import Foundation
import SwiftData

@Model
final class WeightEntry {
    var date: Date
    /// Canonical storage is kilograms; display converts to the preferred unit.
    var kg: Double
    var savedToHealth: Bool
    /// Came from Health (import) — never written back.
    var fromHealth: Bool

    init(date: Date, kg: Double, savedToHealth: Bool = false, fromHealth: Bool = false) {
        self.date = date
        self.kg = kg
        self.savedToHealth = savedToHealth
        self.fromHealth = fromHealth
    }
}
