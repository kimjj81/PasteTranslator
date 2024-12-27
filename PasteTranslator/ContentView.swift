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
    @State private var sourceLanguage: String = "영어"
    @State private var resultLanguage: String = "한국어"
    @State private var sourceImage: PlatformImage? = nil
    @State private var errorMessage: String? = nil
    
    private var translationCancellable: AnyCancellable?
    
    let languages = ["영어", "일본어", "중국어", "한국어", "스페인어", "프랑스어"]
    
    var body: some View {
        VStack {
            NavigationSplitView {
                VStack {
                    Picker("소스 언어", selection: $sourceLanguage) {
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
                            TextEditor(text: $sourceText)
                                .frame(minHeight: 200)
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
                    Picker("결과 언어", selection: $resultLanguage) {
                        ForEach(languages, id: \.self) { language in
                            Text(language)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    TextView(text: resultText)
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .translationTask(
                            source: Locale.Language(identifier: languageCode(for: sourceLanguage)),
                            target: Locale.Language(identifier: languageCode(for: resultLanguage))
                        ) { session in
                            Task { @MainActor in
                                do {
                                    let response = try await session.translate(sourceText)
                                    resultText = response.targetText
                                    errorMessage = nil
                                } catch {
                                    errorMessage = "Translation error: \(error.localizedDescription)"
                                }
                            }
                        }
                }
                .padding()
            } detail: {
                Text("Select an item")
            }
            
            Text(errorMessage ?? "No errors")
                .foregroundColor(errorMessage != nil ? .red : .gray)
                .padding()
        }
    }
    
    private func pasteFromClipboard() {
        #if canImport(UIKit)
        if let clipboardString = UIPasteboard.general.string {
            sourceText = clipboardString
            sourceImage = nil
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
        } else if let clipboardImage = pasteboard.data(forType: .tiff), let image = NSImage(data: clipboardImage) {
            sourceImage = image
            sourceText = ""
            recognizeTextInImage(image: image) // NSImage to CGImage conversion needed
        }
        #endif
    }
    
    private func recognizeTextInImage(image: PlatformImage) {
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
            }
        }
        
        do {
            try requestHandler.perform([request])
        } catch {
            errorMessage = "Failed to perform text recognition: \(error.localizedDescription)"
            print("Failed to perform text recognition: \(error.localizedDescription)")
        }
    }
    
    private func languageCode(for language: String) -> String {
        switch language {
        case "영어": return "en"
        case "일본어": return "ja"
        case "중국어": return "zh"
        case "한국어": return "ko"
        case "스페인어": return "es"
        case "프랑스어": return "fr"
        default: return "en"
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
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
        textView.isEditable = false // 편집 불가능하게 설정
        textView.isSelectable = true // 선택 가능하게 설정
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 17)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
    #elseif canImport(AppKit)
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false // 편집 불가능하게 설정
        textView.isSelectable = true // 선택 가능하게 설정
        textView.backgroundColor = .clear
        textView.font = NSFont.systemFont(ofSize: 17)
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.string = text
    }
    #endif
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

