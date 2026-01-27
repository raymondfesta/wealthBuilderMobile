import Foundation

enum AppConfig {
    #if DEBUG
    // Update this IP when your Mac's address changes
    // Get current IP: ipconfig getifaddr en0
    static let baseURL = "http://192.168.1.8:3000"
    #else
    static let baseURL = "https://api.yourapp.com"
    #endif
}
