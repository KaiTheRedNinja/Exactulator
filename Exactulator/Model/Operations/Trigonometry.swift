//
//  Trigonometry.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 17/10/26.
//

import Foundation

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
