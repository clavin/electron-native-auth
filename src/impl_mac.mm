#include "impl.h"
#include "napi.h"
#include "util.h"

#import <AuthenticationServices/AuthenticationServices.h>

@interface PresentationContextProvider
    : NSObject <ASWebAuthenticationPresentationContextProviding>

@property(nonatomic, assign) NSView* presentationContext;

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

namespace impl {

bool IsAvailable() {
  if (@available(macOS 10.15, *)) {
    return true;
  } else {
    return false;
  }
}

void PromptAuthentication(Napi::String url,
                          Napi::String callbackScheme,
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

    // Try to convert the callback scheme to an NSString
    NSString* callbackSchemeNSStr =
        [NSString stringWithUTF8String:callbackScheme.Utf8Value().c_str()];
    if (callbackScheme == nil) {
      util::RejectWithError(env, promise, err::kBadCallbackScheme);
      return;
    }

    // Create the auth session
    __block Napi::Promise::Deferred blockPromise = promise;
    auto authSess = [[ASWebAuthenticationSession alloc]
              initWithURL:urlNSURL
        callbackURLScheme:callbackSchemeNSStr
        completionHandler:^(NSURL* _Nullable callbackURL,
                            NSError* _Nullable error) {
          __block NSURL* blockCallbackURL = callbackURL;
          dispatch_sync(dispatch_get_main_queue(), ^{
            // Create a handle scope in this block
            Napi::HandleScope handle_scope(env);

            // Handle success
            if (blockCallbackURL != NULL) {
              // Convert the callback URL to a string
              auto result = Napi::String::New(
                  env, [[blockCallbackURL absoluteString] UTF8String]);
              blockPromise.Resolve(result);
              return;
            }

            // Handle error
            if (error != NULL) {
              util::RejectWithError(env, blockPromise,
                                    "todo: auth error message");
              return;
            } else {
              util::RejectWithError(env, blockPromise, err::kUnknownError);
              return;
            }
          });
        }];

    // Just in case. You never know.
    static_assert(sizeof(void*) == sizeof(NSView*),
                  "expected void* to have the same size as NSView*");

    // Create a presentation context provider and set it on the auth session
    auto ctxPvdr = [PresentationContextProvider new];

    // Check if we have "one pointer" amount of data in the buffer
    if (windowHandle.Length() == 1) {
      // UNSAFE: Convert the window handle to an NSView*, which is what we
      // expect it to be
      NSView* windowView = *reinterpret_cast<NSView**>(windowHandle.Data());

      // Sanity check that this is a valid object of the right kind at least
      if ([windowView isKindOfClass:[NSView class]]) {
        ctxPvdr.presentationContext = windowView;
      }
    }

    // Set the presentation context provider on the auth session
    [authSess setPresentationContextProvider:ctxPvdr];

    // Try to check that the auth session can start
    if (@available(macOS 10.15.4, *)) {
      if (![authSess canStart]) {
        util::RejectWithError(env, promise, err::kCannotStart);
        return;
      }
    }

    // Start the auth session
    bool started = [authSess start];

    // Check if the start failed
    if (!started) {
      util::RejectWithError(env, promise, err::kCannotStart);
      return;
    }
  } else {
    // Throw an exception that this method is not available
    Napi::Error::New(env, err::kNotAvailable).ThrowAsJavaScriptException();
  }
}

}  // namespace impl
