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
        // no such thing as an empty token
        if value.isEmpty { return nil }

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
        case .numerical, .letter: false
        case .other, .openBracket, .closeBracket: true
        }
    }
}

extension [Token] {
    static func build(fromString source: String) -> [Token] {
        // break into tokens
        var currentRange: String = ""
        var tokens: [Token] = []
        for char in source {
            // ignore whitespace
            if char.isWhitespace { continue }

            // build token
            let charStr = String(char)
            let newRange = currentRange + charStr
            // if the new range results in a broken token, commit the previous token, reset current range
            if Token(checking: newRange) == nil {
                if let oldToken = Token(checking: currentRange) {
                    tokens.append(oldToken)
                    currentRange = charStr
                }
                // invalid token, cut range
                currentRange = charStr
            } else {
                // valid token, extend the current range
                currentRange = newRange
            }
            // check again whether this range works, and if it should also be committed
            if let newToken = Token(checking: currentRange) {
                if newToken.singleChar {
                    tokens.append(newToken)
                    currentRange = ""
                }
            } else {
                fatalError("... i have no clue what happened here")
            }
        }
        if !currentRange.isEmpty, let newToken = Token(checking: currentRange) {
            tokens.append(newToken)
        }

        return tokens
    }
}
