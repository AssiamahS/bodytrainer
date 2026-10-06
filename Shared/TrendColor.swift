import SwiftUI

extension WeighInAttributes.ContentState {
    /// Up = orange, down = green, flat/first week = gray.
    var deltaColor: Color {
        guard let weekAgo else { return .secondary }
        return latest > weekAgo ? .orange : (latest < weekAgo ? .green : .secondary)
    }
}
