import ActivityKit
import Foundation

enum WeightUnit: String, CaseIterable, Codable, Identifiable {
    case lb, kg
    var id: String { rawValue }

    static let kgPerLb = 0.45359237

    func toKg(_ value: Double) -> Double { self == .kg ? value : value * Self.kgPerLb }
    func fromKg(_ kg: Double) -> Double { self == .kg ? kg : kg / Self.kgPerLb }

    func format(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1))) }

    static var preferred: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "unit") ?? "") ?? .lb
    }
}

/// Live Activity: last weigh-in and how it moved against a week ago.
struct WeighInAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var latest: Double          // in `unit`
        var weekAgo: Double?        // in `unit`, nil during the first week
        var unit: WeightUnit
        var loggedAt: Date

        var latestText: String { unit.format(latest) }

        var deltaText: String {
            guard let weekAgo else { return "new" }
            let d = latest - weekAgo
            let sign = d > 0 ? "+" : (d < 0 ? "−" : "±")
            return sign + unit.format(abs(d))
        }

        var trendText: String {
            guard let weekAgo else { return "\(latestText) \(unit.rawValue) · first week" }
            return "\(unit.format(weekAgo)) → \(latestText) \(unit.rawValue), \(deltaText) this week"
        }
    }
}
