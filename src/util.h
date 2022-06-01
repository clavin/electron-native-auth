#include <napi.h>

#pragma once

namespace util {

/**
 * Convenience method to throw an error and return undefined.
 */
template <class Err = Napi::Error>
inline Napi::Value UndefinedAndThrowError(const Napi::Env& env,
                                          const char* err) {
  // Make sure Err is an Napi::Error type
  static_assert(std::is_base_of<Napi::Error, Err>::value,
                "type param Err must extend Napi::Error");

  // Throw the error
  Err::New(env, err).ThrowAsJavaScriptException();

  // Return undefined
  return env.Undefined();
}

/**
 * //
 */
template <class Err = Napi::Error>
inline void RejectWithError(const Napi::Env& env,
                            const Napi::Promise::Deferred& promise,
                            const char* err) {
  // Make sure Err is an Napi::Error type
  static_assert(std::is_base_of<Napi::Error, Err>::value,
                "type param Err must extend Napi::Error");

  // Reject the promise with an error type
  promise.Reject(Err::New(env, err).Value());
}

}  // namespace util
