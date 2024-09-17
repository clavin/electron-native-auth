# Electron Native Authentication

Integration of native OS authentication services for Electron apps.

## API

### Class: `AuthRequest`

A request to receive authentication from a resource. The request must specify what URL scheme it expects the authentication callback to come from.

**Example**:

```javascript
import { AuthRequest } from "electron-native-auth";

if (AuthRequest.isAvailable()) {
  const req = new AuthRequest({
    url,
    callbackScheme,
    windowHandle: myBrowserWindow.getNativeWindowHandle(),
  });

  const result = await req.start();
} else {
  console.error("Native auth request unavailable :(");
}
```

#### Static Method: `isAvailable()`

Indicates if this API is available on the current platform. This method is always available, even if the current platform is not supported.

- **Parameters**: None.
- **Returns**: A `boolean`, `true` if the rest of this class' methods are supported on the current platform.

#### Constructor

Initializes, but does not start, an authentication request. A request can be started and later cancelled.

- **Parameters**:
  - Options (`object`):
    - `url` (`string`): The URL to authenticate to.
    - `callbackScheme` (`string`): The URL scheme (the part before `://`) that the callback is expected to have.
    - `windowHandle` (`Buffer`): The native OS window handle for the window requesting authentication. Used when the OS prompts the user for authentication.
    - `headers` (`{ [header: string]: string }`, optional, macOS 14.4+): Headers and their values to add to HTTP requests sent during the authentication session.

#### Method: `start()`

Begins the request to authenticate.

- **Parameters**: None.
- **Returns**: A `Promise` that resolves (with `undefined`) when the request has finished.

#### Method: `cancel()`

Cancels the authentication request.

- **Parameters**: None.
- **Returns**: Nothing.

## Supported Platforms

* macOS: ✅
  * Runtime: 10.15+
  * Xcode SDK: 16+
  * Uses [ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
* Windows: ❌
* Linux: ❌