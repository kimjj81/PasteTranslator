//
//  ContentView.swift
//  PasteTranslator
//
//  Created by Jeong Jin Kim on 12/27/24.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
typealias PlatformViewRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
typealias PlatformViewRepresentable = NSViewRepresentable
#endif
import NaturalLanguage
import Vision
import Foundation
import SwiftData
import Combine
import Translation


struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var sourceText: String = ""
    @State private var resultText: String = ""
    @State private var sourceLanguage: String = "en"
    @State private var resultLanguage: String = "ko"
    @State private var sourceImage: PlatformImage? = nil
    @State private var errorMessage: String? = nil
    // Define a configuration.
    @State private var configuration: TranslationSession.Configuration?
    
    let languages = ["en", "ko", "ja", "es", "fr","zh"]
    
    var body: some View {
        VStack {
//            NavigationSplitView {
                VStack {
                    Picker("From", selection: $sourceLanguage) {
                        ForEach(languages, id: \.self) { language in
                            Text(language)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    ZStack {
                        if let image = sourceImage {
                            #if canImport(UIKit)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(minHeight: 200)
                            #elseif canImport(AppKit)
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(minHeight: 200)
                            #endif
                        } else {
                            TextView(text: sourceText)
                                .frame(minHeight: 100)
                                .background(KeyPressHandler(key: "v", modifiers: [.command]) {
                                    pasteFromClipboard()
                                })
                        }
                    }
                    .background(KeyPressHandler(key: "v", modifiers: [.command]) {
                        pasteFromClipboard()
                    })
                }
                .padding()
                VStack {
                    Picker("To", selection: $resultLanguage) {
                        ForEach(languages, id: \.self) { language in
                            Text(language)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    TextView(text: resultText)
                        .frame(minHeight: 100)
                }
                .padding()
            Text(errorMessage ?? "No errors")
                .foregroundColor(errorMessage != nil ? .red : .gray)
                .padding()
        }.translationTask(
            source: Locale.Language(identifier: sourceLanguage),
            target: Locale.Language(identifier: resultLanguage),
            action: performTranslation
        ).translationTask(
            configuration,
            action: performTranslation
        ).background(KeyPressHandler(key: "v", modifiers: [.command]) {
            print("cmd+p")
            pasteFromClipboard()
        })
        .onReceive(EventPublisher.shared.commandVEvent) {
            print("commandVEvent")
            pasteFromClipboard()
        }
    }
    
    func performTranslation(session: TranslationSession) async {
        do {
            errorMessage = "Translating..."
            let response = try await session.translate(sourceText)
            await MainActor.run {
                resultText = response.targetText
                errorMessage = nil
            }
        } catch {
            let errorMessage = "Translation error: \(error.localizedDescription)"
            print(errorMessage)
            await MainActor.run {
                self.errorMessage = errorMessage
            }
        }
    }

    private func triggerTranslation() {
        guard configuration == nil else {
            configuration?.source = Locale.Language(identifier: sourceLanguage)
            configuration?.target = Locale.Language(identifier: resultLanguage)
            configuration?.invalidate()
            return
        }
        // Let the framework automatically determine the language pairing.
        configuration = TranslationSession.Configuration(
            source: Locale.Language(identifier: sourceLanguage),
            target: Locale.Language(identifier: resultLanguage)
        )
    }

    private func pasteFromClipboard() {
        errorMessage = "Pasting..."
        #if canImport(UIKit)
        if let clipboardString = UIPasteboard.general.string {
            sourceText = clipboardString
            sourceImage = nil
            triggerTranslation()
        } else if let clipboardImage = UIPasteboard.general.image {
            sourceImage = clipboardImage
            sourceText = ""
            recognizeTextInImage(image: clipboardImage)
        }
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        if let clipboardString = pasteboard.string(forType: .string) {
            sourceText = clipboardString
            sourceImage = nil
            triggerTranslation()
        } else if let clipboardImage = pasteboard.data(forType: .tiff), let image = NSImage(data: clipboardImage) {
            sourceImage = image
            sourceText = ""
            recognizeTextInImage(image: image) // NSImage to CGImage conversion needed
        }
        #endif
        
    }
    
    private func recognizeTextInImage(image: PlatformImage) {
        errorMessage = "Recognizing..."
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { return }
        #elseif canImport(AppKit)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        #endif
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            DispatchQueue.main.async {
                self.sourceText = recognizedStrings.joined(separator: "\n")
                triggerTranslation()
            }
        }
        
        do {
            try requestHandler.perform([request])
        } catch {
            errorMessage = "Failed to perform text recognition: \(error.localizedDescription)"
            print("Failed to perform text recognition: \(error.localizedDescription)")
        }
    }
    
    private func addItem() {
        withAnimation {
            
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

struct KeyPressHandler: PlatformViewRepresentable {
    var key: String
    var modifiers: NSEvent.ModifierFlags
    var action: () -> Void

    #if canImport(UIKit)
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(self.modifiers) && event.charactersIgnoringModifiers == self.key {
                self.action()
                return nil
            }
            return event
        }
        context.coordinator.monitor = monitor
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    #elseif canImport(AppKit)
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(self.modifiers) && event.charactersIgnoringModifiers == self.key {
                self.action()
                return nil
            }
            return event
        }
        context.coordinator.monitor = monitor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var monitor: Any?
    }
}

// UITextView를 SwiftUI에서 사용하기 위한 UIViewRepresentable
struct TextView: PlatformViewRepresentable {
    var text: String

    #if canImport(UIKit)
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.isScrollEnabled = true
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
    #elseif canImport(AppKit)
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = NSFont.systemFont(ofSize: 11)
        textView.textColor = .black
        
        // textView가 scrollView의 너비에 맞게 자동으로 조정되도록 설정
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            textView.string = text
            print("updateNSView \(text)")
            // scrollView의 너비에 맞게 textView 크기 업데이트
            textView.frame.size.width = nsView.contentSize.width
        }
    }
    #endif
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

