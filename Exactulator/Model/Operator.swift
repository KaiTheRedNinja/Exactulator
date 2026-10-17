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

/// An operator that performs the sine function
struct SinOperator: FunctionOperator {
    var name: String { "sin" }
    var matchTokens: Set<Token> { ["sin"] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...1 }

    static let shared: SinOperator = .init()

    private struct SpecialSine {
        /// The angle as a reduced fraction of pi, in [0, 2).
        let angleNumerator: Int
        let angleDenominator: Int

        /// The exact sine value.
        let value: Exact
    }

    private let specialSines: [SpecialSine] = [
        // sin(0) = 0.
        .init(angleNumerator: 0, angleDenominator: 1, value: Exact(0)),
        // sin(pi/6) = 1/2.
        .init(angleNumerator: 1, angleDenominator: 6, value: Exact(1, div: 2)),
        // sin(pi/4) = sqrt(2)/2.
        .init(angleNumerator: 1, angleDenominator: 4, value: Exact(1, div: 2, surd: 2)),
        // sin(pi/3) = sqrt(3)/2.
        .init(angleNumerator: 1, angleDenominator: 3, value: Exact(1, div: 2, surd: 3)),
        // sin(pi/2) = 1.
        .init(angleNumerator: 1, angleDenominator: 2, value: Exact(1)),
        // sin(2pi/3) = sqrt(3)/2.
        .init(angleNumerator: 2, angleDenominator: 3, value: Exact(1, div: 2, surd: 3)),
        // sin(3pi/4) = sqrt(2)/2.
        .init(angleNumerator: 3, angleDenominator: 4, value: Exact(1, div: 2, surd: 2)),
        // sin(5pi/6) = 1/2.
        .init(angleNumerator: 5, angleDenominator: 6, value: Exact(1, div: 2)),
        // sin(pi) = 0.
        .init(angleNumerator: 1, angleDenominator: 1, value: Exact(0)),
        // sin(7pi/6) = -1/2.
        .init(angleNumerator: 7, angleDenominator: 6, value: Exact(-1, div: 2)),
        // sin(5pi/4) = -sqrt(2)/2.
        .init(angleNumerator: 5, angleDenominator: 4, value: Exact(-1, div: 2, surd: 2)),
        // sin(4pi/3) = -sqrt(3)/2.
        .init(angleNumerator: 4, angleDenominator: 3, value: Exact(-1, div: 2, surd: 3)),
        // sin(3pi/2) = -1.
        .init(angleNumerator: 3, angleDenominator: 2, value: Exact(-1)),
        // sin(5pi/3) = -sqrt(3)/2.
        .init(angleNumerator: 5, angleDenominator: 3, value: Exact(-1, div: 2, surd: 3)),
        // sin(7pi/4) = -sqrt(2)/2.
        .init(angleNumerator: 7, angleDenominator: 4, value: Exact(-1, div: 2, surd: 2)),
        // sin(11pi/6) = -1/2.
        .init(angleNumerator: 11, angleDenominator: 6, value: Exact(-1, div: 2))
    ]

    func specialSine(for angle: Exact) -> Exact? {
        // if angle is zero, return the zero case. Else it must be a multiple of pi.
        if angle == .zero { return .zero }
        guard angle.piPower == 1, angle.surdBase == 1 else {
            return nil
        }

        // Reduce the angle modulo 2pi.
        let period = 2 * angle.denominator
        var numerator = angle.numerator % period

        if numerator < 0 {
            numerator += period
        }

        // numerator and denominator are guaranteed to be in canonical form, no need to GCD again
        return specialSines.first {
            $0.angleNumerator == numerator
            && $0.angleDenominator == angle.denominator
        }?.value
    }

    // note that both input and output to a sinusoidal function are unitless
    // so no unit conversion needed, just use as-is
    func result(elements: [Quantity]) -> Quantity {
        let input = elements.first!
        if case let .exact(angle) = input.value, let exactResult = specialSine(for: angle) {
            return .init(value: .exact(exactResult), unit: .one)
        }

        return .init(value: .imprecise(.init(value: sin(input.value.asImprecise.value))), unit: .one)
    }
}

/// An operator that performs the cosine function
struct CosOperator: FunctionOperator {
    var name: String { "cos" }
    var matchTokens: Set<Token> { ["cos"] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...1 }

    static let shared: CosOperator = .init()

    func result(elements: [Quantity]) -> Quantity {
        let input = elements.first!
        if case let .exact(angle) = input.value, angle.piPower == 1, angle.surdBase == 1 {
            // pi/2 - (n/d)pi = ((d - 2n) / 2d)pi.
            let complementaryAngle = Exact(
                angle.denominator - 2 * angle.numerator,
                div: 2 * angle.denominator,
                pi: 1
            )

            return SinOperator.shared.result(elements: [.init(value: .exact(complementaryAngle), unit: .one)])
        }

        return .init(value: .imprecise(.init(value: cos(input.value.asImprecise.value))), unit: .one)
    }
}

/// An operator that performs the tangent function
struct TanOperator: FunctionOperator {
    var name: String { "tan" }
    var matchTokens: Set<Token> { ["tan"] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...1 }

    static let shared: TanOperator = .init()

    func result(elements: [Quantity]) -> Quantity {
        let input = elements.first!
        if case let .exact(angle) = input.value {
            let sine = SinOperator.shared.result(elements: [.init(value: .exact(angle), unit: .one)])
            let cosine = CosOperator.shared.result(elements: [.init(value: .exact(angle), unit: .one)])

            // Tangent is undefined wherever cosine is zero.
            if case .exact(let c) = cosine.value, c.numerator == 0 {
                fatalError("Undefined, cosine is zero")
            }

            switch (sine.value, cosine.value) {
            case (.exact(let s), .exact(let c)):
                // (sn/sd * sqrt(sb)) / (cn/cd * sqrt(cb))
                // = (sn*cd)/(sd*cn*cb) * sqrt(sb*cb)
                // we do this directly instead of using division to reduce unnescessary normalisations
                return .init(value: .exact(
                    Exact(
                        s.numerator * c.denominator,
                        div: s.denominator * c.numerator * c.surdBase,
                        surd: s.surdBase * c.surdBase
                    )
                ), unit: .one)
            default: break
            }
        }

        return .init(value: .imprecise(.init(value: tan(input.value.asImprecise.value))), unit: .one)
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
    var matchTokens: Set<Token> { ["as"] }
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
