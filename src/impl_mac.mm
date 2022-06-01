#include "impl.h"
#include "util.h"

#import <AuthenticationServices/AuthenticationServices.h>

@interface PresentationContextProvider
    : NSObject <ASWebAuthenticationPresentationContextProviding>

@property(nonatomic, copy) NSView* presentationContext;

@end

@implementation PresentationContextProvider

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:
    (ASWebAuthenticationSession*)session API_AVAILABLE(macos(10.15)) {
  // Ensure that there is a context associated with this object
  if (self.presentationContext == NULL) {
    return NULL;
  }

  // Attempt to find the NSWindow for the associated presentation context view
  for (NSWindow* window in [NSApp orderedWindows]) {
    if ([window contentView] == self.presentationContext) {
      return window;
    }
  }

  // No window found, fallback on null
  return NULL;
}

@end

namespace {

API_AVAILABLE(macos(10.15))
void AttemptSetPresentationContext(ASWebAuthenticationSession* authSess,
                                   const Napi::Buffer<void*>& windowHandle) {
  // Sanity check the window handle buffer:
  if (windowHandle.Length() != sizeof(NSView*)) {
    return;
  }

  // UNSAFE: Convert the window handle to an NSView*, which is what we expect it
  // to be
  NSView* windowView = *reinterpret_cast<NSView**>(windowHandle.Data());

  // Sanity check that this is a valid object of the right kind at least
  if (![windowView isKindOfClass:[NSView class]]) {
    return;
  }

  // Create a presentation context provider and set it on the auth session
  auto ctxPvdr = [PresentationContextProvider new];
  ctxPvdr.presentationContext = windowView;
  [authSess setPresentationContextProvider:ctxPvdr];
}

}

namespace impl {

bool IsAvailable() {
  if (@available(macOS 10.15, *)) {
    return true;
  } else {
    return false;
  }
}

void PromptAuthentication(Napi::String url,
                          Napi::Buffer<void*> windowHandle,
                          Napi::Env env,
                          Napi::Promise::Deferred promise) {
  if (@available(macOS 10.15, *)) {
    // Try to convert the url to an NSURL
    NSString* urlNSStr =
        [NSString stringWithUTF8String:url.Utf8Value().c_str()];
    if (urlNSStr == nil) {
      util::RejectWithError(env, promise, err::kBadURL);
      return;
    }
    NSURL* urlNSURL = [NSURL URLWithString:urlNSStr];
    if (urlNSURL == nil) {
      util::RejectWithError(env, promise, err::kBadURL);
      return;
    }

    // Create the auth session
    auto authSess = [[ASWebAuthenticationSession alloc]
              initWithURL:urlNSURL
        callbackURLScheme:NULL
        completionHandler:^(NSURL* _Nullable callbackURL,
                            NSError* _Nullable error) {
          // Handle success
          if (callbackURL != NULL) {
            // Convert the callback URL to a string
            auto result = Napi::String::New(
                env, [[callbackURL absoluteString] UTF8String]);
            promise.Resolve(result);
          }

          // Handle error
          if (error != NULL) {
            util::RejectWithError(env, promise, "todo: auth error message");
          } else {
            util::RejectWithError(env, promise, err::kUnknownError);
          }
        }];

    // Attempt to set the presentationContextProvider
    AttemptSetPresentationContext(authSess, windowHandle);

    // Try to check that the auth session can start
    if (@available(macOS 10.15.4, *)) {
      if (![authSess canStart]) {
        util::RejectWithError(env, promise, err::kUnknownError);
        return;
      }
    }

    // Start the auth session
    bool started = [authSess start];

    // Check if the start failed
    if (!started) {
      util::RejectWithError(env, promise, err::kUnknownError);
      return;
    }
  } else {
    // Throw an exception that this method is not available
    Napi::Error::New(env, err::kNotAvailable).ThrowAsJavaScriptException();
  }
}

}  // namespace impl
