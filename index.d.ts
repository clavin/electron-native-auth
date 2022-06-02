/**
 * Prompts the user to authenticate at the URL.
 */
export function promptAuthentication(
  url: string,
  callbackScheme: string,
  windowHandle: import("node:buffer").Buffer
): Promise<string>;

export function isAvailable(): boolean;
