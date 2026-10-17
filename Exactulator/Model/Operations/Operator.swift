//
//  Operator.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Foundation

/// An operator, which can perform mathematical operations on values
protocol Operator {
    /// The name of the operator
    var name: String { get }
    /// What tokens match to this operator
    var matchTokens: Set<Token> { get }
    /// The operator's calculation priority
    var priority: OperatorPriority { get }
}

/// An error in executing an operation
enum OperatorError: Error {
    /// An error with Exact
    case exactError(ExactError)
    /// A unit error
    case unitError(UnitSystemError)
    /// Math error
    case mathError
    /// Syntax error
    case syntaxError
}

/// Operator priority, higher number = higher priority. Follows PEMDAS.
enum OperatorPriority: Int {
    /// Brackets and functions
    case bracket = 4
    /// Exponents and square roots
    case exponential = 3
    /// Multiplication and division
    case multiplication = 2
    /// Addition and subtraction
    case addition = 1
}

/// A type with a shared instance
protocol Shared {
    /// The shared instance of this type
    static var shared: Self { get }
}

/// An operator placed between two values, e.g. `1+1`
protocol InfixOperator: Operator, Shared {
    /// Returns the result of this operation given the values to the left and right of the operator
    func result(lhs: Quantity, rhs: Quantity) throws(OperatorError) -> Quantity
}

/// An operator placed before a value, e.g. `-1`
protocol PrefixOperator: Operator, Shared {
    /// Returns the result of this operation given the value to the right of the operator
    func result(rhs: Quantity) throws(OperatorError) -> Quantity
}

/// An operator placed after a value, e.g. `3!`
protocol PostfixOperator: Operator, Shared {
    /// Returns the result of this operation given the value to the left of the operator
    func result(lhs: Quantity) throws(OperatorError) -> Quantity
}

/// An operator that represents a function
protocol FunctionOperator: Operator, Shared {
    /// The number of arguments that this operator accepts
    var argumentCount: ClosedRange<Int> { get }
    /// Returns the result of this operation given the parameters passed to the operator.
    func result(elements: [Quantity]) throws(OperatorError) -> Quantity
}

/// An implicit infix operator. There may only be one of these. Behaviour is used when
/// no operator is placed between two values, such as `(2)(3)`.
protocol ImplicitInfixOperator: InfixOperator, Shared {
}

/// An operator which just matches directly to a value
protocol ConstantOperator: Operator {
    /// Returns the constant value
    func result() throws(OperatorError) -> Quantity
}

/// Represents a bracket, which is essentially the function `f(x) = x`
struct SubexpressionOperator: FunctionOperator {
    var name: String { "subexpression" }
    var matchTokens: Set<Token> { [] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...1 }

    static let shared: SubexpressionOperator = .init()

    func result(elements: [Quantity]) throws(OperatorError) -> Quantity {
        return elements.first!
    }
}

/// Represents a bracket with commas inside of it, which basically mean these are function parameters
struct ParametersOperator: FunctionOperator {
    var name: String { "subexpression" }
    var matchTokens: Set<Token> { [] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...100_000 }

    static let shared: ParametersOperator = .init()

    func result(elements: [Quantity]) throws(OperatorError) -> Quantity {
        throw OperatorError.syntaxError
    }
}

/// A constant value operator
struct ConstValueOperator: ConstantOperator {
    var name: String
    var value: NumValue
    var matchTokens: Set<Token>
    var priority: OperatorPriority { fatalError("Constant value has no priority") }

    static let pi: ConstValueOperator = .init(
        name: "pi",
        value: .exact(.init(1, pi: 1)),
        matchTokens: ["pi", "π"]
    )

    static let euler: ConstValueOperator = .init(
        name: "e",
        value: .imprecise(.init(value: 2.7182818)),
        matchTokens: ["e", "ℇ"]
    )

    func result() -> Quantity {
        .init(value: value, unit: .one)
    }
}

/// An operator which is a unit.
///
/// Because of a quirk of the system, we can actually calculate treat units as values, because a value like `1m` is
/// interpreted as `1 * m`, which would result in `1` of unit `m`.
struct UnitOperator: ConstantOperator {
    var name: String
    var unit: Unit
    var matchTokens: Set<Token>
    var priority: OperatorPriority { fatalError("Unit has no priority") }

    init(unit: Unit, matchTokens: Set<Token>) {
        self.name = unit.symbol
        self.unit = unit
        self.matchTokens = matchTokens
    }

    func result() -> Quantity {
        .init(value: .exact(.init(1)), unit: unit)
    }
}

/// An operator which converts a value on the left to the unit on the right
struct UnitConvertOperator: InfixOperator {
    var name: String { "as" }
    var matchTokens: Set<Token> { ["as", "→"] }
    var priority: OperatorPriority { .multiplication }

    static let shared: UnitConvertOperator = .init()

    func result(lhs: Quantity, rhs: Quantity) throws(OperatorError) -> Quantity {
        // RHS has to be a unit. That means its value is 1 and unit isn't .one.
        guard rhs.value.asImprecise.value == 1, rhs.unit != .one else {
            throw OperatorError.syntaxError
        }

        // Attempt to convert lhs into rhs.unit
        do {
            let result = try lhs.converted(to: rhs.unit)
            return result
        } catch {
            if let error = error as? UnitSystemError {
                throw OperatorError.unitError(error)
            }
            throw OperatorError.mathError
        }
    }
}
