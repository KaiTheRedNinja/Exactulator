//
//  Operator.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Foundation

protocol Operator {
    var name: String { get }
    static var shared: Self { get }
}

protocol InfixOperator: Operator {
    func result(lhs: NumValue, rhs: NumValue) -> NumValue
}

protocol PrefixOperator: Operator {
    func result(rhs: NumValue) -> NumValue
}

protocol PostfixOperator: Operator {
    func result(lhs: NumValue) -> NumValue
}

protocol FunctionOperator: Operator {
    var argumentCount: ClosedRange<Int> { get }
    func result(elements: [NumValue]) -> NumValue
}

struct AdditionOperator: InfixOperator {
    var name: String { "add" }

    static let shared: AdditionOperator = .init()

    func result(lhs: NumValue, rhs: NumValue) -> NumValue {
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
}

struct SubtractionOperator: InfixOperator, PrefixOperator {
    var name: String { "subtract" }

    static let shared: SubtractionOperator = .init()

    func result(lhs: NumValue, rhs: NumValue) -> NumValue {
        AdditionOperator.shared.result(lhs: lhs, rhs: result(rhs: rhs))
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

struct MultiplicationOperator: InfixOperator {
    var name: String { "multiply" }

    static let shared: MultiplicationOperator = .init()

    func result(lhs: NumValue, rhs: NumValue) -> NumValue {
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
}

struct DivisionOperator: InfixOperator {
    var name: String { "divide" }

    static let shared: DivisionOperator = .init()

    /// `lhs / rhs`
    func result(lhs: NumValue, rhs: NumValue) -> NumValue {
        MultiplicationOperator.shared.result(lhs: lhs, rhs: reciprocal(rhs: rhs))
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

struct LogOperator: FunctionOperator {
    var name: String { "log" }
    var argumentCount: ClosedRange<Int> { 1...2 }

    static let shared: LogOperator = .init()

    func result(elements: [NumValue]) -> NumValue {
        let conversion: Double = if elements.count == 1 { 1 } else {
            log(elements.last!.asImprecise.value)
        }

        return .imprecise(.init(value: log(elements.first!.asImprecise.value) / conversion))
    }
}

struct SinOperator: FunctionOperator {
    var name: String { "sin" }
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

struct CosOperator: FunctionOperator {
    var name: String { "cos" }
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

struct TanOperator: FunctionOperator {
    var name: String { "tan" }
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
