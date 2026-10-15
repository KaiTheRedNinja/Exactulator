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

        enum WorkingToken {
            case token(Token)
            case operation(any Operation)
        }

        // build index of operators
        let postfixOps = registeredOps.compactMap { $0 as? PostfixOperator }
        let prefixOps = registeredOps.compactMap { $0 as? PrefixOperator }
        let infixOps = registeredOps.compactMap { $0 as? InfixOperator }
        // TODO: function operators
        // TODO: implicit multiplication operators

        // map all tokens into working tokens. We first convert values into operations, because those are the most direct.
        var startWorkingTokens: [WorkingToken] = []
        for token in tokens {
            switch token {
            case .numerical(let string):
                startWorkingTokens.append(.operation(ValueOperation(value: .bestGuess(value: string))))
            default:
                startWorkingTokens.append(.token(token))
            }
        }

        // until there is only one working token left, we do the following:
        // 1. Find any brackets and get operations from them
        // 2. Find the highest-ranked operator, searcing in the order postfix -> prefix -> infix
        func computeSubexpression(workingTokens: ArraySlice<WorkingToken>) throws(TreeBuildingError) -> any Operation {
            // scan for brackets, get them solved
            var bracketStartIndex: Int?
            var height: Int = 0
            var replacements: [(Range<Int>, any Operation)] = []
            for (index, workToken) in workingTokens.enumerated() {
                guard case let .token(token) = workToken else { continue }
                switch token {
                case .openBracket:
                    height += 1
                    if height == 1 { bracketStartIndex = index }
                case .closeBracket:
                    height -= 1
                    if height == 0 {
                        // We have exited a bracket, time to solve!
                        // note that we drop the first and last item, because those are brackets and will result in infinite loops.
                        let subexpression = try computeSubexpression(workingTokens: workingTokens[(bracketStartIndex!+1)..<index])
                        replacements.append((
                            bracketStartIndex!..<(index+1),
                            FunctionOperation(
                                op: SubexpressionOperator.shared,
                                elements: [subexpression]
                            )
                        ))
                        bracketStartIndex = nil
                    }
                default: continue
                }
            }

            // get a mutable copy and substitute
            var workingTokensMut = Array(workingTokens)
            for (replacementRange, op) in replacements {
                workingTokensMut.replaceSubrange(replacementRange, with: [.operation(op)])
            }

            // Find the highest-ranked operator, searcing in the order postfix -> prefix -> infix. Then optimise.
            while workingTokensMut.count > 1 {
                // search for highest ranked valid postfix operations
                do {
                    var highestPostfix: any PostfixOperator?
                    var replacement: (Range<Int>, PostfixOperation)?
                    for (index, workToken) in workingTokensMut.enumerated().dropFirst() {
                        // must be a token, have valid LHS, and invalid RHS to be postfix
                        guard case let .token(token) = workToken,
                              case let .operation(lhs) = workingTokensMut[index-1]
                                else { continue }
                        if index < workingTokensMut.count-1, case .operation = workingTokensMut[index+1] { continue }
                        // determine what operator it matches
                        guard let op = postfixOps.first(where: { $0.matchTokens.contains(token) }) else { continue }
                        // determine if it is of a higher priority
                        if highestPostfix == nil || op.priority.rawValue > highestPostfix!.priority.rawValue {
                            highestPostfix = op
                            // mark the LHS and this item as for replacement
                            // note that index-1..<index+1 is [index-1, index+1) = [index-1, index]
                            replacement = ((index-1)..<(index+1), PostfixOperation(op: op, lhs: lhs))
                        }
                    }
                    // replace and continue the main loop if one is found
                    if let (replacementRange, op) = replacement {
                        workingTokensMut.replaceSubrange(replacementRange, with: [.operation(op)])
                        continue
                    }
                }

                // search for highest ranked valid prefix operations
                do {
                    var highestPrefix: any PrefixOperator?
                    var replacement: (Range<Int>, PrefixOperation)?
                    for (index, workToken) in workingTokensMut.enumerated().dropLast() {
                        // must be a token, have valid RHS, and invalid LHS to be prefix
                        guard case let .token(token) = workToken,
                              case let .operation(rhs) = workingTokensMut[index+1]
                        else { continue }
                        if index > 0, case .operation = workingTokensMut[index-1] { continue }
                        // determine what operator it matches
                        guard let op = prefixOps.first(where: { $0.matchTokens.contains(token) }) else { continue }
                        // determine if it is of a higher priority
                        if highestPrefix == nil || op.priority.rawValue > highestPrefix!.priority.rawValue {
                            highestPrefix = op
                            // mark the RHS and this item as for replacement
                            // note that index..<index+2 is [index, index+2) = [index, index+1]
                            replacement = (index..<(index+2), PrefixOperation(op: op, rhs: rhs))
                        }
                    }
                    // replace and continue the main loop if one is found
                    if let (replacementRange, op) = replacement {
                        workingTokensMut.replaceSubrange(replacementRange, with: [.operation(op)])
                        continue
                    }
                }

                // search for highest ranked valid infix operations
                do {
                    var highestInfix: any InfixOperator?
                    var replacement: (Range<Int>, InfixOperation)?
                    for (index, workToken) in workingTokensMut.enumerated().dropFirst().dropLast() {
                        // must be a token, have valid LHS and RHS to be an infix
                        guard case let .token(token) = workToken,
                              case let .operation(lhs) = workingTokensMut[index-1],
                              case let .operation(rhs) = workingTokensMut[index+1]
                        else { continue }
                        // determine what operator it matches
                        guard let op = infixOps.first(where: { $0.matchTokens.contains(token) }) else { continue }
                        // determine if it is of a higher priority
                        if highestInfix == nil || op.priority.rawValue > highestInfix!.priority.rawValue {
                            highestInfix = op
                            // mark this item, LHS, and RHS for replacement
                            // note that index-1..<index+2 is [index-1, index+2) = [index-1, index+1]
                            replacement = ((index-1)..<(index+2), InfixOperation(op: op, lhs: lhs, rhs: rhs))
                        }
                    }
                    // replace and continue the main loop if one is found
                    if let (replacementRange, op) = replacement {
                        workingTokensMut.replaceSubrange(replacementRange, with: [.operation(op)])
                        continue
                    }
                }
            }

            guard let reduced = workingTokensMut.first, case let .operation(operation) = reduced else {
                throw TreeBuildingError.invalidSyntax
            }
            return operation
        }

        return try computeSubexpression(
            workingTokens: startWorkingTokens[startWorkingTokens.startIndex..<startWorkingTokens.endIndex]
        )
    }
}
