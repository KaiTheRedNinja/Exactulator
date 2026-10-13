//
//  ExpressionManager.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Playgrounds

class ExpressionManager {
    var expression: String = ""
    var registeredOps: [any Operator] = []

    func computeOperationTree() {
        // convert the expression into tokens
        let tokens: [Token] = .build(from: expression)
    }
}

#Playground {
    let exp = "1+5(4*6.45)*pi"
    let tokens = [Token].build(from: exp)
}
