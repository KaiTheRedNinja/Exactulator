//
//  Token.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 13/10/26.
//

import Foundation

/// A token consists of characters where all characters fall under one of the following categories:
/// - Numerical values and period
/// - Brackets
/// - Latin and greek alphabets
/// - Everything else that does not fall under the first three categories
struct Token: ExpressibleByStringLiteral {
    var char: String
    var category: ContentCategory

    enum ContentCategory {
        /// Numerical values and the period
        case numerical
        /// Brackets
        case bracket
        /// Latin and greek letters
        case letter
        /// Everything non-alphanumeric and non-bracket
        case other

        static func from(string: String) -> ContentCategory? {
            // Empty string is an invalid token
            guard let first = string.first else { return nil }

            // Get the initial type
            let category = ContentCategory.from(char: first)
            if string.contains(where: { ContentCategory.from(char: $0) != category }) {
                // Contains strings from different categories
                return nil
            }
            return category
        }

        static func from(char: Character) -> ContentCategory {
            switch char {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".": return .numerical
            case "(", "[", "{", "}", "]", ")": return .bracket
            default: break
            }

            return char.isLetter ? .letter : .other
        }
    }

    init(stringLiteral value: String) {
        self.char = value
        self.category = .from(string: value)!
    }

    init?(string: String) {
        guard let category = ContentCategory.from(string: string) else { return nil }
        self.char = string
        self.category = category
    }
}

extension [Token] {
    static func build(from source: String) -> [Token] {
        // break into tokens
        var currentRange: String = ""
        var tokens: [Token] = []
        for char in source {
            // ignore whitespace
            if char.isWhitespace { continue }

            // build token
            let newRange = currentRange + String(char)
            if Token.ContentCategory.from(string: newRange) != nil {
                currentRange = newRange
            } else {
                if let newToken = Token(string: currentRange) {
                    tokens.append(newToken)
                }
                currentRange = String(char)
            }
        }
        if let newToken = Token(string: currentRange) {
            tokens.append(newToken)
        }

        return tokens
    }
}
