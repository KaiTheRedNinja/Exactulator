//
//  ExpressionManager.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 12/10/26.
//

import Playgrounds

#Playground {
    let operation = InfixOperation(
        op: DivisionOperator(),
        lhs: ValueOperation(
            value: .exact(.init(5, surd: 3))
        ),
        rhs: ValueOperation(
            value: .exact(.init(7, surd: 10))
        ),
    )

    print(operation.solve().description)
}
