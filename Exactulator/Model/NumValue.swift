//
//  NumValue.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Foundation

struct Quantity {
    let value: NumValue
    let unit: Unit

    func converted(to target: Unit) throws -> Quantity {
        guard unit.dimensions == target.dimensions else {
            throw UnitSystemError.incompatibleDimensions(
                from: unit,
                to: target
            )
        }

        return Quantity(
            value: try MultiplicationOperator.shared.result(
                lhs: value,
                rhs: try DivisionOperator.shared.result(
                    lhs: unit.scale,
                    rhs: target.scale
                )
            ),
            unit: target
        )
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
