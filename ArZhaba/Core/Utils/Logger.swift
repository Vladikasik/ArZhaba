import Foundation

/// Universal logging service that tracks source/destination and parent calls
class Logger {
    // MARK: - Log levels enum
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    // MARK: - Singleton
    static let shared = Logger()
    
    // MARK: - Properties
    private var isEnabled = true
    private var logHistory: [String] = []
    private let maxLogHistory = 1000 // Maximum logs to keep in memory
    
    // MARK: - Public methods
    
    /// Logs a message with optional context information
    func log(
        _ message: String,
        level: LogLevel = .info,
        source: String? = nil,
        destination: String? = nil,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let sourceInfo = source ?? "\(filename):\(line)"
        let destinationInfo = destination ?? "N/A"
        
        // Format the log message with timestamp and source information
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formattedMessage = """
        \(level.emoji) [\(level.rawValue)] [\(timestamp)]
        → Source: \(sourceInfo) in \(function)
        → Destination: \(destinationInfo)
        → Message: \(message)
        """
        
        // Print to console
        print(formattedMessage)
        
        // Store in history
        logHistory.append(formattedMessage)
        
        // Trim log history if needed
        if logHistory.count > maxLogHistory {
            logHistory.removeFirst(logHistory.count - maxLogHistory)
        }
    }
    
    /// Logs a debug message
    func debug(_ message: String, source: String? = nil, destination: String? = nil, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .debug, source: source, destination: destination, function: function, file: file, line: line)
    }
    
    /// Logs an info message
    func info(_ message: String, source: String? = nil, destination: String? = nil, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .info, source: source, destination: destination, function: function, file: file, line: line)
    }
    
    /// Logs a warning message
    func warning(_ message: String, source: String? = nil, destination: String? = nil, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .warning, source: source, destination: destination, function: function, file: file, line: line)
    }
    
    /// Logs an error message
    func error(_ message: String, source: String? = nil, destination: String? = nil, function: String = #function, file: String = #file, line: Int = #line) {
        log(message, level: .error, source: source, destination: destination, function: function, file: file, line: line)
    }
    
    /// Returns the full log history
    func getLogHistory() -> [String] {
        return logHistory
    }
    
    /// Clears the log history
    func clearLogHistory() {
        logHistory.removeAll()
    }
    
    /// Enables or disables logging
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
} 