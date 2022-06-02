#include "impl.h"

namespace impl {

namespace err {

const char* kBadCallbackScheme =
    "the callback scheme is misformatted or incorrect";
const char* kBadURL = "url is misformatted or incorrect";
const char* kCannotStart =
    "failed to start authentication session. (double check your callback "
    "scheme?)";
const char* kNotAvailable = "this function is not available";
const char* kUnknownError = "an unknown error occurred";

}  // namespace err

}  // namespace impl
