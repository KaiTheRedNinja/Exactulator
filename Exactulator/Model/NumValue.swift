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
