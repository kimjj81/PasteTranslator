//
//  Item.swift
//  PasteTranslator
//
//  Created by Jeong Jin Kim on 12/27/24.
//


import Foundation
import SwiftData

@Model
final public class Item {
    var timestamp: Date
    var sourceLanguage : String
    var targetLanguage : String
    var sourceText : String
    var targetString : String
    
    init(timestamp: Date, sourceLanguage: String, targetLanguage: String, sourceText: String, targetString: String) {
        self.timestamp = timestamp
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.sourceText = sourceText
        self.targetString = targetString
    }
}
