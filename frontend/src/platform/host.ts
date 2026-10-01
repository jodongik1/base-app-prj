// Implement this boundary in each host when host-specific behavior is needed.
export interface HostBridge {
  openExternalUrl(url: string): Promise<void>
  getStorage(key: string): Promise<string | null>
  setStorage(key: string, value: string): Promise<void>
}
