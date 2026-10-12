//
//  ExpressionManager.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Playgrounds

#Playground {
    let operation = FunctionOperation(
        op: SinOperator.shared,
        elements: [
            ValueOperation(value: .exact(.init(9)))
        ]
    )

    print(operation.solve().description)
}
