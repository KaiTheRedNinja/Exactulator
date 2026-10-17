//
//  CalculatorView.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 17/10/26.
//

import SwiftUI

struct CalculatorView: View {
    @StateObject var manager: CalculatorManager

    private let columns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    var body: some View {
        VStack(spacing: 0) {
//            header

            inputAndResult
                .frame(maxHeight: .infinity)
                .background(Color(uiColor: .secondarySystemBackground))

            keypad
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .background(Color(uiColor: .systemBackground))
        }
        .background(Color(uiColor: .systemBackground))
        .preferredColorScheme(.light)
    }

//    private var header: some View {
//        HStack {
//            VStack(alignment: .leading, spacing: 3) {
//                Text("FORMULA")
//                    .font(.caption2.weight(.bold))
//                    .tracking(1.8)
//                    .foregroundStyle(.secondary)
//                Text("Calculator")
//                    .font(.title2.weight(.semibold))
//            }
//            Spacer()
//            Button {
//                manager.toggleDisplayMode()
//            } label: {
//                HStack(spacing: 6) {
//                    Image(systemName: "arrow.left.arrow.right")
//                    Text(manager.displayMode.label)
//                }
//                .font(.subheadline.weight(.semibold))
//                .padding(.horizontal, 12)
//                .padding(.vertical, 9)
//                .background(Color.indigo.opacity(0.10), in: Capsule())
//                .foregroundStyle(.indigo)
//            }
//            .buttonStyle(.plain)
//        }
//        .padding(.horizontal, 20)
//        .padding(.vertical, 15)
//    }

    private var inputAndResult: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView([.horizontal, .vertical]) {
                ExpressionRow(
                    nodes: manager.expression,
                    path: [],
                    cursor: manager.cursor,
                    onSetCursor: manager.setCursor
                )
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(20)
            }
            .scrollClipDisabled()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 210, maxHeight: .infinity, alignment: .topTrailing)

            HStack(alignment: .bottom, spacing: 6) {
                if let warning = manager.warning {
                    Text(warning)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                } else {
                    ExpressionRow(
                        nodes: [.atom("=")] + manager.solution,
                        path: [],
                        cursor: Cursor(path: [], index: -1),
                        onSetCursor: { _, _ in }
                    )

                    Spacer()

                    Button {
                        manager.toggleDisplayMode()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right")
//                            Text(manager.displayMode.label)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.indigo.opacity(0.10), in: Capsule())
                        .foregroundStyle(.indigo)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .systemBackground))
            }
            .padding(10)
        }
    }

    private var keypad: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                utilityButton("Clear", symbol: "xmark.circle", tint: .red) {
                    manager.clear()
                }
                utilityButton("Delete", symbol: "delete.left", tint: .orange) {
                    manager.deleteBackward()
                }
                utilityButton("←", symbol: nil, tint: .indigo) {
                    manager.moveLeft()
                }
                utilityButton("→", symbol: nil, tint: .indigo) {
                    manager.moveRight()
                }
            }

            LazyVGrid(columns: columns, spacing: 9) {
                key("sin") { manager.insertAtom("sin(") }
                key("cos") { manager.insertAtom("cos(") }
                key("tan") { manager.insertAtom("tan(") }
                key("ln") { manager.insertAtom("ln(") }

                key("7", style: .number) { manager.insertAtom("7") }
                key("8", style: .number) { manager.insertAtom("8") }
                key("9", style: .number) { manager.insertAtom("9") }
                key("÷", style: .operatorKey) { manager.insertAtom("÷") }

                key("4", style: .number) { manager.insertAtom("4") }
                key("5", style: .number) { manager.insertAtom("5") }
                key("6", style: .number) { manager.insertAtom("6") }
                key("×", style: .operatorKey) { manager.insertAtom("×") }

                key("1", style: .number) { manager.insertAtom("1") }
                key("2", style: .number) { manager.insertAtom("2") }
                key("3", style: .number) { manager.insertAtom("3") }
                key("−", style: .operatorKey) { manager.insertAtom("−") }

                key("0", style: .number) { manager.insertAtom("0") }
                key(".", style: .number) { manager.insertAtom(".") }
                key("(", style: .number) { manager.insertAtom("(") }
                key("+", style: .operatorKey) { manager.insertAtom("+") }

                key("a⁄b", style: .structure) { manager.insertFraction() }
                key("√x", style: .structure) { manager.insertSquareRoot() }
                key("x²", style: .structure) { manager.insertSquared() }
                key("10ˣ", style: .structure) { manager.insertTenToPower() }
            }
        }
    }

    private enum KeyStyle {
        case number, operatorKey, structure
    }

    private func key(_ title: String, style: KeyStyle = .number, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(keyBackground(style), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(keyForeground(style))
        }
        .buttonStyle(.plain)
    }

    private func keyBackground(_ style: KeyStyle) -> Color {
        switch style {
        case .number: return Color(uiColor: .secondarySystemBackground)
        case .operatorKey: return Color.indigo.opacity(0.10)
        case .structure: return Color.teal.opacity(0.12)
        }
    }

    private func keyForeground(_ style: KeyStyle) -> Color {
        switch style {
        case .number: return .primary
        case .operatorKey: return .indigo
        case .structure: return .teal
        }
    }

    private func utilityButton(
        _ title: String,
        symbol: String?,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recursive expression renderer

struct ExpressionRow: View {
    let nodes: [VisualNode]
    let path: [Cursor.Step]
    let cursor: Cursor
    let onSetCursor: ([Cursor.Step], Int) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<nodes.count, id: \.self) { gap in
                NodeView(
                    node: nodes[gap],
                    path: path,
                    nodeIndex: gap,
                    cursor: cursor,
                    onSetCursor: onSetCursor
                )
                .background {
                    if cursor.path == path && cursor.index-1 == gap {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(uiColor: .tertiarySystemBackground))
                    }
                }
                .overlay(alignment: .leading) {
                    if cursor.path == path && cursor.index == gap {
                        CursorCaret()
                            .offset(x: -2)
                    }
                }
            }
        }
        .overlay(alignment: .trailing) {
            if cursor.path == path && cursor.index == nodes.count {
                CursorCaret()
                    .offset(x: 2)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(minHeight: 36)
    }
}

struct NodeView: View {
    let node: VisualNode
    let path: [Cursor.Step]
    let nodeIndex: Int
    let cursor: Cursor
    let onSetCursor: ([Cursor.Step], Int) -> Void

    var body: some View {
        switch node {
        case .atom(let value):
            Text(value)
                .font(.system(size: 24, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.vertical, 1)
                .contentShape(Rectangle())
                .overlay { // left tap = focus here, right tap = focus next
                    HStack(spacing: 0) {
                        Color.white.opacity(0.001)
                            .onTapGesture {
                                onSetCursor(path, nodeIndex)
                            }
                        Color.white.opacity(0.001)
                            .onTapGesture {
                                onSetCursor(path, nodeIndex+1)
                            }
                    }
                }

        case .structure(let structure):
            StructureView(
                structure: structure,
                path: path,
                nodeIndex: nodeIndex,
                cursor: cursor,
                onSetCursor: onSetCursor
            )
        }
    }
}

struct StructureView: View {
    let structure: Structure
    let path: [Cursor.Step]
    let nodeIndex: Int
    let cursor: Cursor
    let onSetCursor: ([Cursor.Step], Int) -> Void

    var body: some View {
        Group {
            switch structure.associatedOperator.name {
            case FractionOperator.shared.name:
                VStack(spacing: 4) {
                    slot(0)
                    Rectangle()
                        .fill(Color.primary.opacity(0.75))
                        .frame(height: 1.5)
                        .frame(minWidth: 34)
                    slot(1)
                }
                .padding(.horizontal, 3)
            case SquareRootOperator.shared.name:
                slot(0)
                    .padding(.leading, 1)
                    .padding(.trailing, 4)
                    .padding(.top, 2)
                    .padding(.leading, 16) // for the sqrt shape
                    .overlay {
                        SquareRootShape(mainTickWidth: 16)
                            .stroke(
                                Color.primary,
                                style: StrokeStyle(
                                    lineWidth: 1.8,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                    }
            case PowerOperator.shared.name:
                HStack(alignment: .top, spacing: 1) {
                    slot(0)
                    slot(1)
                        .scaleEffect(0.72, anchor: .bottomLeading)
                        .offset(y: -7)
                }
//            case .custom(let symbol):
//                HStack(spacing: 3) {
//                    Text(symbol)
//                    ForEach(structure.slots.indices, id: \.self) { index in
//                        slot(index)
//                    }
//                }
            default:
                Text("???")
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func slot(_ index: Int) -> some View {
        let slotPath = path + [Cursor.Step(nodeIndex: nodeIndex, slotIndex: index)]
        if structure.slots.indices.contains(index) {
            let content = structure.slots[index]
            if content.isEmpty {
                Button {
                    onSetCursor(slotPath, 0)
                } label: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.indigo.opacity(0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.indigo.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        }
                        .frame(width: 30, height: 27)
                        .overlay {
                            if cursor.path == slotPath {
                                CursorCaret()
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.indigo.opacity(0.7))
                            }
                        }
                }
                .buttonStyle(.plain)
            } else {
                ExpressionRow(
                    nodes: content,
                    path: slotPath,
                    cursor: cursor,
                    onSetCursor: onSetCursor
                )
            }
        }
    }
}

struct CursorCaret: View {
    var body: some View {
        Capsule()
            .fill(Color.indigo)
            .frame(width: 2, height: 29)
            .padding(.horizontal, 1)
    }
}

struct SquareRootShape: Shape {
    let mainTickWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = mainTickWidth
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height * 0.56)) // start of tick
        path.addLine(to: CGPoint(x: width * 0.32, y: height * 0.56)) // end of tick; start of down slope
        path.addLine(to: CGPoint(x: width * 0.61, y: height * 0.94)) // end of down slope; start of up slope
        path.addLine(to: CGPoint(x: width, y: 0)) // end of up slop; start of line
        path.addLine(to: CGPoint(x: rect.width, y: 0)) // end of line

        return path
    }
}
