#include "impl.h"

namespace impl {

bool IsAvailable() {
  return false;
}

void PromptAuthentication(Napi::String url,
                          Napi::String callbackScheme,
                          Napi::Buffer<void*> windowHandle,
                          Napi::Env env,
                          Napi::Promise::Deferred promise) {
  Napi::Error::New(env, err::kNotAvailable).ThrowAsJavaScriptException();
}

}  // namespace impl
