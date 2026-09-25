import AppKit
import CaptainsLog
import SwiftUI

@main
struct CaptainsLogApp: App {
    @CLState private var appState: AppState

    #if DEBUG
    private let designFixture = ProcessInfo.processInfo.environment["CAPTAINSLOG_UI_FIXTURE"]
    #endif

    init() {
        #if DEBUG
        // Configure the isolated demo before AppState reads any saved configuration.
        if ProcessInfo.processInfo.environment["CAPTAINS_LOG_CONFIG_PATH"] == nil {
            do {
                try DemoMode.prepare()
            } catch {
                fatalError("Could not prepare the safe demo data: \(error)")
            }
        }
        #endif
        _appState = CLState(wrappedValue: AppState())
        // Required: SwiftPM executables have no .app bundle, so without this macOS won't let windows become key and keystrokes leak to the Finder.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

    }

    var body: some Scene {
        WindowGroup {
            FieldNotesContentView(
                bootstrap: {
                    #if DEBUG
                    return designFixture == nil
                    #else
                    return true
                    #endif
                }()
            )
                .environment(appState)
                #if DEBUG
                .task {
                    if let designFixture {
                        appState.applyDesignFixture(named: designFixture)
                    }
                }
                #endif
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 840, height: 780)

    }
}
