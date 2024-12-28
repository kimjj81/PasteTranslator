//
//  PasteTranslatorApp.swift
//  PasteTranslator
//
//  Created by Jeong Jin Kim on 12/27/24.
//

import SwiftUI
import SwiftData
import Combine
import AppKit

// Global event publisher
class EventPublisher: ObservableObject {
    static let shared = EventPublisher()
    let commandVEvent = PassthroughSubject<Void, Never>()
}

@main
struct PasteTranslatorApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Global Monitor: Captures key events globally
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
        }
        
        // Local Monitor: Captures key events when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
            return event // Return the event to propagate it further
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up monitors
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "v" {
            print("Command+V pressed!")
            EventPublisher.shared.commandVEvent.send()
        }
    }
}