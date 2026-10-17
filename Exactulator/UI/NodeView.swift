//
//  NodeView.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 17/10/26.
//

import SwiftUI

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

