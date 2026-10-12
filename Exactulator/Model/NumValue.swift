//
//  NumValue.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Foundation

enum NumValue {
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

    /// `lhs + rhs`
    static func add(lhs: Self, rhs: Self) -> Self {
        // both must be exact
        guard case .exact(var lhsExact) = lhs,
              case .exact(var rhsExact) = rhs
        else {
            return .imprecise(lhs.asImprecise + rhs.asImprecise)
        }

        lhsExact.normalise()
        rhsExact.normalise()

        // both must have compatible powers of pi
        guard lhsExact.piPower == rhsExact.piPower && lhsExact.surdBase == rhsExact.surdBase else {
            return .imprecise(lhs.asImprecise + rhs.asImprecise)
        }

        // cross-multiply to sum together
        let exactSum = Exact(
            numerator: (lhsExact.numerator * rhsExact.denominator) + (rhsExact.numerator * lhsExact.denominator),
            denominator: lhsExact.numerator * rhsExact.denominator,
            piPower: lhsExact.piPower,
            surdBase: lhsExact.surdBase
        )
        return .exact(exactSum)
    }

    /// `0 - rhs`
    static func negate(rhs: Self) -> Self {
        switch rhs {
        case .exact(var exact):
            exact.numerator *= -1
            return .exact(exact)
        case .imprecise(let imprecise):
            return .imprecise(.init(value: imprecise.value * -1))
        }
    }

    /// `lhs - rhs`
    static func subtract(lhs: Self, rhs: Self) -> Self {
        add(lhs: lhs, rhs: negate(rhs: rhs))
    }

    /// `lhs * rhs`
    static func multiply(lhs: Self, rhs: Self) -> Self {
        // both must be exact
        guard case .exact(var lhsExact) = lhs,
              case .exact(var rhsExact) = rhs
                else {
            return .imprecise(lhs.asImprecise + rhs.asImprecise)
        }

        lhsExact.normalise()
        rhsExact.normalise()

        // If either has zero as a numerator, we can just return 0 immediately
        if lhsExact.numerator == 0 || rhsExact.numerator == 0 {
            return .exact(.zero)
        }

        // multiply everything
        let exactProduct = Exact(
            numerator: lhsExact.numerator * rhsExact.numerator,
            denominator: lhsExact.denominator * rhsExact.denominator,
            piPower: lhsExact.piPower + rhsExact.piPower,
            surdBase: lhsExact.surdBase * rhsExact.surdBase
        )
        return .exact(exactProduct)
    }

    /// `lhs / rhs`
    static func divide(lhs: Self, rhs: Self) -> Self {
        multiply(lhs: lhs, rhs: reciprocal(rhs: rhs))
    }

    /// `1 / rhs`
    ///
    /// Note that `a/b * sqrt(c) = b/ac * sqrt(c)`
    static func reciprocal(rhs: Self) -> Self {
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

/// A value in the form `n / d * pi^p * sqrt(b)` where:
/// - `n` is an integer
/// - `d` is a positive integer
/// - `p` is an integer
/// - `b` is a positive integer
struct Exact {
    /// The numerator of a rational value
    var numerator: Int
    /// The denominator of a rational value. Must be positive.
    var denominator: Int
    /// The power of pi. A value of `0` indicates that this `Exact` is not a multiple of `pi`.
    var piPower: Int
    /// The base of the surd. Must be positive. A value of `1` indicates no surd.
    var surdBase: Int

    /// Creates an `Exact` from its components, then normalises everything.
    init(numerator: Int, denominator: Int, piPower: Int, surdBase: Int) {
        self.numerator = numerator
        self.denominator = denominator
        self.piPower = piPower
        self.surdBase = surdBase

        self.normalise()
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

    mutating func normalise() {
        // Simplify numerator and denominator
        guard denominator != 0 else { fatalError("Divide by zero error") } // Denominator cannot be zero
        let gcd = gcd(numerator, denominator)
        numerator = numerator / gcd
        denominator = denominator / gcd

        // Simplify surd
        guard surdBase >= 1 else { fatalError("Format error with surd") } // Surd must be at least 1

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
    }

    func normalised() -> Exact {
        var copy = self
        copy.normalise()
        return copy
    }

    static let zero = Exact(
        numerator: 0,
        denominator: 1,
        piPower: 0,
        surdBase: 1
    )
}

struct Imprecise: AdditiveArithmetic {
    var value: Double

    static let zero: Imprecise = .zero

    static func + (lhs: Imprecise, rhs: Imprecise) -> Imprecise {
        .init(value: lhs.value + rhs.value)
    }

    static func - (lhs: Imprecise, rhs: Imprecise) -> Imprecise {
        .init(value: lhs.value - rhs.value)
    }
}

func gcd(_ a: Int, _ b: Int) -> Int {
    var num1 = a
    var num2 = b

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
