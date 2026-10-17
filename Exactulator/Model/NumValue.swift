//
//  NumValue.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Foundation

struct Quantity {
    var value: NumValue
    var unit: Unit

    var description: String {
        var desc: String = value.description
        if unit != .one {
            desc += " \(unit.symbol)"
        }
        return desc
    }

    /// Converts this quantity to a different unit
    /// - Parameters:
    ///   - target: The unit to convert to
    ///   - forgiveNoDimension: If either the current unit or the target unit are `Unit.one`, the conversion is done anyway, assuming 1:1
    /// - Returns: The quantity produced by the conversion
    func converted(to target: Unit, forgiveNoDimension: Bool = true) throws -> Quantity {
        // if units are the same, no change
        guard target != unit else { return self }
        // if forgive no dimension and either unit or target is `Unit.one`, allow the conversion
        if forgiveNoDimension, unit == .one || target == .one {
            return .init(value: value, unit: target)
        }

        guard unit.dimensions == target.dimensions else {
            throw UnitSystemError.incompatibleDimensions(
                from: unit,
                to: target
            )
        }

        return try .init(value: value.multiplying(unit.scale.dividing(target.scale)), unit: target)
    }

    static func convertedToCompatible(lhs: Quantity, rhs: Quantity) throws -> (newLhs: Quantity, newRhs: Quantity) {
        // if lhs is not .one, attempt to convert rhs
        if lhs.unit != .one {
            return try (lhs, rhs.converted(to: lhs.unit))
        }
        // if rhs is not .one, attempt to convert lhs
        if rhs.unit != .one {
            return try (lhs.converted(to: rhs.unit), rhs)
        }
        // both are one, no conversion needed
        return (lhs, rhs)
    }
}


enum NumValue: Equatable, ExpressibleByFloatLiteral {
    case exact(Exact)
    case imprecise(Imprecise)

    var isImprecise: Bool {
        if case .imprecise = self { true } else { false }
    }

    var asImprecise: Imprecise {
        switch self {
        case .exact(let exact): exact.asImprecise
        case .imprecise(let imprecise): imprecise
        }
    }

    var description: String {
        switch self {
        case .exact(let exact):
            var result = "\(exact.numerator)"
            if exact.denominator != 1 {
                result += "/\(exact.denominator)"
            }
            if exact.piPower != 0 || exact.surdBase != 1 {
                result = "(\(result))"
                if exact.piPower != 0 {
                    result += " * (π^\(exact.piPower))"
                }
                if exact.surdBase != 1 {
                    result += " * √\(exact.surdBase)"
                }
            }
            return result
        case .imprecise(let imprecise):
            return String(imprecise.value)
        }
    }

    static func bestGuess(value: String) -> NumValue {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = NumValue.imprecise(.init(value: Double(value) ?? .nan))

        guard !value.isEmpty else { return fallback }

        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return fallback }

        let integerPart = String(parts[0])
        let fractionalPart = parts.count == 2 ? String(parts[1]) : ""

        guard !integerPart.isEmpty || !fractionalPart.isEmpty else {
            return fallback
        }

        // Require ordinary decimal notation, optionally with a leading sign.
        let digits = integerPart + fractionalPart
        let unsignedDigits = digits.first == "-" || digits.first == "+"
        ? String(digits.dropFirst())
        : digits

        guard !unsignedDigits.isEmpty,
              unsignedDigits.allSatisfy(\.isNumber),
              unsignedDigits.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let numerator = Int(digits)
                else {
            return fallback
        }

        var denominator = 1
        for _ in fractionalPart {
            let (next, overflow) = denominator.multipliedReportingOverflow(by: 10)
            guard !overflow else { return fallback }
            denominator = next
        }

        return .exact(.init(numerator, div: denominator))
    }

    init(floatLiteral value: Double) {
        self = .bestGuess(value: String(value))
    }
    typealias FloatLiteralType = Double

    func adding(_ rhs: NumValue) throws(OperatorError) -> NumValue {
        // both must be exact
        let fallback = NumValue.imprecise(self.asImprecise + rhs.asImprecise)
        guard case .exact(var lhsExact) = self,
              case .exact(var rhsExact) = rhs
                else {
            return fallback
        }

        do {
            try lhsExact.normalise()
            try rhsExact.normalise()
        } catch {
            throw OperatorError.exactError(error)
        }

        // both must have compatible powers of pi
        guard lhsExact.piPower == rhsExact.piPower && lhsExact.surdBase == rhsExact.surdBase else {
            return fallback
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

    func subtracting(_ rhs: NumValue) throws(OperatorError) -> NumValue {
        try adding(rhs.negated())
    }

    func negated() -> NumValue {
        switch self {
        case .exact(var exact):
            exact.numerator *= -1
            return .exact(exact)
        case .imprecise(let imprecise):
            return .imprecise(.init(value: imprecise.value * -1))
        }
    }

    func multiplying(_ rhs: NumValue) throws(OperatorError) -> NumValue {
        // both must be exact
        guard case .exact(var lhsExact) = self,
              case .exact(var rhsExact) = rhs
                else {
            return .imprecise(.init(value: self.asImprecise.value * rhs.asImprecise.value))
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

    /// `lhs / rhs`
    func dividing(_ rhs: NumValue) throws(OperatorError) -> NumValue {
        guard rhs.asImprecise.value != 0 else { throw OperatorError.mathError }
        return try multiplying(rhs.reciprocal())
    }

    /// `1 / rhs`
    ///
    /// Note that `a/b * sqrt(c) = b/ac * sqrt(c)`
    func reciprocal() -> NumValue {
        switch self {
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

    func toPower(_ power: NumValue) -> NumValue {
        let base = self

        // if power is 1/2, do a square root instead
        // must not be in terms of pi, must not already have a sqrt, must be whole
        guard power != .exact(.init(1, div: 2)) else {
            if case let .exact(exact) = self, exact.denominator == 1, exact.piPower == 0, exact.surdBase == 1 {
                return .exact(.init(1, surd: exact.numerator))
            }
            return .imprecise(.init(value: sqrt(self.asImprecise.value)))
        }

        // Both must be exact, and base must be an integer, and surd must be compatible, otherwise just naive pow
        guard case let .exact(baseExact) = base,
              case let .exact(powerExact) = power,
              powerExact.denominator == 1,
              baseExact.surdBase == 1 || powerExact.numerator%2 == 0 // no surd, or power is even
                else {
            return .imprecise(.init(value: pow(base.asImprecise.value, power.asImprecise.value)))
        }
        let powerVal = powerExact.numerator

        // compute the power
        let newNumerator = if baseExact.surdBase == 1 {
            // if no surd, just square it
            Int(pow(Double(baseExact.numerator), Double(powerVal)))
        } else {
            // if yes surd, base must be a multiple of two, so we take out the surd first
            Int(pow(Double(baseExact.numerator * baseExact.numerator * baseExact.surdBase), Double(powerVal)/2))
        }
        let newDenominator = Int(pow(Double(baseExact.denominator), Double(powerVal)))
        let newPi = baseExact.piPower * powerVal

        return .exact(.init(newNumerator, div: newDenominator, pi: newPi, surd: 1))
    }
}

enum ExactError: Error {
    /// The `Exact` is in an invalid state
    case malformed
    /// Calculating the `Exact` would result in a divide by zero error
    case divideByZero
}

/// A value in the form `n / d * pi^p * sqrt(b)` where:
/// - `n` is an integer
/// - `d` is a positive integer
/// - `p` is an integer
/// - `b` is a positive integer
struct Exact: Equatable {
    /// The numerator of a rational value
    var numerator: Int
    /// The denominator of a rational value. Must be positive.
    var denominator: Int
    /// The power of pi. A value of `0` indicates that this `Exact` is not a multiple of `pi`.
    var piPower: Int
    /// The base of the surd. Must be positive. A value of `1` indicates no surd.
    var surdBase: Int

    /// Creates an `Exact` from its components, WITHOUT normalisation.
    init(numerator: Int, denominator: Int, piPower: Int, surdBase: Int) {
        self.numerator = numerator
        self.denominator = denominator
        self.piPower = piPower
        self.surdBase = surdBase
    }

    /// Convenience initialiser for an `Exact`
    init(_ numerator: Int, div denominator: Int = 1, pi piPower: Int = 0, surd surdBase: Int = 1) {
        self.init(numerator: numerator, denominator: denominator, piPower: piPower, surdBase: surdBase)
        try! self.normalise()
    }

    var asImprecise: Imprecise {
        Imprecise(
            value: (
                (Double(numerator) / Double(denominator))
                * pow(Double.pi, Double(piPower))
                * sqrt(Double(surdBase))
            )
        )
    }

    mutating func normalise() throws(ExactError) {
        // Simplify surd
        guard surdBase >= 1 else { throw ExactError.malformed } // Surd must be at least 1

        var coefficient = 1
        var factor = 2
        while factor * factor <= surdBase {
            let square = factor * factor

            while surdBase % square == 0 {
                coefficient *= factor
                surdBase /= square
            }

            factor += 1
        }
        numerator *= coefficient

        // If zero, zero out the rest
        if numerator == 0 {
            self = .zero
        }

        // Simplify numerator and denominator
        guard denominator != 0 else { throw ExactError.divideByZero } // Denominator cannot be zero
        let gcd = gcd(numerator, denominator)
        numerator = numerator / gcd
        denominator = denominator / gcd
        if denominator < 0 { // if denominator is negative, flip both. Denominator must be positive.
            numerator *= -1
            denominator *= -1
        }
    }

    func normalised() throws(ExactError) -> Exact {
        var copy = self
        try copy.normalise()
        return copy
    }

    static let zero = Exact(
        numerator: 0,
        denominator: 1,
        piPower: 0,
        surdBase: 1
    )
}

struct Imprecise: Equatable, ExpressibleByFloatLiteral, AdditiveArithmetic {
    var value: Double

    init(value: Double) {
        self.value = value
    }

    static let zero: Imprecise = .zero

    static func + (lhs: Imprecise, rhs: Imprecise) -> Imprecise {
        .init(value: lhs.value + rhs.value)
    }

    static func - (lhs: Imprecise, rhs: Imprecise) -> Imprecise {
        .init(value: lhs.value - rhs.value)
    }

    typealias FloatLiteralType = Double
    init(floatLiteral value: Double) {
        self.value = value
    }
}

func gcd(_ a: Int, _ b: Int) -> Int {
    var num1 = a
    var num2 = b

    if a == b { return a }

    while num2 != 0 {
        let remainder = num1 % num2
        num1 = num2
        num2 = remainder
    }

    return num1
}

func lcm(_ a: Int, _ b: Int) -> Int {
    return (a * b) / gcd(a, b)
}
