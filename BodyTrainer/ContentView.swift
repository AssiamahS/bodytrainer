import Charts
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]

    @AppStorage("unit") private var unitRaw = WeightUnit.lb.rawValue
    @AppStorage("reminderDays") private var reminderDaysRaw = "2,4,6"   // Mon, Wed, Fri
    @AppStorage("reminderHour") private var reminderHour = 7
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("onboarded") private var onboarded = false

    @State private var input = ""
    @State private var status: String?
    @FocusState private var fieldFocused: Bool

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }
    private var state: WeighInAttributes.ContentState? { entries.isEmpty ? nil : WeightLog.shared.currentState(unit: unit) }

    var body: some View {
        NavigationStack {
            List {
                Section { header }
                Section { logRow }
                if entries.count > 1 { Section("Trend") { chart } }
                Section("Reminders") { reminders }
                Section("History") { history }
            }
            .navigationTitle("BodyTrainer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Unit", selection: $unitRaw) {
                            ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0.rawValue) }
                        }
                        Button("Import from Health", systemImage: "heart.text.square") {
                            Task {
                                let n = await WeightLog.shared.importFromHealth()
                                status = n == 0 ? "Nothing new in Health" : "Imported \(n) weigh-ins from Health"
                            }
                        }
                        Button("Hide Live Activity", systemImage: "rectangle.slash") {
                            Task { await TrendActivity.end() }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .task { await firstRun() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await WeightLog.shared.syncPending() } }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let state {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(state.latestText).font(.system(size: 56, weight: .bold, design: .rounded))
                    Text(unit.rawValue).font(.title2).foregroundStyle(.secondary)
                    Spacer()
                    Text(state.deltaText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(state.deltaColor)
                }
                Text(state.trendText).font(.subheadline).foregroundStyle(.secondary)
                Text("Last logged \(state.loggedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption).foregroundStyle(.tertiary)
            } else {
                Text("No weigh-ins yet").font(.title2.bold())
                Text("Log one below, or answer the reminder right from the notification.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if let status { Text(status).font(.caption).foregroundStyle(.teal) }
        }
        .padding(.vertical, 6)
    }

    private var logRow: some View {
        HStack {
            TextField("Weight (\(unit.rawValue))", text: $input)
                .keyboardType(.decimalPad)
                .focused($fieldFocused)
                .font(.title3)
            Button("Log") {
                guard let v = Reminders.parse(input) else { status = "Enter a number like 196.4"; return }
                fieldFocused = false
                input = ""
                Task { status = await WeightLog.shared.log(v, unit: unit).summary }
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
    }

    private var chart: some View {
        let points = entries.prefix(120).reversed()
        let values = points.map { unit.fromKg($0.kg) }
        let lo = (values.min() ?? 0) - 1, hi = (values.max() ?? 0) + 1
        return Chart(Array(points)) { e in
            LineMark(x: .value("Date", e.date), y: .value(unit.rawValue, unit.fromKg(e.kg)))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.teal)
            PointMark(x: .value("Date", e.date), y: .value(unit.rawValue, unit.fromKg(e.kg)))
                .foregroundStyle(.teal)
                .symbolSize(24)
        }
        .chartYScale(domain: lo...hi)
        .frame(height: 200)
        .padding(.vertical, 8)
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Array(zip(1...7, Calendar.current.veryShortWeekdaySymbols)), id: \.0) { day, label in
                    let on = reminderDays.contains(day)
                    Button {
                        var d = reminderDays
                        if on { d.remove(day) } else { d.insert(day) }
                        reminderDaysRaw = d.sorted().map(String.init).joined(separator: ",")
                        reschedule()
                    } label: {
                        Text(label).font(.subheadline.bold())
                            .frame(width: 36, height: 36)
                            .background(on ? Color.teal : Color.secondary.opacity(0.2), in: Circle())
                            .foregroundStyle(on ? .black : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
            Button("Send a test reminder in 5 s", systemImage: "bell.badge") {
                Task { await Reminders.sendTest(); status = "Lock the phone — reminder in 5 s" }
            }
        }
        .padding(.vertical, 4)
    }

    private var history: some View {
        ForEach(entries) { e in
            HStack {
                VStack(alignment: .leading) {
                    Text("\(unit.format(unit.fromKg(e.kg))) \(unit.rawValue)").font(.body.monospacedDigit())
                    Text(e.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: e.fromHealth ? "heart.text.square" : (e.savedToHealth ? "heart.fill" : "clock.arrow.circlepath"))
                    .foregroundStyle(e.savedToHealth ? .pink : .secondary)
            }
        }
        .onDelete { idx in idx.map { entries[$0] }.forEach(WeightLog.shared.delete) }
    }

    // MARK: Helpers

    private var reminderDays: Set<Int> {
        Set(reminderDaysRaw.split(separator: ",").compactMap { Int($0) })
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now
        } set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            reminderHour = c.hour ?? 7
            reminderMinute = c.minute ?? 0
            reschedule()
        }
    }

    private func reschedule() {
        let days = reminderDays, h = reminderHour, m = reminderMinute
        Task { await Reminders.schedule(weekdays: days, hour: h, minute: m) }
    }

    private func firstRun() async {
        if !onboarded {
            _ = await Reminders.requestPermission()
            await WeightLog.shared.requestHealthAccess()
            await WeightLog.shared.importFromHealth()
            onboarded = true
        }
        reschedule()
        await WeightLog.shared.syncPending()
        // Foreground is the only time an activity can be started; bring the trend back.
        if let s = WeightLog.shared.currentState(unit: unit) { await TrendActivity.show(s) }
    }
}
