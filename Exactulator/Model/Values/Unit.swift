//
//  Unit.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 16/10/26.
//

import Foundation

struct Dimensions: Equatable, Hashable {
    var length: Int = 0
    var mass: Int = 0
    var time: Int = 0

    static let dimensionless = Dimensions()
    static let length = Dimensions(length: 1)
    static let mass = Dimensions(mass: 1)
    static let time = Dimensions(time: 1)

    static func * (lhs: Dimensions, rhs: Dimensions) -> Dimensions {
        Dimensions(
            length: lhs.length + rhs.length,
            mass: lhs.mass + rhs.mass,
            time: lhs.time + rhs.time
        )
    }

    static func / (lhs: Dimensions, rhs: Dimensions) -> Dimensions {
        Dimensions(
            length: lhs.length - rhs.length,
            mass: lhs.mass - rhs.mass,
            time: lhs.time - rhs.time
        )
    }

    func raised(to exponent: Int) -> Dimensions {
        Dimensions(
            length: length * exponent,
            mass: mass * exponent,
            time: time * exponent
        )
    }

    var isDimensionless: Bool {
        self == .dimensionless
    }
}

struct Unit: Equatable {
    let symbol: String
    let scale: NumValue
    let dimensions: Dimensions

    static let one = Unit(
        symbol: "1",
        scale: 1.0,
        dimensions: .dimensionless
    )

    /// Scale is the multiplier converting this unit to SI base units.
    init(
        symbol: String,
        scale: NumValue,
        dimensions: Dimensions
    ) {
        precondition(!symbol.isEmpty, "Unit symbol cannot be empty")
        precondition(scale.asImprecise.value.isFinite && scale.asImprecise.value > 0, "Scale must be positive and finite")

        self.symbol = symbol
        self.scale = scale
        self.dimensions = dimensions
    }

    func multiplied(by other: Unit) -> Unit {
        if self == .one { return other }
        if other == .one { return self }
        return Unit(
            symbol: "\(symbol)·\(other.symbol)",
            scale: try! scale.multiplying(other.scale),
            dimensions: dimensions * other.dimensions
        )
    }

    func divided(by other: Unit) -> Unit {
        if other == .one { return self }
        return Unit(
            symbol: "\(symbol)/\(other.symbol)",
            scale: try! scale.dividing(other.scale),
            dimensions: dimensions / other.dimensions
        )
    }

    func raised(to exponent: Int) -> Unit {
        Unit(
            symbol: "(\(symbol))^\(exponent)",
            scale: scale.toPower(.exact(.init(exponent))),
            dimensions: dimensions.raised(to: exponent)
        )
    }
}

// MARK: - Unit System

enum UnitSystemError: Error, LocalizedError {
    case unknownUnit(String)
    case duplicateUnit(String)
    case incompatibleDimensions(from: Unit, to: Unit)

    var errorDescription: String? {
        switch self {
        case .unknownUnit(let symbol):
            return "Unknown unit: \(symbol)"
        case .duplicateUnit(let symbol):
            return "Unit already exists: \(symbol)"
        case .incompatibleDimensions(let from, let to):
            return "Cannot convert \(from.symbol) to \(to.symbol): dimensions differ."
        }
    }
}

struct UnitSystem {
    private(set) var units: [String: Unit] = [:]

    init() {
        // SI base units.
        register(Unit(symbol: "m", scale: 1.0, dimensions: .length))
        register(Unit(symbol: "kg", scale: 1.0, dimensions: .mass))
        register(Unit(symbol: "s", scale: 1.0, dimensions: .time))

        // Dimensionless unit.
        register(Unit.one)

        // Common scaled units.
        try! define(symbol: "km", from: "m", factor: 1_000.0)
        try! define(symbol: "cm", from: "m", factor: 0.01)
        try! define(symbol: "mm", from: "m", factor: 0.001)
        try! define(symbol: "mi", from: "m", factor: 1_609.344)
        try! define(symbol: "ft", from: "m", factor: 0.3048)
        try! define(symbol: "in", from: "m", factor: 0.0254)

        try! define(symbol: "ms", from: "s", factor: 0.001)
        try! define(symbol: "min", from: "s", factor: 60.0)
        try! define(symbol: "h", from: "s", factor: 3_600.0)

        try! define(symbol: "g", from: "kg", factor: 0.001)
        try! define(symbol: "lb", from: "kg", factor: 0.45359237)

        // Derived unit: Hz = 1/s.
        let second = units["s"]!
        let one = units["1"]!
        let hertz = one.divided(by: second)
        try! define(symbol: "Hz", as: hertz)
    }

    private mutating func register(_ unit: Unit) {
        units[unit.symbol] = unit
    }

    func unit(_ symbol: String) throws -> Unit {
        guard let unit = units[symbol] else {
            throw UnitSystemError.unknownUnit(symbol)
        }
        return unit
    }

    /// Define a new unit as a scaled version of an existing unit.
    mutating func define(
        symbol: String,
        from baseSymbol: String,
        factor: NumValue
    ) throws {
        let base = try unit(baseSymbol)
        let derived = Unit(
            symbol: symbol,
            scale: try base.scale.multiplying(factor),
            dimensions: base.dimensions
        )
        try define(symbol: symbol, as: derived)
    }

    /// Register a unit derived through multiplication, division, or powers.
    mutating func define(symbol: String, as unit: Unit) throws {
        guard units[symbol] == nil else {
            throw UnitSystemError.duplicateUnit(symbol)
        }

        register(Unit(
            symbol: symbol,
            scale: unit.scale,
            dimensions: unit.dimensions
        ))
    }

    /// Convert a numerical value between compatible units.
    func convert(
        _ value: NumValue,
        from sourceSymbol: String,
        to targetSymbol: String
    ) throws -> NumValue {
        let source = try unit(sourceSymbol)
        let target = try unit(targetSymbol)

        guard source.dimensions == target.dimensions else {
            throw UnitSystemError.incompatibleDimensions(
                from: source,
                to: target
            )
        }

        return try value.multiplying(source.scale.dividing(target.scale))
    }
}
