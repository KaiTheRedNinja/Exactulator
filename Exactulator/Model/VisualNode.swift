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
    var value: String
    var slots: [[VisualNode]]
}
