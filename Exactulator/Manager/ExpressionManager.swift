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

    private enum TreeBuildingError: Error {
        case invalidSyntax
        case unknownOperator
    }

    func computeOperationTree() {
        // convert the expression into tokens
//        let tokens: [Token] = .build(from: expression)
//
//        // we recurse
//        func computeSubexpression(tokenSlice: ArraySlice<Token>) throws -> any Operation {
//            guard !tokenSlice.isEmpty else { throw TreeBuildingError.invalidSyntax }
//
//            if tokenSlice.count == 1, let first = tokenSlice.first {
//                guard case let .numerical(string) = first else { throw TreeBuildingError.invalidSyntax }
//
//                return ValueOperation(value: .bestGuess(value: first.string))
//            }
//
//            // Go through the symbols, finding the highest ranked action. We then take that action and minimise it.
//
//        }
//        do {
//            let finalTree = try computeSubexpression(tokenSlice: tokens[tokens.startIndex..<tokens.endIndex])
//        } catch {
//            print("Tree building error: \(error)")
//        }
    }
}
