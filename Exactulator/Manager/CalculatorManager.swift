//
//  CalculatorManager.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 17/10/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class CalculatorManager: ObservableObject {
    @Published var pastOperations: [PastOperation] = []
    @Published var expression: [VisualNode] = []
    var currentId: UUID = .init()
    @Published var cursor = Cursor()
    @Published var solution: [VisualNode] = []
    @Published var warning: String?
    @Published var displayMode: ResultDisplayMode = .exact

    /// The expression manager
    private let expressionManager: ExpressionManager

    init(
        expressionManager: ExpressionManager
    ) {
        self.expressionManager = expressionManager
    }

    func toggleDisplayMode() {
        displayMode = displayMode == .exact ? .imprecise : .exact
        refreshSolution()
    }

    func refreshSolution() {
        do {
            solution = try expressionManager.computeOperationTree(nodes: expression).solve().toVisualNodes(displayMode: displayMode)
            warning = nil
        } catch {
            solution = []
            warning = error.localizedDescription
        }
    }
}

struct PastOperation: Identifiable {
    var id: UUID = .init()
    var expression: [VisualNode]
    var solution: [VisualNode]

    init(id: UUID = .init(), expression: [VisualNode], solution: [VisualNode]) {
        self.id = id
        self.expression = expression
        self.solution = solution
    }
}

struct IDStr: Hashable {
    var uuid: UUID
    var str: String
}
