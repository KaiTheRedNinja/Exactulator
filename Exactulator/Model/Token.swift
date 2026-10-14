//
//  Token.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 13/10/26.
//

import Foundation

var digitCharSet: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "."]
var bracketCharSet: Set<Character> = ["(", ")"]

/// A token consists of characters where all characters fall under one of the following categories:
/// - Numerical values and period
/// - Brackets
/// - Latin and greek alphabets
/// - Everything else that does not fall under the first three categories
enum Token: ExpressibleByStringLiteral, Hashable {
    case numerical(String)
    case openBracket
    case closeBracket
    case letter(String)
    case other(String)

    var string: String {
        switch self {
        case .numerical(let string): string
        case .openBracket: "("
        case .closeBracket: ")"
        case .letter(let string): string
        case .other(let string): string
        }
    }

    init(stringLiteral value: String) {
        let char = value.first!
        switch char {
        case "(": self = .openBracket
        case ")": self = .closeBracket
        default: break
        }

        if digitCharSet.contains(char) {
            self = .numerical(value)
        } else if char.isLetter {
            self = .letter(value)
        } else {
            self = .other(value)
        }
    }

    init?(checking value: String) {
        if value.allSatisfy({ digitCharSet.contains($0) }) {
            self = .numerical(value); return
        } else if value.allSatisfy({ $0.isLetter }) {
            self = .letter(value); return
        } else if value.count == 1 {
            switch value {
            case "(": self = .openBracket; return
            case ")": self = .closeBracket; return
            default: break
            }
        }

        if !value.contains(where: { digitCharSet.contains($0) || $0.isLetter || bracketCharSet.contains($0) }) {
            self = .other(value); return
        }

        return nil
    }
}

private extension Token {
    var singleChar: Bool {
        switch self {
        case .numerical, .letter, .other: false
        case .openBracket, .closeBracket: true
        }
    }
}

extension [Token] {
    static func build(from source: String) -> [Token] {
        // break into tokens
        var currentRange: String = ""
        var currentToken: Token?
        var tokens: [Token] = []
        for char in source {
            // ignore whitespace
            if char.isWhitespace { continue }

            // build token
            let charStr = String(char)
            let newRange = currentRange + charStr
            var shouldAppendToken: Bool
            if let newToken = Token(checking: newRange) {
                currentRange = newRange
                currentToken = newToken
                shouldAppendToken = newToken.singleChar
            } else {
                shouldAppendToken = true
            }

            if shouldAppendToken {
                if let currentToken { tokens.append(currentToken) }
                currentToken = nil
                currentRange = charStr
            }
        }
        if let newToken = Token(checking: currentRange) {
            tokens.append(newToken)
        }

        return tokens
    }
}
