#include <napi.h>
#include <type_traits>
#include "impl.h"
#include "util.h"

Napi::Boolean IsAvailable(const Napi::CallbackInfo& cbInfo) {
  return Napi::Boolean::New(cbInfo.Env(), impl::IsAvailable());
}

Napi::Value PromptAuthentication(const Napi::CallbackInfo& cbInfo) {
  Napi::Env env = cbInfo.Env();

  // Ensure we were passed enough arguments
  if (cbInfo.Length() < 3) {
    return util::UndefinedAndThrowError(env, "expected at least 3 arguments");
  }

  // Check the url argument
  if (!cbInfo[0].IsString()) {
    return util::UndefinedAndThrowError<Napi::TypeError>(
        env, "expected first argument to be a string");
  }
  auto url = cbInfo[0].As<Napi::String>();

  // Check the callback scheme argument
  if (!cbInfo[1].IsString()) {
    return util::UndefinedAndThrowError<Napi::TypeError>(
        env, "expected second argument to be a string");
  }
  auto callbackScheme = cbInfo[1].As<Napi::String>();

  // Check the window handle argument
  if (!cbInfo[2].IsBuffer()) {
    return util::UndefinedAndThrowError<Napi::TypeError>(
        env, "expected second argument to be a Buffer");
  }
  auto windowHandle = cbInfo[2].As<Napi::Buffer<void*>>();

  // Call the impl and then handle the result
  auto promise = Napi::Promise::Deferred::New(env);
  impl::PromptAuthentication(std::move(url), std::move(callbackScheme),
                             std::move(windowHandle), env, promise);

  return Napi::Value::From(env, promise.Promise());
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("isAvailable", Napi::Function::New(env, IsAvailable));
  exports.Set("promptAuthentication",
              Napi::Function::New(env, PromptAuthentication));

  return exports;
}
NODE_API_MODULE(NODE_GYP_MODULE_NAME, Init)
