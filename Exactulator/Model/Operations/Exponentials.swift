//
//  Exponentials.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 17/10/26.
//

import Foundation

/// An operator that performs the natural log function. Optionally takes a second parameter for the base.
struct LogOperator: FunctionOperator {
    var name: String { "log" }
    var matchTokens: Set<Token> { ["log"] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...2 }

    static let shared: LogOperator = .init()

    func result(elements: [Quantity]) throws(OperatorError) -> Quantity {
        let conversion: Double
        if elements.count == 1 {
            conversion = 1
        } else {
            let last = elements.last!.value.asImprecise.value
            guard last > 0 else { throw OperatorError.mathError }
            conversion = log(last)
        }

        let first = elements.first!.value.asImprecise.value
        guard first > 0 else { throw OperatorError.mathError }
        return .init(value: .imprecise(.init(value: log(first) / conversion)), unit: .one)
    }
}

/// An operator that performs the square root function
struct SquareRootOperator: FunctionOperator {
    var name: String { "sqrt" }
    var matchTokens: Set<Token> { ["sqrt", "√"] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...1 }

    static let shared: SquareRootOperator = .init()

    // TODO: get fractional units working
    func result(elements: [Quantity]) throws(OperatorError) -> Quantity {
        let input = elements.first!
        // must not be in terms of pi, must not already have a sqrt, must be whole
        if case let .exact(exact) = input.value, exact.denominator == 1, exact.piPower == 0, exact.surdBase == 1 {
            return .init(value: .exact(.init(1, surd: exact.numerator)), unit: .one)
        }

        guard input.value.asImprecise.value >= 0 else { throw OperatorError.mathError }

        return .init(value: input.value.toPower(.exact(.init(1, div: 2))), unit: .one)
    }
}

/// An operator that performs the power function
struct PowerOperator: FunctionOperator {
    var name: String { "pow" }
    var matchTokens: Set<Token> { ["pow"] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...2 }

    static let shared: PowerOperator = .init()

    func result(elements: [Quantity]) -> Quantity {
        let base = elements.first!
        let power = if elements.count > 1 { elements.last! } else { Quantity(value: 2.0, unit: .one) }

        let resultValue = base.value.toPower(power.value)
        let resultUnit = if case let .exact(exactPower) = power.value, exactPower.denominator == 1 {
            base.unit.raised(to: exactPower.numerator)
        } else {
            Unit.one
        }

        return .init(value: resultValue, unit: resultUnit)
    }
}
