/**
 * This file implements a facade of the addon for platforms that are not
 * supported.
 */

#include <napi.h>

class AuthRequest : public Napi::ObjectWrap<AuthRequest> {
 public:
  static Napi::Function ClassDef(Napi::Env env);
  static Napi::Value IsAvailable(const Napi::CallbackInfo& info);
  AuthRequest(const Napi::CallbackInfo& info);
};

Napi::Function AuthRequest::ClassDef(Napi::Env env) {
  return DefineClass(
      env, "AuthRequest",
      {StaticMethod<&AuthRequest::IsAvailable>(
          "isAvailable", static_cast<napi_property_attributes>(
                             napi_writable | napi_configurable))});
}

Napi::Value AuthRequest::IsAvailable(const Napi::CallbackInfo& info) {
  return Napi::Boolean::New(info.Env(), false);
}

AuthRequest::AuthRequest(const Napi::CallbackInfo& info)
    : Napi::ObjectWrap<AuthRequest>(info) {
  auto env = info.Env();

  Napi::Error::New(env, "this function is not implemented for this platform")
      .ThrowAsJavaScriptException();
  return;
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set("AuthRequest", AuthRequest::ClassDef(env));
  return exports;
}
NODE_API_MODULE(NODE_GYP_MODULE_NAME, Init)
