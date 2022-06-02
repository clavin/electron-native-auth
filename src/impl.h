#include <napi.h>
#include <cstddef>
#include <string>

#pragma once

namespace impl {

namespace err {

// Values defined in impl_errs.cc
extern const char* kBadCallbackScheme;
extern const char* kBadURL;
extern const char* kCannotStart;
extern const char* kNotAvailable;
extern const char* kUnknownError;

}  // namespace err

bool IsAvailable();

void PromptAuthentication(Napi::String url,
                          Napi::String callbackScheme,
                          Napi::Buffer<void*> windowHandle,
                          Napi::Env env,
                          Napi::Promise::Deferred promise);

}  // namespace impl
