import AppIntents

/// "Hey Siri, log my weight in BodyTrainer" — also usable from Shortcuts automations.
struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Weight"
    static var description = IntentDescription("Logs a weigh-in to BodyTrainer and Apple Health.")
    static var openAppWhenRun = false

    @Parameter(title: "Weight", requestValueDialog: "What's the weigh-in?")
    var weight: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await WeightLog.shared.log(weight)
        return .result(dialog: "\(result.summary)")
    }
}

struct BodyTrainerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogWeightIntent(),
                    phrases: ["Log my weight in \(.applicationName)",
                              "Weigh in with \(.applicationName)"],
                    shortTitle: "Log Weight",
                    systemImageName: "scalemass.fill")
    }
}
