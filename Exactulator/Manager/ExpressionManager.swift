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
    // Prefix: `-a` // currently broken!
    // Postfix: `a!` // currently broken!
    //
    // Not supported:
    // Functions: `sin(a)`
    // Implicit multiplication: `ab`
    func computeOperationTree() throws(TreeBuildingError) -> any Operation {
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
        func computeSubexpression(tokenSlice: ArraySlice<Token>) throws(TreeBuildingError) -> any Operation {
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

            // Find the furthest, lowest ranked operation. Note that it cannot be in a bracket.
            var height = 0
            var bestIndexAndOp: (Int, any Operator)?
            for (index, token) in tokenSlice.enumerated().reversed() {
                // handle brackets
                switch token {
                case .openBracket: height += 1; continue
                case .closeBracket: height -= 1; continue
                default: break
                }

                // determine the operation for this token, else skip
                guard height == 0,
                      let targetOp = registeredOps.first(where: { $0.matchTokens.contains(token) })
                else { continue }

                // If it has a lower priority than the current best, it becomes the new best
                if let bestOp = bestIndexAndOp?.1 {
                    if targetOp.priority.rawValue < bestOp.priority.rawValue {
                        bestIndexAndOp = (index, targetOp)
                    }
                } else {
                    // if no current best, it wins by default
                    bestIndexAndOp = (index, targetOp)
                }
            }

            guard let (opIndex, op) = bestIndexAndOp else {
                throw TreeBuildingError.invalidSyntax
            }

            // get the subexpression for the content on the left, if any
            let lhsContent: (any Operation)? = if opIndex > 0 {
                try computeSubexpression(tokenSlice: tokenSlice[..<(tokenSlice.startIndex + opIndex)])
            } else { nil }
            let rhsContent: (any Operation)? = if opIndex < tokenSlice.count - 1 {
                try computeSubexpression(tokenSlice: tokenSlice[(tokenSlice.startIndex + opIndex + 1)...])
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
        return try computeSubexpression(tokenSlice: tokens[tokens.startIndex..<tokens.endIndex])
    }
}
