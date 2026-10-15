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
    /// A shared instance of this operator
    static var shared: Self { get }
}

/// An error in executing an operation
enum OperatorError: Error {
    /// An error with Exact
    case exactError(ExactError)
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

/// An operator placed between two values, e.g. `1+1`
protocol InfixOperator: Operator {
    /// Returns the result of this operation given the values to the left and right of the operator
    func result(lhs: NumValue, rhs: NumValue) throws(OperatorError) -> NumValue
}

/// An operator placed before a value, e.g. `-1`
protocol PrefixOperator: Operator {
    /// Returns the result of this operation given the value to the right of the operator
    func result(rhs: NumValue) throws(OperatorError) -> NumValue
}

/// An operator placed after a value, e.g. `3!`
protocol PostfixOperator: Operator {
    /// Returns the result of this operation given the value to the left of the operator
    func result(lhs: NumValue) throws(OperatorError) -> NumValue
}

/// An operator that represents a function
protocol FunctionOperator: Operator {
    /// The number of arguments that this operator accepts
    var argumentCount: ClosedRange<Int> { get }
    /// Returns the result of this operation given the parameters passed to the operator.
    func result(elements: [NumValue]) throws(OperatorError) -> NumValue
}

/// An implicit infix operator. There may only be one of these. Behaviour is used when
/// no operator is placed between two values, such as `(2)(3)`.
protocol ImplicitInfixOperator: InfixOperator {
}

/// An operator which just matches directly to a value
protocol ConstantOperator: Operator {
    /// Returns the constant value
    func result() throws(OperatorError) -> NumValue
}

/// An operator that performs addition
struct AdditionOperator: InfixOperator {
    var name: String { "add" }
    var matchTokens: Set<Token> { ["+"] }
    var priority: OperatorPriority { .addition }

    static let shared: AdditionOperator = .init()

    func result(lhs: NumValue, rhs: NumValue) throws(OperatorError) -> NumValue {
        // both must be exact
        guard case .exact(var lhsExact) = lhs,
              case .exact(var rhsExact) = rhs
                else {
            return .imprecise(lhs.asImprecise + rhs.asImprecise)
        }

        do {
            try lhsExact.normalise()
            try rhsExact.normalise()
        } catch {
            throw OperatorError.exactError(error)
        }

        // both must have compatible powers of pi
        guard lhsExact.piPower == rhsExact.piPower && lhsExact.surdBase == rhsExact.surdBase else {
            return .imprecise(lhs.asImprecise + rhs.asImprecise)
        }

        // cross-multiply to sum together
        do {
            let exactSum = try Exact(
                numerator: (lhsExact.numerator * rhsExact.denominator) + (rhsExact.numerator * lhsExact.denominator),
                denominator: lhsExact.denominator * rhsExact.denominator,
                piPower: lhsExact.piPower,
                surdBase: lhsExact.surdBase
            )
            .normalised()
            return .exact(exactSum)
        } catch {
            throw OperatorError.exactError(error)
        }
    }
}

/// An operator that performs subtraction, including prefix subtraction (`-1`)
struct SubtractionOperator: InfixOperator, PrefixOperator {
    var name: String { "subtract" }
    var matchTokens: Set<Token> { ["-"] } // yes, these two dashes are different.
    var priority: OperatorPriority { .addition }

    static let shared: SubtractionOperator = .init()

    func result(lhs: NumValue, rhs: NumValue) throws(OperatorError) -> NumValue {
        try AdditionOperator.shared.result(lhs: lhs, rhs: result(rhs: rhs))
    }

    func result(rhs: NumValue) -> NumValue {
        switch rhs {
        case .exact(var exact):
            exact.numerator *= -1
            return .exact(exact)
        case .imprecise(let imprecise):
            return .imprecise(.init(value: imprecise.value * -1))
        }
    }
}

/// An operator that performs multiplication, including implicit multiplication (`(2)(3)`)
struct MultiplicationOperator: InfixOperator, ImplicitInfixOperator {
    var name: String { "multiply" }
    var matchTokens: Set<Token> { ["×", "*"] }
    var priority: OperatorPriority { .multiplication }

    static let shared: MultiplicationOperator = .init()

    func result(lhs: NumValue, rhs: NumValue) throws(OperatorError) -> NumValue {
        // both must be exact
        guard case .exact(var lhsExact) = lhs,
              case .exact(var rhsExact) = rhs
                else {
            return .imprecise(.init(value: lhs.asImprecise.value * rhs.asImprecise.value))
        }

        do {
            try lhsExact.normalise()
            try rhsExact.normalise()
        } catch {
            throw OperatorError.exactError(error)
        }

        // If either has zero as a numerator, we can just return 0 immediately
        if lhsExact.numerator == 0 || rhsExact.numerator == 0 {
            return .exact(.zero)
        }

        // multiply everything
        do {
            let exactProduct = try Exact(
                numerator: lhsExact.numerator * rhsExact.numerator,
                denominator: lhsExact.denominator * rhsExact.denominator,
                piPower: lhsExact.piPower + rhsExact.piPower,
                surdBase: lhsExact.surdBase * rhsExact.surdBase
            )
                .normalised()
            return .exact(exactProduct)
        } catch {
            throw OperatorError.exactError(error)
        }
    }
}

/// An operator that performs division
struct DivisionOperator: InfixOperator {
    var name: String { "divide" }
    var matchTokens: Set<Token> { ["÷", "/"] }
    var priority: OperatorPriority { .multiplication }

    static let shared: DivisionOperator = .init()

    /// `lhs / rhs`
    func result(lhs: NumValue, rhs: NumValue) throws(OperatorError) -> NumValue {
        guard rhs.asImprecise.value != 0 else { throw OperatorError.mathError }

        return try MultiplicationOperator.shared.result(lhs: lhs, rhs: reciprocal(rhs: rhs))
    }

    /// `1 / rhs`
    ///
    /// Note that `a/b * sqrt(c) = b/ac * sqrt(c)`
    func reciprocal(rhs: NumValue) -> NumValue {
        switch rhs {
        case .exact(let exact):
            return .exact(
                .init(
                    numerator: exact.denominator,
                    denominator: exact.numerator * exact.surdBase,
                    piPower: exact.piPower * -1,
                    surdBase: exact.surdBase
                )
            )
        case .imprecise(let imprecise):
            return .imprecise(.init(value: 1 / imprecise.value))
        }
    }
}

/// Represents a bracket, which is essentially the function `f(x) = x`
struct SubexpressionOperator: FunctionOperator {
    var name: String { "subexpression" }
    var matchTokens: Set<Token> { [] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...1 }

    static let shared: SubexpressionOperator = .init()

    func result(elements: [NumValue]) throws(OperatorError) -> NumValue {
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

    func result(elements: [NumValue]) throws(OperatorError) -> NumValue {
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

    func result(elements: [NumValue]) throws(OperatorError) -> NumValue {
        let conversion: Double
        if elements.count == 1 {
            conversion = 1
        } else {
            let last = elements.last!.asImprecise.value
            guard last > 0 else { throw OperatorError.mathError }
            conversion = log(last)
        }

        let first = elements.first!.asImprecise.value
        guard first > 0 else { throw OperatorError.mathError }
        return .imprecise(.init(value: log(first) / conversion))
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

    func result(elements: [NumValue]) -> NumValue {
        let input = elements.first!
        if case let .exact(angle) = input, let exactResult = specialSine(for: angle) {
            return .exact(exactResult)
        }

        return .imprecise(.init(value: sin(input.asImprecise.value)))
    }
}

/// An operator that performs the cosine function
struct CosOperator: FunctionOperator {
    var name: String { "cos" }
    var matchTokens: Set<Token> { ["cos"] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...1 }

    static let shared: CosOperator = .init()

    func result(elements: [NumValue]) -> NumValue {
        let input = elements.first!
        if case let .exact(angle) = input, angle.piPower == 1, angle.surdBase == 1 {
            // pi/2 - (n/d)pi = ((d - 2n) / 2d)pi.
            let complementaryAngle = Exact(
                angle.denominator - 2 * angle.numerator,
                div: 2 * angle.denominator,
                pi: 1
            )

            return SinOperator.shared.result(elements: [.exact(complementaryAngle)])
        }

        return .imprecise(.init(value: cos(input.asImprecise.value)))
    }
}

/// An operator that performs the tangent function
struct TanOperator: FunctionOperator {
    var name: String { "tan" }
    var matchTokens: Set<Token> { ["tan"] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...1 }

    static let shared: TanOperator = .init()

    func result(elements: [NumValue]) -> NumValue {
        let input = elements.first!
        if case let .exact(angle) = input {
            let sine = SinOperator.shared.result(elements: [.exact(angle)])
            let cosine = CosOperator.shared.result(elements: [.exact(angle)])

            // Tangent is undefined wherever cosine is zero.
            if case .exact(let c) = cosine, c.numerator == 0 {
                fatalError("Undefined, cosine is zero")
            }

            switch (sine, cosine) {
            case (.exact(let s), .exact(let c)):
                // (sn/sd * sqrt(sb)) / (cn/cd * sqrt(cb))
                // = (sn*cd)/(sd*cn*cb) * sqrt(sb*cb)
                // we do this directly instead of using division to reduce unnescessary normalisations
                return .exact(
                    Exact(
                        s.numerator * c.denominator,
                        div: s.denominator * c.numerator * c.surdBase,
                        surd: s.surdBase * c.surdBase
                    )
                )
            default: break
            }
        }

        return .imprecise(.init(value: tan(input.asImprecise.value)))
    }
}

/// An operator that performs the square root function
struct SquareRootOperator: FunctionOperator {
    var name: String { "sqrt" }
    var matchTokens: Set<Token> { ["sqrt", "√"] }
    var priority: OperatorPriority { .bracket }
    var argumentCount: ClosedRange<Int> { 1...1 }

    static let shared: SquareRootOperator = .init()

    func result(elements: [NumValue]) -> NumValue {
        let input = elements.first!
        // must not be in terms of pi, must not already have a sqrt, must be whole
        if case let .exact(exact) = input, exact.denominator == 1, exact.piPower == 0, exact.surdBase == 1 {
            return .exact(.init(1, surd: exact.numerator))
        }

        return .imprecise(.init(value: sqrt(input.asImprecise.value)))
    }
}

/// The constant Pi
struct PiOperator: ConstantOperator {
    var name: String { "pi" }
    var matchTokens: Set<Token> { ["pi", "π"] }
    var priority: OperatorPriority { .bracket }

    static let shared: PiOperator = .init()

    func result() -> NumValue {
        .exact(.init(1, pi: 1))
    }
}
