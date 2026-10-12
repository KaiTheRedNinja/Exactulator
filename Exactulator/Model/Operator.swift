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
