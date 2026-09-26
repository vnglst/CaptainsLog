import Foundation

enum AudioLevel {
    static func rootMeanSquare(of samples: UnsafeBufferPointer<Float>) -> Float? {
        guard !samples.isEmpty else { return nil }
        let sum = samples.reduce(Float.zero) { $0 + $1 * $1 }
        return sqrt(sum / Float(samples.count))
    }
}
