//
//  ExpressionManager.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Playgrounds

class ExpressionManager {
    var registeredOps: OperationHolder
    var registeredUnits: UnitSystem

    init(registeredOps: OperationHolder, registeredUnits: UnitSystem) {
        self.registeredOps = registeredOps
        self.registeredUnits = registeredUnits
    }

    enum TreeBuildingError: Error {
        // Syntax had something wrong with it
        case invalidSyntax
        // An operator is not supported
        case unknownOperator
        // An operator is supported but is used incorrectly
        case unsupportedOperatorPosition
        // Invalid number of arguments
        case invalidArguments
    }

    enum WorkingToken {
        case token(Token)
        case operation(any Operation)
        case nested(any FunctionOperator, [[WorkingToken]])
    }

    func computeOperationTree(nodes: [VisualNode]) throws(TreeBuildingError) -> any Operation {
        func visualNodesToWorkingTokens(visualNodes: [VisualNode]) -> [WorkingToken] {
            // convert the expression into tokens
            var result: [WorkingToken] = []
            var currentString: String = ""

            func pushCurrent() {
                result.append(contentsOf: [Token].build(fromString: currentString).map { .token($0) })
                currentString = ""
            }

            // Check for matching bracket pairs. There cannot be more close brackets than open brackets
            for node in visualNodes {
                switch node {
                case .atom(let str):
                    currentString += str
                case .structure(let structure):
                    result.append(
                        .nested(structure.associatedOperator, structure.slots.map {
                            visualNodesToWorkingTokens(visualNodes: $0)
                        })
                    )
                }
            }

            return result
        }

        var tokens = visualNodesToWorkingTokens(visualNodes: nodes)

        try balanceWorkingTokenBrackets(tokens: &tokens)

        return try computeSubexpression(
            workingTokens: tokens[tokens.startIndex..<tokens.endIndex]
        )
    }

    func computeOperationTree(expression: String) throws(TreeBuildingError) -> any Operation {
        // convert the expression into tokens
        let tokens: [Token] = .build(fromString: expression)

        // map all tokens into working tokens. We first convert values and constants into operations
        var startWorkingTokens: [WorkingToken] = []
        for token in tokens {
            switch token {
            case .numerical(let string):
                startWorkingTokens.append(.operation(ValueOperation(value: .init(value: .bestGuess(value: string), unit: .one))))
            default:
                if let op = registeredOps.match(constantToken: token) {
                    startWorkingTokens.append(.operation(ConstantOperation(constant: op)))
                } else {
                    startWorkingTokens.append(.token(token))
                }
            }
        }

        try balanceWorkingTokenBrackets(tokens: &startWorkingTokens)

        return try computeSubexpression(
            workingTokens: startWorkingTokens[startWorkingTokens.startIndex..<startWorkingTokens.endIndex]
        )
    }

    func balanceWorkingTokenBrackets(tokens: inout [WorkingToken]) throws(TreeBuildingError) {
        // Check for matching bracket pairs. There cannot be more close brackets than open brackets
        var height: Int = 0
        for token in tokens {
            switch token {
            case .token(.openBracket):
                height += 1
            case .token(.closeBracket):
                height -= 1
                if height < 0 { throw TreeBuildingError.invalidSyntax }
            default: continue
            }
        }
        // however there may be more open than close brackets, so we just close them at the end.
        tokens.append(contentsOf: [WorkingToken](repeating: .token(.closeBracket), count: height))
    }

    // Currently supported syntax:
    // Infix: `a + b`
    // Prefix: `-a`
    // Postfix: `a!`
    // Implicit multiplication: `ab`
    // Functions with one parameter: `sin(a)`
    // Functions with multiple parameters: `log(a, b)`
    //
    // Not supported:
    // Functions with zero parameters
    //
    // For each subexpression, we aim to break it up by
    // 1) Splitting up subexpressions, if any
    // 2) Splitting up brackets, if any
    // 3) Evaluating operators
    func computeSubexpression(workingTokens: ArraySlice<WorkingToken>) throws(TreeBuildingError) -> any Operation {
        guard !workingTokens.isEmpty else { throw TreeBuildingError.invalidSyntax }

        // scan for nested, get them solved
        var workingTokensMut = Array(workingTokens)
        for (index, workToken) in workingTokens.enumerated() {
            guard case let .nested(functionOperator, rows) = workToken else { continue }
            workingTokensMut[index] = try .operation(
                FunctionOperation(
                    op: functionOperator,
                    elements: rows.map { (row) throws(TreeBuildingError) in
                        try computeSubexpression(workingTokens: row[row.startIndex..<row.endIndex])
                    }
                )
            )
        }

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

                    let subExpression = workingTokens[(bracketStartIndex!+1)..<index]
                    let subExpressionParts = subExpression.split { possibleDelimiter in
                        switch possibleDelimiter {
                        case .token(let token): token.string == ","
                        default: false
                        }
                    }
                    let subOperations = try subExpressionParts.map { (subExpression) throws(TreeBuildingError) in
                        try computeSubexpression(workingTokens: subExpression)
                    }
                    replacements.append((
                        bracketStartIndex!..<(index+1),
                        FunctionOperation(
                            op: subExpressionParts.count == 1 ? SubexpressionOperator.shared : ParametersOperator.shared,
                            elements: subOperations
                        )
                    ))
                    bracketStartIndex = nil
                }
            default: continue
            }
        }

        // substitute brackets out
        for (replacementRange, op) in replacements.reversed() { // replace from back to front to preserve index order
            workingTokensMut.replaceSubrange(replacementRange, with: [.operation(op)])
        }

        // Find the highest-ranked operator, searcing in the order function -> postfix -> implicit -> prefix -> infix. Then optimise.
        mainloop: while workingTokensMut.count > 1 {
            // search for highest ranked valid function operations
            for (index, workToken) in workingTokensMut.enumerated().dropLast() {
                // must be a token, and have a valid RHS that is a subexpression. LHS is irrelevant.
                guard case let .token(token) = workToken,
                      case let .operation(rhs) = workingTokensMut[index+1],
                      let funcOperation = rhs as? FunctionOperation, // must be subexpression
                      funcOperation.op.name == SubexpressionOperator.shared.name ||
                        funcOperation.op.name == ParametersOperator.shared.name
                else { continue }
                // determine what operator it matches
                guard let op = registeredOps.match(functionToken: token) else { continue }
                // ensure the number of parameters is correct
                guard op.argumentCount.contains(funcOperation.elements.count) else {
                    throw TreeBuildingError.invalidArguments
                }
                // functions are of the highest priority anyway, just replace the first one found.
                workingTokensMut.replaceSubrange(
                    index..<(index+2),
                    with: [.operation(FunctionOperation(op: op, elements: funcOperation.elements))]
                )

                // continue the main loop
                continue mainloop
            }

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
                    guard let op = registeredOps.match(postfixToken: token) else { continue }
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

            // search for first valid implicit infix operation. Rank doesn't matter since there is only one
            // implicit infix operation.
            if let op = registeredOps.registeredImplicitInfixOp {
                for (index, workToken) in workingTokensMut.enumerated().dropLast() {
                    // must be an operation, next work token must also be an operation
                    guard case let .operation(lhs) = workToken,
                          case let .operation(rhs) = workingTokensMut[index+1]
                    else { continue }

                    workingTokensMut.replaceSubrange(
                        index..<(index+2), // [index, index+2) = [index, index+1]
                        with: [.operation(
                            InfixOperation(
                                op: op,
                                lhs: lhs,
                                rhs: rhs
                            )
                        )]
                    )

                    // continue the main loop
                    continue mainloop
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
                    guard let op = registeredOps.match(prefixToken: token) else { continue }
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
                    guard let op = registeredOps.match(infixToken: token) else { continue }
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
}
