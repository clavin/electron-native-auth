export class AuthRequest {
  constructor(params: {
    url: string;
    callbackScheme: string;
    windowHandle: import("node:buffer").Buffer;
  });
  static isAvailable(): boolean;
  start(): Promise<string>;
  cancel(): void;
}
