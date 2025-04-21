import SwiftUI
import Foundation

enum AppColors {
    static let background = Color(red: 256/255, green: 252/255, blue: 228/255)
}

// Non-isolated debug functionality
private var isDebugOutputEnabled: Bool {
    get {
        UserDefaults.standard.bool(forKey: "debugOutputEnabled")
    }
    set {
        UserDefaults.standard.set(newValue, forKey: "debugOutputEnabled")
    }
}

func setDebugOutputEnabled(_ enabled: Bool) {
    isDebugOutputEnabled = enabled
}

func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    if isDebugOutputEnabled {
        let message = items.map { "\($0)" }.joined(separator: separator)
        // Filter out system messages we don't want to see
        let unwantedPatterns = [
            "VSGating:",
            "MADService",
            "RTIInputSystemClient",
            "perform input operation requires a valid sessionID",
            "has passed an invalid numeric value (NaN, or not-a-number) to CoreGraphics API",
            "Backtrace:",
            "<redacted>"
        ]
        
        let shouldPrint = !unwantedPatterns.contains { pattern in
            message.contains(pattern)
        }
        
        if shouldPrint {
            print(message, terminator: terminator)
        }
    }
}

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Default values
    private let defaultWebhookURL = "https://api.thunk.ai/webhook"
    
    @Published var webhookURL: String {
        didSet {
            UserDefaults.standard.set(webhookURL, forKey: "webhookURL")
        }
    }
    
    @Published var debugOutputEnabled: Bool {
        didSet {
            setDebugOutputEnabled(debugOutputEnabled)
        }
    }
    
    private init() {
        self.webhookURL = UserDefaults.standard.string(forKey: "webhookURL") ?? defaultWebhookURL
        self.debugOutputEnabled = UserDefaults.standard.bool(forKey: "debugOutputEnabled")
    }
    
    func resetToDefaults() {
        webhookURL = defaultWebhookURL
        debugOutputEnabled = false
    }
}

