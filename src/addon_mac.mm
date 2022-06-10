#include <napi.h>
#include "js_native_api_types.h"

#import <AuthenticationServices/AuthenticationServices.h>

/**
 * Holds a reference to an NSObject (or subclass of it), calling `-release` on
 * that reference when this object is destroyed. The pointer can be null.
 *
 * This object does **not** call retain on the reference it is created with when
 * the object is constructed.
 */
template <typename T>
class ns_ref {
 public:
  explicit constexpr ns_ref(T* obj) : obj_(obj) {}
  ~ns_ref() { try_release(); }

  ns_ref(const ns_ref<T>&) = delete;
  ns_ref(const ns_ref<T>&&) = delete;

  ns_ref<T>& operator=(const ns_ref<T>& that) {
    try_release();
    obj_ = that.get();
    [obj_ retain];
    return *this;
  }

  T* get() const { return obj_; }

 private:
  T* obj_;

  void try_release() {
    if (obj_ != nullptr) {
      [obj_ release];
      obj_ = nullptr;
    }
  }
};

/**
 * Holds a reference to some type T that is *only* meant for comparison. Deters
 * accidentally dereferencing a pointer. The pointer can be null.
 */
template <typename T>
class comp_only_ref {
 public:
  comp_only_ref() : ref_(nullptr) {}
  explicit comp_only_ref(T* ref) : ref_(ref) {}

  bool operator==(T* other) { return other == ref_; }

 private:
  T* ref_;
};

@interface AuthReqPresentationContextProvider
    : NSObject <ASWebAuthenticationPresentationContextProviding>

/**
 * Maybe an `NSView*` that corresponds to the `contentView` of an `NSWindow`.
 *
 * NOTE: Even if this property is set, it is not guaranteed that this points to
 * a valid Objecive-C object, much less anything at all! Avoid using this as the
 * object of a message (not even `- isKindOfClass:`) so there are no crashes.
 */
@property(nonatomic, assign) comp_only_ref<NSView> targetContentViewMaybe;

@end

@implementation AuthReqPresentationContextProvider

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:
    (ASWebAuthenticationSession*)session API_AVAILABLE(macos(10.15)) {
  // Ensure that there is a target view associated with this object
  if (self.targetContentViewMaybe == nullptr) {
    return nullptr;
  }

  // Attempt to find the NSWindow for the associated presentation context view
  for (NSWindow* window in [NSApp orderedWindows]) {
    if (self.targetContentViewMaybe == [window contentView]) {
      return window;
    }
  }

  // No window found, fallback on null
  return nullptr;
}

@end

#define THROW_ERR_AND_RETURN_UNDEFINED(env, msg)           \
  Napi::Error::New(env, msg).ThrowAsJavaScriptException(); \
  return env.Undefined();
#define THROW_TYPE_ERR_AND_RETURN_UNDEFINED(env, msg)          \
  Napi::TypeError::New(env, msg).ThrowAsJavaScriptException(); \
  return env.Undefined();
#define THROW_ERR_AND_RETURN(env, msg)                     \
  Napi::Error::New(env, msg).ThrowAsJavaScriptException(); \
  return;
#define THROW_TYPE_ERR_AND_RETURN(env, msg)                    \
  Napi::TypeError::New(env, msg).ThrowAsJavaScriptException(); \
  return;

enum class AuthRequestState {
  Invalid,
  Initialized,
  Started,
  Canceled,
  Finished,
};

/**
 * A request for authentication.
 */
class API_AVAILABLE(macos(10.15)) AuthRequest
    : public Napi::ObjectWrap<AuthRequest> {
 public:
  static Napi::Function ClassDef(Napi::Env env);
  static Napi::Value IsAvailable(const Napi::CallbackInfo& info);
  AuthRequest(const Napi::CallbackInfo& info);
  ~AuthRequest();
  Napi::Value Start(const Napi::CallbackInfo& info);
  Napi::Value Cancel(const Napi::CallbackInfo& info);

 private:
  ns_ref<ASWebAuthenticationSession> webAuthSess_;
  Napi::Env env_;
  Napi::Promise::Deferred promise_;
  AuthRequestState state_;

  void OnComplete(NSURL* _Nullable callbackURL, NSError* _Nullable error);
};

Napi::Function AuthRequest::ClassDef(Napi::Env env) {
  constexpr napi_property_attributes propAttrs =
      static_cast<napi_property_attributes>(napi_writable | napi_configurable);

  return DefineClass(
      env, "AuthRequest",
      {InstanceMethod<&AuthRequest::Start>("start", propAttrs),
       InstanceMethod<&AuthRequest::Cancel>("cancel", propAttrs),
       StaticMethod<&AuthRequest::IsAvailable>("isAvailable", propAttrs)});
}

Napi::Value AuthRequest::IsAvailable(const Napi::CallbackInfo& info) {
  return Napi::Boolean::New(info.Env(), @available(macOS 10.15, *));
}

AuthRequest::AuthRequest(const Napi::CallbackInfo& info)
    : Napi::ObjectWrap<AuthRequest>(info),
      webAuthSess_(nullptr),
      env_(info.Env()),
      promise_(env_),
      state_(AuthRequestState::Invalid) {
  auto env = env_;

  // Verify and coerce the parameters object
  if (!info[0].IsObject()) {
    THROW_TYPE_ERR_AND_RETURN(env, "expected object for parameter");
  }
  auto paramsObj = info[0].As<Napi::Object>();

  // Verify and coerce the url parameter into an NSURL
  Napi::Value urlParamValue;
  if (!paramsObj.Get("url").UnwrapTo(&urlParamValue)) {
    THROW_TYPE_ERR_AND_RETURN(env, "expected parameter 'url'");
  }
  if (!urlParamValue.IsString()) {
    THROW_TYPE_ERR_AND_RETURN(env, "expected parameter 'url' to be a string");
  }
  auto urlParam = urlParamValue.As<Napi::String>();
  auto urlNSStr = [NSString stringWithUTF8String:urlParam.Utf8Value().c_str()];
  if (urlNSStr == nullptr) {
    THROW_TYPE_ERR_AND_RETURN(env,
                              "expected parameter 'url' to be utf-8 encoded");
  }
  auto urlNSURL = [NSURL URLWithString:urlNSStr];
  if (urlNSURL == nullptr) {
    THROW_ERR_AND_RETURN(env, "expected parameter 'url' to be a valid url");
  }
  // urlNSURL is valid!

  // Verify and coerce the callback url scheme
  Napi::Value cbSchemeParamValue;
  if (!paramsObj.Get("callbackScheme").UnwrapTo(&cbSchemeParamValue)) {
    THROW_TYPE_ERR_AND_RETURN(env, "expected parameter 'callbackScheme'");
  }
  if (!cbSchemeParamValue.IsString()) {
    THROW_TYPE_ERR_AND_RETURN(
        env, "expected parameter 'callbackScheme' to be a string");
  }
  auto cbSchemeParam = cbSchemeParamValue.As<Napi::String>();
  auto cbSchemeNSStr =
      [NSString stringWithUTF8String:cbSchemeParam.Utf8Value().c_str()];
  if (cbSchemeNSStr == nullptr) {
    THROW_TYPE_ERR_AND_RETURN(
        env, "expected parameter 'callbackScheme' to be utf-8 encoded");
  }
  // cbSchemeNSStr is valid!

  // Verify and coerce the window handle
  Napi::Value windowHandleParamValue;
  if (!paramsObj.Get("windowHandle").UnwrapTo(&windowHandleParamValue)) {
    THROW_TYPE_ERR_AND_RETURN(env, "expected parameter 'windowHandle'");
  }
  if (!windowHandleParamValue.IsBuffer()) {
    THROW_TYPE_ERR_AND_RETURN(
        env, "expected parameter 'windowHandle' to be a buffer");
  }
  auto windowHandleBuf = windowHandleParamValue.As<Napi::Buffer<NSView*>>();
  if (windowHandleBuf.ByteLength() != sizeof(NSView*)) {
    THROW_TYPE_ERR_AND_RETURN(
        env,
        "expected parameter 'windowHandle' to be the size of a window handle");
  }
  auto windowHandle = comp_only_ref<NSView>(*windowHandleBuf.Data());
  // windowHandle is valid for comparisons!

  // Create the web auth session
  auto webAuthSess = [ASWebAuthenticationSession alloc];
  // We store a pointer to the web auth session object as a block variable
  // so we can later compare it during completion to verify that this object is
  // still valid, just in case.
  __block comp_only_ref<ASWebAuthenticationSession>
      completionVerificationHandle(webAuthSess);
  webAuthSess_ = ns_ref<ASWebAuthenticationSession>([webAuthSess
            initWithURL:urlNSURL
      callbackURLScheme:cbSchemeNSStr
      completionHandler:^(NSURL* _Nullable callbackURL,
                          NSError* _Nullable error) {
        dispatch_sync(dispatch_get_main_queue(), ^{
          if (completionVerificationHandle == webAuthSess_.get()) {
            OnComplete(callbackURL, error);
          }
        });
      }]);

  // Set the presentation context provider on the web auth sess
  auto authReqPresentationCtxPvdr = [AuthReqPresentationContextProvider new];
  [authReqPresentationCtxPvdr
      setTargetContentViewMaybe:std::move(windowHandle)];
  [webAuthSess_.get()
      setPresentationContextProvider:authReqPresentationCtxPvdr];

  // Done for now, the session can be started in |Start|.
  state_ = AuthRequestState::Initialized;
}

AuthRequest::~AuthRequest() {
  // Mark this request invalid just in case
  state_ = AuthRequestState::Invalid;
}

Napi::Value AuthRequest::Start(const Napi::CallbackInfo& info) {
  auto env = info.Env();

  // Check for web auth sess to be initialized and not started or canceled
  if (webAuthSess_.get() == nullptr) {
    THROW_ERR_AND_RETURN_UNDEFINED(env, "this auth request is not initialized");
  }
  if (state_ != AuthRequestState::Initialized) {
    THROW_ERR_AND_RETURN_UNDEFINED(
        env, "this auth request is in an invalid state, cannot be started");
  }

  // Attempt to start the web auth session
  state_ = AuthRequestState::Started;
  auto started = [webAuthSess_.get() start];

  // If it started successfully, set the started flag and return the deferred
  // completion promise
  if (started) {
    return promise_.Promise();
  }

  // Double check that the state is still initialized, it may have been changed
  // synchronously by `-start`.
  if (state_ != AuthRequestState::Initialized) {
    return promise_.Promise();
  }

  // Otherwise, mark this request as canceled and throw an error
  state_ = AuthRequestState::Invalid;
  THROW_ERR_AND_RETURN_UNDEFINED(
      env, "auth request could not be started for an unknown reason");
}

Napi::Value AuthRequest::Cancel(const Napi::CallbackInfo& info) {
  auto env = info.Env();

  // Check for web auth sess to be initialized, started, and not canceled
  if (webAuthSess_.get() == nullptr) {
    THROW_ERR_AND_RETURN_UNDEFINED(env, "this auth request is not initialized");
  }
  if (state_ != AuthRequestState::Started) {
    THROW_ERR_AND_RETURN_UNDEFINED(
        env, "this auth request has not been started, cannot be canceled");
  }

  // Mark this request canceled.
  state_ = AuthRequestState::Canceled;
  return env.Undefined();
}

void AuthRequest::OnComplete(NSURL* _Nullable callbackURL,
                             NSError* _Nullable error) {
  // Check that this request isn't canceled or invalid, only started
  if (state_ != AuthRequestState::Started) {
    return;
  }

  Napi::HandleScope handleScope(env_);

  // Mark this request as finished
  state_ = AuthRequestState::Finished;

  // Handle errors
  if (error != nullptr) {
    // Reject with an error that includes information in the NSError
    auto err = Napi::Error::New(env_, [[error description] UTF8String]);
    err.Set("code", Napi::Number::New(env_, [error code]));

    // Just in case the extra info is useful
    if (callbackURL != nullptr) {
      err.Set("info", [[callbackURL absoluteString] UTF8String]);
    }

    promise_.Reject(err.Value());
    return;
  }

  // If we got a callback url, resolve with that
  if (callbackURL != nullptr) {
    promise_.Resolve(
        Napi::String::New(env_, [[callbackURL absoluteString] UTF8String]));
    return;
  }

  // Something has gone wrong, but still reject anyways
  promise_.Reject(
      Napi::Error::New(
          env_,
          "the request was completed, but returned no callback url nor error")
          .Value());
  return;
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("AuthRequest", AuthRequest::ClassDef(env));
  return exports;
}
NODE_API_MODULE(NODE_GYP_MODULE_NAME, Init)
