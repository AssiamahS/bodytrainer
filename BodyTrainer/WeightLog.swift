import ActivityKit
import Foundation
import HealthKit
import SwiftData

/// The one write path: notification reply, Siri/Shortcuts and the in-app field all land here.
@MainActor
final class WeightLog {
    static let shared = WeightLog()

    let container: ModelContainer = {
        do { return try ModelContainer(for: WeightEntry.self) }
        catch { fatalError("SwiftData store failed: \(error)") }
    }()
    private let health = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)

    private var context: ModelContext { container.mainContext }

    struct Result {
        let state: WeighInAttributes.ContentState
        let savedToHealth: Bool
        var summary: String {
            "Logged \(state.latestText) \(state.unit.rawValue)" + (state.weekAgo == nil ? "" : " · \(state.deltaText) this week")
                + (savedToHealth ? "" : " (Health sync pending)")
        }
    }

    // MARK: Health

    func requestHealthAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await health.requestAuthorization(toShare: [bodyMass], read: [bodyMass])
    }

    private func writeToHealth(kg: Double, date: Date) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(),
              health.authorizationStatus(for: bodyMass) == .sharingAuthorized else { return false }
        let sample = HKQuantitySample(type: bodyMass,
                                      quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: date, end: date)
        do { try await health.save(sample); return true }
        catch { return false }   // locked device / revoked access — retried by syncPending()
    }

    /// Retry entries that missed Health (logged while locked, or before access was granted).
    func syncPending() async {
        let pending = (try? context.fetch(FetchDescriptor<WeightEntry>(
            predicate: #Predicate { !$0.savedToHealth && !$0.fromHealth }))) ?? []
        for entry in pending {
            if await writeToHealth(kg: entry.kg, date: entry.date) { entry.savedToHealth = true }
        }
        try? context.save()
    }

    /// Pull the last year of Body Weight samples from Health so the chart has history on day one.
    @discardableResult
    func importFromHealth() async -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let since = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass,
                                         predicate: HKQuery.predicateForSamples(withStart: since, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        guard let samples = try? await descriptor.result(for: health) else { return 0 }

        let existing = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        var added = 0
        for s in samples where s.sourceRevision.source.bundleIdentifier != Bundle.main.bundleIdentifier {
            if existing.contains(where: { abs($0.date.timeIntervalSince(s.startDate)) < 60 }) { continue }
            let kg = s.quantity.doubleValue(for: .gramUnit(with: .kilo))
            context.insert(WeightEntry(date: s.startDate, kg: kg, savedToHealth: true, fromHealth: true))
            added += 1
        }
        try? context.save()
        return added
    }

    // MARK: Log

    @discardableResult
    func log(_ value: Double, unit: WeightUnit = .preferred, date: Date = .now) async -> Result {
        let kg = unit.toKg(value)
        let entry = WeightEntry(date: date, kg: kg)
        context.insert(entry)
        entry.savedToHealth = await writeToHealth(kg: kg, date: date)
        try? context.save()

        let state = currentState(unit: unit) ?? .init(latest: value, weekAgo: nil, unit: unit, loggedAt: date)
        await TrendActivity.show(state)
        return Result(state: state, savedToHealth: entry.savedToHealth)
    }

    func delete(_ entry: WeightEntry) {
        context.delete(entry)
        try? context.save()
    }

    /// Latest weigh-in vs the newest one at least six days older than it.
    func currentState(unit: WeightUnit = .preferred) -> WeighInAttributes.ContentState? {
        var desc = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        desc.fetchLimit = 400
        guard let all = try? context.fetch(desc), let latest = all.first else { return nil }
        let cutoff = latest.date.addingTimeInterval(-6 * 86_400)
        let weekAgo = all.first(where: { $0.date <= cutoff })
        return .init(latest: unit.fromKg(latest.kg),
                     weekAgo: weekAgo.map { unit.fromKg($0.kg) },
                     unit: unit,
                     loggedAt: latest.date)
    }
}

/// Lock Screen + Dynamic Island trend. Request only works with the app in the
/// foreground; a notification reply can only update an activity that already exists.
enum TrendActivity {
    static func show(_ state: WeighInAttributes.ContentState) async {
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(8 * 3600))
        if let activity = Activity<WeighInAttributes>.activities.first {
            await activity.update(content)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(attributes: WeighInAttributes(), content: content)
    }

    static func end() async {
        for activity in Activity<WeighInAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
