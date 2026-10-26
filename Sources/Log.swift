import os

enum Log {
    static let app = Logger(subsystem: "au.com.codebridge.dockbridge", category: "app")
    static let tap = Logger(subsystem: "au.com.codebridge.dockbridge", category: "event-tap")
    static let windows = Logger(subsystem: "au.com.codebridge.dockbridge", category: "windows")
}
