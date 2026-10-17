//
//  CalculatorManager+Cursor.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 17/10/26.
//

import SwiftUI

extension CalculatorManager {
    func insert(_ nodes: [VisualNode]) {
        guard var row = row(at: cursor.path) else { return }
        let insertionIndex = min(max(cursor.index, 0), row.count)
        row.insert(contentsOf: nodes, at: insertionIndex)
        setRow(row, at: cursor.path)
        cursor.index = insertionIndex + nodes.count
        refreshSolution()
    }

    func insertAtom(_ value: String) {
        insert([.atom(value)])
    }

    func insertFraction() {
        insert([.structure(Structure(
            associatedOperator: FractionOperator.shared,
            slots: [[], []]
        ))])
        enterSlot(ofInsertedNodeAt: cursor.index - 1, slot: 0)
    }

    func insertSquareRoot() {
        insert([.structure(Structure(
            associatedOperator: SquareRootOperator.shared,
            slots: [[]]
        ))])
        enterSlot(ofInsertedNodeAt: cursor.index - 1, slot: 0)
    }

    func insertPower(exponent: [VisualNode] = []) {
        insert([.structure(Structure(
            associatedOperator: PowerOperator.shared,
            slots: [[], exponent]
        ))])
        enterSlot(ofInsertedNodeAt: cursor.index - 1, slot: 0)
    }

    func insertTenToPower() {
        insert([.structure(Structure(
            associatedOperator: PowerOperator.shared,
            slots: [[.atom("10")], []]
        ))])
        enterSlot(ofInsertedNodeAt: cursor.index - 1, slot: 1)
    }

    func insertSquared() {
        insertPower(exponent: [.atom("2")])
    }

    func insertInverse() {
        insertPower(exponent: [.atom("-1")])
    }

    func deleteBackward() {
        guard var row = row(at: cursor.path) else { return }
        guard cursor.index > 0, cursor.index <= row.count else { return }
        row.remove(at: cursor.index - 1)
        setRow(row, at: cursor.path)
        cursor.index -= 1
        refreshSolution()
    }

    func clear() {
        expression = []
        solution = []
        warning = nil
        currentId = .init()
        cursor = Cursor()
    }

    func saveCurrent() {
        guard !solution.isEmpty else { return }
        pastOperations.append(.init(id: currentId, expression: expression, solution: solution))
        clear()
    }

    // MARK: Cursor and recursive row editing

    func moveLeft() {
        guard let currentRow = row(at: cursor.path) else { return }

        if cursor.index > 0 {
            let previousIndex = cursor.index - 1

            if case .structure(let structure) = currentRow[previousIndex],
               let lastSlot = structure.slots.indices.last {
                cursor.path.append(
                    Cursor.Step(nodeIndex: previousIndex, slotIndex: lastSlot)
                )
                cursor.index = structure.slots[lastSlot].count
            } else {
                cursor.index -= 1
            }
        } else if let previous = previousRowLocation() {
            cursor.path = previous.path
            cursor.index = previous.index
        } else {
            cursor.path = []
            cursor.index = expression.count
        }
    }

    func moveRight() {
        guard let currentRow = row(at: cursor.path) else { return }

        if cursor.index < currentRow.count {
            let nextIndex = cursor.index

            if case .structure(let structure) = currentRow[nextIndex],
               !structure.slots.isEmpty {
                cursor.path.append(
                    Cursor.Step(nodeIndex: nextIndex, slotIndex: 0)
                )
                cursor.index = 0
            } else {
                cursor.index += 1
            }
        } else if let next = nextRowLocation() {
            cursor.path = next.path
            cursor.index = next.index
        } else {
            cursor.path = []
            cursor.index = 0
        }
    }

    func setCursor(path: [Cursor.Step], index: Int) {
        cursor.path = path
        cursor.index = min(max(index, 0), row(at: path)?.count ?? 0)
    }

    func setActive(pastOpId: UUID, path: [Cursor.Step], index: Int) {
        // save the current expression
        guard let pastOpIndex = pastOperations.firstIndex(where: { $0.id == pastOpId }) else { return }
        let pastOp = pastOperations.remove(at: pastOpIndex)
        saveCurrent()

        // load the past expression
        self.expression = pastOp.expression
        setCursor(path: path, index: index)
        refreshSolution()
    }

    func setActive(expression: [VisualNode]) {
        saveCurrent()
        self.expression = expression
        setCursor(path: [], index: expression.count) // at the end
        refreshSolution()
    }

    private func enterSlot(ofInsertedNodeAt nodeIndex: Int, slot: Int) {
        cursor.path.append(Cursor.Step(nodeIndex: nodeIndex, slotIndex: slot))
        cursor.index = 0
    }

    private func row(at path: [Cursor.Step]) -> [VisualNode]? {
        var current = expression
        for step in path {
            guard current.indices.contains(step.nodeIndex),
                  case .structure(let structure) = current[step.nodeIndex],
                  structure.slots.indices.contains(step.slotIndex) else { return nil }
            current = structure.slots[step.slotIndex]
        }
        return current
    }

    private func setRow(_ newRow: [VisualNode], at path: [Cursor.Step]) {
        guard !path.isEmpty else {
            expression = newRow
            return
        }

        func replacing(_ row: [VisualNode], depth: Int) -> [VisualNode] {
            let step = path[depth]
            guard row.indices.contains(step.nodeIndex),
                  case .structure(var structure) = row[step.nodeIndex],
                  structure.slots.indices.contains(step.slotIndex) else { return row }

            var copy = row
            if depth == path.count - 1 {
                structure.slots[step.slotIndex] = newRow
            } else {
                structure.slots[step.slotIndex] =
                replacing(structure.slots[step.slotIndex], depth: depth + 1)
            }
            copy[step.nodeIndex] = .structure(structure)
            return copy
        }

        expression = replacing(expression, depth: 0)
    }

    private func previousRowLocation() -> (path: [Cursor.Step], index: Int)? {
        guard let last = cursor.path.last else { return nil }
        let parentPath = Array(cursor.path.dropLast())
        guard let parentRow = row(at: parentPath),
              parentRow.indices.contains(last.nodeIndex),
              case .structure(let structure) = parentRow[last.nodeIndex] else { return nil }

        if last.slotIndex > 0 {
            let priorSlot = last.slotIndex - 1
            var path = parentPath
            path.append(.init(nodeIndex: last.nodeIndex, slotIndex: priorSlot))
            return (path, structure.slots[priorSlot].count)
        }
        return (parentPath, last.nodeIndex)
    }

    private func nextRowLocation() -> (path: [Cursor.Step], index: Int)? {
        guard let last = cursor.path.last else { return nil }
        let parentPath = Array(cursor.path.dropLast())
        guard let parentRow = row(at: parentPath),
              parentRow.indices.contains(last.nodeIndex),
              case .structure(let structure) = parentRow[last.nodeIndex] else { return nil }

        if last.slotIndex + 1 < structure.slots.count {
            var path = parentPath
            path.append(.init(nodeIndex: last.nodeIndex, slotIndex: last.slotIndex + 1))
            return (path, 0)
        }
        return (parentPath, last.nodeIndex + 1)
    }
}
