export class AuthRequest {
  constructor(params: {
    url: string;
    callbackScheme: string;
    windowHandle: Buffer;
  });
  static isAvailable(): boolean;
  start(): Promise<string>;
  cancel(): void;
}
