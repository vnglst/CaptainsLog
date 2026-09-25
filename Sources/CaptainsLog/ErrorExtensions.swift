import Foundation

extension Error {
    /// True if this error represents a network cancellation (timeout, user cancel, etc.).
    var isNetworkCancellation: Bool {
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
            underlying.domain == NSURLErrorDomain && underlying.code == NSURLErrorCancelled {
            return true
        }
        let description = nsError.localizedDescription.lowercased()
        if description.contains("cancelled") || description.contains("canceled") {
            return true
        }
        return false
    }
}
