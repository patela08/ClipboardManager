import Foundation
import Testing
@testable import ClipboardManager

@Suite("SettingsManager")
@MainActor
struct SettingsManagerTests {

    // MARK: - Initialization

    @Test("Loads settings from persistence on init")
    func loadsSettingsFromPersistence() {
        let persistence = MockPersistenceService()
        persistence.storedSettings = AppSettings(historySize: 50)

        let manager = SettingsManager(persistenceService: persistence)

        #expect(manager.settings.historySize == 50)
        #expect(persistence.loadSettingsCallCount == 1)
    }

    @Test("Uses default settings when persistence throws")
    func usesDefaultsOnLoadFailure() {
        let persistence = MockPersistenceService()
        persistence.loadSettingsError = NSError(domain: "test", code: 1)

        let manager = SettingsManager(persistenceService: persistence)

        #expect(manager.settings == AppSettings())
    }

    // MARK: - updateHistorySize

    @Test("Accepts valid history size within bounds")
    func acceptsValidHistorySize() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        manager.updateHistorySize(50)

        #expect(manager.settings.historySize == 50)
        #expect(persistence.saveSettingsCallCount == 1)
        #expect(persistence.lastSavedSettings?.historySize == 50)
    }

    @Test("Accepts history size at lower bound (1)")
    func acceptsHistorySizeLowerBound() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        manager.updateHistorySize(1)

        #expect(manager.settings.historySize == 1)
    }

    @Test("Accepts history size at upper bound (150)")
    func acceptsHistorySizeUpperBound() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        manager.updateHistorySize(150)

        #expect(manager.settings.historySize == 150)
    }

    @Test("Rejects history size below lower bound (0)")
    func rejectsHistorySizeBelowBound() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)
        let original = manager.settings.historySize

        manager.updateHistorySize(0)

        #expect(manager.settings.historySize == original)
        #expect(persistence.saveSettingsCallCount == 0)
    }

    @Test("Rejects history size above upper bound (151)")
    func rejectsHistorySizeAboveBound() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)
        let original = manager.settings.historySize

        manager.updateHistorySize(151)

        #expect(manager.settings.historySize == original)
        #expect(persistence.saveSettingsCallCount == 0)
    }

    @Test("Rejects negative history size")
    func rejectsNegativeHistorySize() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)
        let original = manager.settings.historySize

        manager.updateHistorySize(-5)

        #expect(manager.settings.historySize == original)
        #expect(persistence.saveSettingsCallCount == 0)
    }

    // MARK: - updateContentTypes

    @Test("Updates content types and forces plainText true")
    func updateContentTypesForcesPT() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        var types = CaptureContentTypes()
        types.plainText = false
        types.richText = false
        types.images = true
        types.files = false

        manager.updateContentTypes(types)

        #expect(manager.settings.captureContentTypes.plainText == true)
        #expect(manager.settings.captureContentTypes.richText == false)
        #expect(manager.settings.captureContentTypes.images == true)
        #expect(manager.settings.captureContentTypes.files == false)
        #expect(persistence.saveSettingsCallCount == 1)
    }

    // MARK: - addExcludedApp

    @Test("Adds a new excluded app")
    func addsNewExcludedApp() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        manager.addExcludedApp("com.example.app")

        #expect(manager.settings.excludedApps.contains("com.example.app"))
        #expect(persistence.saveSettingsCallCount == 1)
    }

    @Test("Does not add duplicate excluded app")
    func noDuplicateExcludedApp() {
        let persistence = MockPersistenceService()
        persistence.storedSettings.excludedApps = ["com.example.app"]
        let manager = SettingsManager(persistenceService: persistence)

        manager.addExcludedApp("com.example.app")

        #expect(manager.settings.excludedApps.count == 1)
        #expect(persistence.saveSettingsCallCount == 0)
    }

    // MARK: - removeExcludedApp

    @Test("Removes an existing excluded app")
    func removesExistingExcludedApp() {
        let persistence = MockPersistenceService()
        persistence.storedSettings.excludedApps = ["com.example.app", "com.other.app"]
        let manager = SettingsManager(persistenceService: persistence)

        manager.removeExcludedApp("com.example.app")

        #expect(!manager.settings.excludedApps.contains("com.example.app"))
        #expect(manager.settings.excludedApps.contains("com.other.app"))
        #expect(persistence.saveSettingsCallCount == 1)
    }

    @Test("No-op when removing app not in list")
    func noOpRemoveNonExistentApp() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        manager.removeExcludedApp("com.nonexistent.app")

        #expect(persistence.saveSettingsCallCount == 0)
    }

    // MARK: - updateTriggerGesture

    @Test("Updates trigger gesture")
    func updatesTriggerGesture() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        let gesture = KeyGesture(modifiers: .option, keyCode: 0x0A)
        manager.updateTriggerGesture(gesture)

        #expect(manager.settings.triggerGesture == gesture)
        #expect(persistence.saveSettingsCallCount == 1)
    }

    // MARK: - updateTheme

    @Test("Updates theme preference")
    func updatesTheme() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        manager.updateTheme(.dark)

        #expect(manager.settings.theme == .dark)
        #expect(persistence.saveSettingsCallCount == 1)
    }

    // MARK: - updateAutoStart

    @Test("Updates auto-start setting")
    func updatesAutoStart() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        manager.updateAutoStart(true)

        #expect(manager.settings.autoStartAtLogin == true)
        #expect(persistence.saveSettingsCallCount == 1)
    }

    // MARK: - updateMonitoringEnabled

    @Test("Updates monitoring enabled setting")
    func updatesMonitoringEnabled() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        manager.updateMonitoringEnabled(false)

        #expect(manager.settings.monitoringEnabled == false)
        #expect(persistence.saveSettingsCallCount == 1)
    }

    // MARK: - Persistence failure handling

    @Test("Keeps in-memory state when save fails")
    func keepsStateOnSaveFailure() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        // First update succeeds
        manager.updateHistorySize(42)
        #expect(manager.settings.historySize == 42)

        // Now simulate save failure
        persistence.saveSettingsError = NSError(domain: "test", code: 2)
        manager.updateHistorySize(75)

        // In-memory state should still update
        #expect(manager.settings.historySize == 75)
    }

    // MARK: - Settings apply immediately

    @Test("Settings changes apply immediately without restart")
    func settingsApplyImmediately() {
        let persistence = MockPersistenceService()
        let manager = SettingsManager(persistenceService: persistence)

        // Each update should be reflected immediately in the settings property
        manager.updateHistorySize(25)
        #expect(manager.settings.historySize == 25)

        manager.updateTheme(.light)
        #expect(manager.settings.theme == .light)

        manager.updateAutoStart(true)
        #expect(manager.settings.autoStartAtLogin == true)

        manager.updateMonitoringEnabled(false)
        #expect(manager.settings.monitoringEnabled == false)
    }
}
