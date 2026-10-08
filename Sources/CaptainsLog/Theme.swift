import SwiftUI

/// Swift 6.4's macOS SDK also declares a `State` macro, but the standalone
/// Command Line Tools do not ship its implementation. Referencing the original
/// property-wrapper type through an alias keeps command-line builds working.
public typealias CLState<Value> = SwiftUI.State<Value>

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
