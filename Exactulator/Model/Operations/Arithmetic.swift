//
//  Arithmetic.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 17/10/26.
//

import Foundation

/// An operator that performs addition
struct AdditionOperator: InfixOperator {
    var name: String { "add" }
    var matchTokens: Set<Token> { ["+"] }
    var priority: OperatorPriority { .addition }

    static let shared: AdditionOperator = .init()

    func result(lhs: Quantity, rhs: Quantity) throws(OperatorError) -> Quantity {
        // both must be the same unit, otherwise invalid.
        guard let (lhs, rhs) = try? Quantity.convertedToCompatible(lhs: lhs, rhs: rhs) else {
            throw OperatorError.unitError(.incompatibleDimensions(from: rhs.unit, to: lhs.unit))
        }
        return try .init(value: lhs.value.adding(rhs.value), unit: lhs.unit)
    }
}

/// An operator that performs subtraction, including prefix subtraction (`-1`)
struct SubtractionOperator: InfixOperator, PrefixOperator {
    var name: String { "subtract" }
    var matchTokens: Set<Token> { ["-"] } // yes, these two dashes are different.
    var priority: OperatorPriority { .addition }

    static let shared: SubtractionOperator = .init()

    func result(lhs: Quantity, rhs: Quantity) throws(OperatorError) -> Quantity {
        // both must be the same unit, otherwise invalid.
        guard let (lhs, rhs) = try? Quantity.convertedToCompatible(lhs: lhs, rhs: rhs) else {
            throw OperatorError.unitError(.incompatibleDimensions(from: rhs.unit, to: lhs.unit))
        }
        return try .init(value: lhs.value.subtracting(rhs.value), unit: lhs.unit)
    }

    func result(rhs: Quantity) throws(OperatorError) -> Quantity {
        return .init(value: rhs.value.negated(), unit: rhs.unit)
    }
}

/// An operator that performs multiplication, including implicit multiplication (`(2)(3)`)
struct MultiplicationOperator: InfixOperator, ImplicitInfixOperator {
    var name: String { "multiply" }
    var matchTokens: Set<Token> { ["×", "*"] }
    var priority: OperatorPriority { .multiplication }

    static let shared: MultiplicationOperator = .init()

    func result(lhs: Quantity, rhs: Quantity) throws(OperatorError) -> Quantity {
        return try .init(
            value: lhs.value.multiplying(rhs.value),
            unit: lhs.unit.multiplied(by: rhs.unit)
        )
    }
}

/// An operator that performs division
struct DivisionOperator: InfixOperator {
    var name: String { "divide" }
    var matchTokens: Set<Token> { ["÷", "/"] }
    var priority: OperatorPriority { .multiplication }

    static let shared: DivisionOperator = .init()

    /// `lhs / rhs`
    func result(lhs: Quantity, rhs: Quantity) throws(OperatorError) -> Quantity {
        guard rhs.value.asImprecise.value != 0 else { throw OperatorError.mathError }
        return try .init(
            value: lhs.value.dividing(rhs.value),
            unit: lhs.unit.divided(by: rhs.unit)
        )
    }
}

/// An operator that performs division, but has fraction semantics
struct FractionOperator: FunctionOperator {
    var name: String { "divide" }
    var matchTokens: Set<Token> { [] }
    var priority: OperatorPriority { .multiplication }
    var argumentCount: ClosedRange<Int> { 2...2 }

    static let shared: FractionOperator = .init()

    /// `elements.first / elements.last`
    func result(elements: [Quantity]) throws(OperatorError) -> Quantity {
        let numerator = elements.first!
        let denominator = elements.last!

        guard numerator.value.asImprecise.value != 0 else { throw OperatorError.mathError }
        return try .init(
            value: numerator.value.dividing(denominator.value),
            unit: numerator.unit.divided(by: denominator.unit)
        )
    }
}
