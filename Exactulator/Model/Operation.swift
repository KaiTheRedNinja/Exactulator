//
//  Operation.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Foundation

protocol Operation {
    func solve() throws(OperatorError) -> NumValue
}

struct ValueOperation: Operation {
    var value: NumValue

    func solve() throws(OperatorError) -> NumValue {
        value
    }
}

struct InfixOperation: Operation {
    var op: any InfixOperator
    var lhs: any Operation
    var rhs: any Operation

    func solve() throws(OperatorError) -> NumValue {
        try op.result(lhs: lhs.solve(), rhs: rhs.solve())
    }
}

struct PrefixOperation: Operation {
    var op: any PrefixOperator
    var rhs: any Operation

    func solve() throws(OperatorError) -> NumValue {
        try op.result(rhs: rhs.solve())
    }
}

struct PostfixOperation: Operation {
    var op: any PostfixOperator
    var lhs: any Operation

    func solve() throws(OperatorError) -> NumValue {
        try op.result(lhs: lhs.solve())
    }
}

struct FunctionOperation: Operation {
    var op: any FunctionOperator
    var elements: [any Operation]

    func solve() throws(OperatorError) -> NumValue {
        guard op.argumentCount.contains(elements.count) else { fatalError("Wrong number of elements") }
        let elementsSolved = try elements.map { (elem) throws(OperatorError) in try elem.solve() }
        return try op.result(elements: elementsSolved)
    }
}
