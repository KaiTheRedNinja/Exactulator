//
//  Operation.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Foundation

/// An operation is a mathematical primative that can be evaluated to produce a value
protocol Operation {
    var description: String { get }
    func solve() throws(OperatorError) -> Quantity
}

/// An operation which simply returns a stored value
struct ValueOperation: Operation {
    var value: Quantity

    var description: String {
        value.description
    }

    func solve() throws(OperatorError) -> Quantity {
        value
    }
}

/// An operation which simply returns a stored constant
struct ConstantOperation: Operation {
    var constant: any ConstantOperator

    var description: String {
        constant.name
    }

    func solve() throws(OperatorError) -> Quantity {
        try constant.result()
    }
}

/// An operation that uses an operator to provide a result given a value to the left and right
struct InfixOperation: Operation {
    var op: any InfixOperator
    var lhs: any Operation
    var rhs: any Operation

    var description: String {
        """
        {
            op: \(op.name),
            lhs: \((lhs.description).split(separator: "\n").map { "    \($0)" }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)),
            rhs: \((rhs.description).split(separator: "\n").map { "    \($0)" }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        """
    }

    func solve() throws(OperatorError) -> Quantity {
        try op.result(lhs: lhs.solve(), rhs: rhs.solve())
    }
}

/// An operation that uses an operator to provide a result given a value to the right
struct PrefixOperation: Operation {
    var op: any PrefixOperator
    var rhs: any Operation

    var description: String {
        """
        {
            op: \(op.name),
            rhs: \((rhs.description).split(separator: "\n").map { "    \($0)" }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        """
    }

    func solve() throws(OperatorError) -> Quantity {
        try op.result(rhs: rhs.solve())
    }
}

/// An operation that uses an operator to provide a result given a value to the left
struct PostfixOperation: Operation {
    var op: any PostfixOperator
    var lhs: any Operation

    var description: String {
        """
        {
            op: \(op.name),
            lhs: \((lhs.description).split(separator: "\n").map { "    \($0)" }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        """
    }

    func solve() throws(OperatorError) -> Quantity {
        try op.result(lhs: lhs.solve())
    }
}

/// An operation that uses an operator to perform a function given function parameters
struct FunctionOperation: Operation {
    var op: any FunctionOperator
    var elements: [any Operation]

    var description: String {
        """
        {
            op: \(op.name),
            \(elements.enumerated()
                .map {
                    "\($0.offset): " + ($0.element.description)
                    .split(separator: "\n")
                    .map { "    \($0)" }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                }.joined(separator: ",\n    ")
            )
        }
        """
    }

    func solve() throws(OperatorError) -> Quantity {
        guard op.argumentCount.contains(elements.count) else { throw OperatorError.syntaxError }
        let elementsSolved = try elements.map { (elem) throws(OperatorError) in try elem.solve() }
        return try op.result(elements: elementsSolved)
    }
}
