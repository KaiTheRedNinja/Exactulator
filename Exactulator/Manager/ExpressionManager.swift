//
//  ExpressionManager.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Playgrounds

class ExpressionManager {
    var expression: String = ""
    var registeredOps: [any Operator] = []

    enum TreeBuildingError: Error {
        // Syntax had something wrong with it
        case invalidSyntax
        // An operator is not supported
        case unknownOperator
        // An operator is supported but is used incorrectly
        case unsupportedOperatorPosition
    }

    // Currently planned supported syntax:
    // Infix: `a + b`
    // Prefix: `-a`
    // Postfix: `a!`
    //
    // Not supported:
    // Functions: `sin(a)`
    // Implicit multiplication: `ab`
    func computeOperationTree() throws {
        // convert the expression into tokens
        var tokens: [Token] = .build(from: expression)

        // Check for matching bracket pairs. There cannot be more close brackets than open brackets
        var height: Int = 0
        for token in tokens {
            switch token {
            case .openBracket:
                height += 1
            case .closeBracket:
                height -= 1
                if height < 0 { throw TreeBuildingError.invalidSyntax }
            default: continue
            }
        }
        // however there may be more open than close brackets, so we just close them at the end.
        tokens.append(contentsOf: [Token](repeating: .closeBracket, count: height))

        // we recurse. Counterintuitively, it is the *lowest* rated operation that is split up first,
        // because operations are solved deepest-first. Therefore the last operation to happen is the highest up.
        func computeSubexpression(tokenSlice: ArraySlice<Token>) throws -> any Operation {
            guard !tokenSlice.isEmpty else { throw TreeBuildingError.invalidSyntax }
            let first = tokenSlice.first!
            let last = tokenSlice.last!

            if tokenSlice.count == 1 {
                guard case let .numerical(string) = first else { throw TreeBuildingError.invalidSyntax }
                return ValueOperation(value: .bestGuess(value: string))
            }

            // If the subexpression starts and ends with a bracket, take it out
            if first == .openBracket && last == .closeBracket {
                return try computeSubexpression(tokenSlice: tokenSlice.dropFirst().dropLast())
            }

            // Find the lowest ranked operation
            let lowestOperation = tokenSlice.enumerated()
                .compactMap { (index, token) in
                    // for each token, try and find a matching operation
                    if let targetOp = registeredOps.first(where: { $0.matchTokens.contains(token) }) {
                        return (index: index, op: targetOp)
                    }
                    // if we couldn't find one, skip it
                    return nil
                }
                // sort by lowest priority
                .min(by: { $0.op.priority.rawValue < $1.op.priority.rawValue })

            guard let (opIndex, op) = lowestOperation else {
                throw TreeBuildingError.invalidSyntax
            }

            // get the subexpression for the content on the left, if any
            let lhsContent: (any Operation)? = if opIndex > 0 {
                try computeSubexpression(tokenSlice: tokenSlice[..<opIndex])
            } else { nil }
            let rhsContent: (any Operation)? = if opIndex < tokenSlice.count - 1 {
                try computeSubexpression(tokenSlice: tokenSlice[(opIndex + 1)...])
            } else { nil }

            if let lhsContent, let rhsContent, let op = op as? InfixOperator {
                return InfixOperation(op: op, lhs: lhsContent, rhs: rhsContent)
            }
            if let rhsContent, let op = op as? PrefixOperator {
                return PrefixOperation(op: op, rhs: rhsContent)
            }
            if let lhsContent, let op = op as? PostfixOperator {
                return PostfixOperation(op: op, lhs: lhsContent)
            }
            // TODO: figure out how to support function operators

            throw TreeBuildingError.unsupportedOperatorPosition
        }
        do {
            let finalTree = try computeSubexpression(tokenSlice: tokens[tokens.startIndex..<tokens.endIndex])
            print("Final tree: \(finalTree)")
        } catch {
            print("Tree building error: \(error)")
        }
    }
}
