//
//  VisualNode.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 17/10/26.
//

enum VisualNode {
    case atom(String)
    case structure(Structure)
}

struct Structure {
    var associatedOperator: FunctionOperator
    var slots: [[VisualNode]]
}

struct Cursor {
    struct Step: Hashable { var nodeIndex: Int; var slotIndex: Int }
    var path: [Step] = []      // how to descend from the root row
    var index: Int = 0         // gap position (0...count) in the innermost row
}

enum ResultDisplayMode {
    // Exact, which includes fractions, surds, and pi
    case exact
    // Imprecise, which displays up to 10 significant figures
    case imprecise
}

extension [VisualNode] {
    static func from(string: String) -> [VisualNode] {
        var nodes: [VisualNode] = []
        for character in string {
            nodes.append(.atom(String(character)))
        }
        return nodes
    }
}

extension Quantity {
    func toVisualNodes(displayMode: ResultDisplayMode) -> [VisualNode] {
        // get the value
        var nodes: [VisualNode] = []
        if case let .exact(exactValue) = self.value, displayMode == .exact {
            // main value
            if exactValue.denominator == 0 {
                // no denominator, just add the numerator
                let stringValue = String(exactValue.numerator)
                nodes.append(contentsOf: [VisualNode].from(string: stringValue))
            } else {
                // create a fraction
                nodes.append(.structure(.init(
                    associatedOperator: FractionOperator.shared,
                    slots: [
                        [VisualNode].from(string: String(exactValue.numerator)),
                        [VisualNode].from(string: String(exactValue.denominator))
                    ]
                )))
            }

            // pi
            if exactValue.piPower == 1 {
                // add pi
                nodes.append(.atom("π"))
            } else if exactValue.piPower > 1 {
                // add pi and a power
                nodes.append(.structure(.init(
                    associatedOperator: PowerOperator.shared,
                    slots: [
                        [.atom("π")],
                        [VisualNode].from(string: String(exactValue.piPower))
                    ]
                )))
            }

            // sqrt
            if exactValue.surdBase > 1 {
                // add square root
                nodes.append(.structure(.init(
                    associatedOperator: SquareRootOperator.shared,
                    slots: [
                        [VisualNode].from(string: String(exactValue.surdBase))
                    ]
                )))
            }
        } else {
            let stringValue = String(value.asImprecise.value)
            nodes.append(contentsOf: [VisualNode].from(string: stringValue))
        }

        // get the unit
        guard unit != .one else { return nodes }
        nodes.append(.atom(" "))
        nodes.append(contentsOf: [VisualNode].from(string: unit.symbol))
        return nodes
    }
}
