//
//  Operation.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Foundation

protocol Operation {
    func solve() -> NumValue
}

struct ValueOperation: Operation {
    var value: NumValue

    func solve() -> NumValue {
        value
    }
}

struct InfixOperation: Operation {
    var op: any InfixOperator
    var lhs: any Operation
    var rhs: any Operation

    func solve() -> NumValue {
        op.result(lhs: lhs.solve(), rhs: rhs.solve())
    }
}

struct PrefixOperation: Operation {
    var op: any PrefixOperator
    var rhs: any Operation

    func solve() -> NumValue {
        op.result(rhs: rhs.solve())
    }
}

struct PostfixOperation: Operation {
    var op: any PostfixOperator
    var lhs: any Operation

    func solve() -> NumValue {
        op.result(lhs: lhs.solve())
    }
}

struct FunctionOperation: Operation {
    var op: any FunctionOperator
    var elements: [any Operation]

    func solve() -> NumValue {
        guard op.argumentCount.contains(elements.count) else { fatalError("Wrong number of elements") }
        return op.result(elements: elements.map { $0.solve() })
    }
}
