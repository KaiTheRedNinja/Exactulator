//
//  OperationHolder.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 15/10/26.
//

import Foundation

struct OperationHolder {
    var registeredInfixOps: [String: any InfixOperator]
    var registeredPrefixOps: [String: any PrefixOperator]
    var registeredPostfixOps: [String: any PostfixOperator]
    var registeredFunctionOps: [String: any FunctionOperator]
    var registeredImplicitInfixOp: ImplicitInfixOperator?

    var tokenMatchInfix: [Token: String]
    var tokenMatchPrefix: [Token: String]
    var tokenMatchPostfix: [Token: String]
    var tokenMatchFunction: [Token: String]

    init(all: [any Operator]) {
        self.registeredInfixOps = [:]
        self.registeredPrefixOps = [:]
        self.registeredPostfixOps = [:]
        self.registeredFunctionOps = [:]
        self.registeredImplicitInfixOp = nil
        self.tokenMatchInfix = [:]
        self.tokenMatchPrefix = [:]
        self.tokenMatchPostfix = [:]
        self.tokenMatchFunction = [:]

        for op in all {
            if let op = op as? InfixOperator {
                if registeredInfixOps[op.name] != nil { fatalError("Duplicate operations of same type") }
                registeredInfixOps[op.name] = op
                op.matchTokens.forEach { tokenMatchInfix[$0] = op.name }
            }
            if let op = op as? PrefixOperator {
                if registeredPrefixOps[op.name] != nil { fatalError("Duplicate operations of same type") }
                registeredPrefixOps[op.name] = op
                op.matchTokens.forEach { tokenMatchPrefix[$0] = op.name }
            }
            if let op = op as? PostfixOperator {
                if registeredPostfixOps[op.name] != nil { fatalError("Duplicate operations of same type") }
                registeredPostfixOps[op.name] = op
                op.matchTokens.forEach { tokenMatchPostfix[$0] = op.name }
            }
            if let op = op as? FunctionOperator {
                if registeredFunctionOps[op.name] != nil { fatalError("Duplicate operations of same type") }
                registeredFunctionOps[op.name] = op
                op.matchTokens.forEach { tokenMatchFunction[$0] = op.name }
            }
            if let op = op as? ImplicitInfixOperator {
                if registeredImplicitInfixOp != nil { fatalError("There may only be one implicit infix operator") }
                registeredImplicitInfixOp = op
            }
        }
    }

    func match(infixToken: Token) -> any InfixOperator? {
        if let name = tokenMatchInfix[infixToken], let op = registeredInfixOps[name] {
            return op
        }
        return nil
    }

    func match(prefixToken: Token) -> any PrefixOperator? {
        if let name = tokenMatchPrefix[prefixToken], let op = registeredPrefixOps[name] {
            return op
        }
        return nil
    }

    func match(postfixToken: Token) -> any PostfixOperator? {
        if let name = tokenMatchPostfix[postfixToken], let op = registeredPostfixOps[name] {
            return op
        }
        return nil
    }

    func match(functionToken: Token) -> any FunctionOperator? {
        if let name = tokenMatchFunction[functionToken], let op = registeredFunctionOps[name] {
            return op
        }
        return nil
    }
}
