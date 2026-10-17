//
//  CalculatorView.swift
//  Exactulator
//
//  Created by Kai Quan Tay on 17/10/26.
//

import SwiftUI

struct CalculatorView: View {
    @StateObject var manager: CalculatorManager
    @State var showKeypad: Bool = true

    @Namespace var namespace

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                inputAndResult
                    .frame(maxHeight: .infinity)
                    .background(Color(uiColor: .secondarySystemBackground))

                if showKeypad {
                    keypad
                        .padding(.horizontal, 12)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .background(Color(uiColor: .systemBackground))
                }
            }
            .background(Color(uiColor: .systemBackground))
            .preferredColorScheme(.light)
            .toolbar {
                Button {
                    withAnimation {
                        showKeypad.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showKeypad ? "grid" : "grid.circle.fill")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.cyan.opacity(0.10), in: Capsule())
                    .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: manager.expression) { _, _ in
            withAnimation {
                showKeypad = true
            }
        }
    }

    private var inputAndResult: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    Spacer()

                    ForEach(manager.pastOperations) { pastOperation in
                        VStack(alignment: .leading, spacing: 5) {
                            // expression
                            ScrollView(.horizontal) {
                                ExpressionRow(
                                    nodes: pastOperation.expression,
                                    path: [],
                                    cursor: Cursor(path: [], index: -1),
                                    onSetCursor: { manager.setActive(pastOpId: pastOperation.id, path: $0, index: $1) }
                                )
                                .matchedGeometryEffect(id: IDStr(uuid: pastOperation.id, str: "expression"), in: namespace)
                                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                            }
                            .defaultScrollAnchor(.trailing)
                            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(uiColor: .systemBackground))
                                    .opacity(0.5)
                            }
                            .clipShape(Rectangle())
                            .padding(10)

                            // solution
                            ScrollView(.horizontal) {
                                ExpressionRow(
                                    nodes: [.atom("=")] + pastOperation.solution,
                                    path: [],
                                    cursor: Cursor(path: [], index: -1),
                                    onSetCursor: { _, _ in manager.setActive(expression: pastOperation.solution) }
                                )
                                .matchedGeometryEffect(id: IDStr(uuid: pastOperation.id, str: "solution"), in: namespace)
                                .padding(20)
                            }
                            .frame(minWidth: 0)
                            .scrollClipDisabled()
                        }
                    }

                    if !manager.pastOperations.isEmpty {
                        Divider()

                        Spacer()
                            .frame(height: 30)
                    }
                }
            }
            .defaultScrollAnchor(.bottom)
            .scrollClipDisabled()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 210, maxHeight: .infinity, alignment: .topTrailing)

            ScrollView(.horizontal) {
                ExpressionRow(
                    nodes: manager.expression,
                    path: [],
                    cursor: manager.cursor,
                    onSetCursor: manager.setCursor
                )
                .matchedGeometryEffect(id: IDStr(uuid: manager.currentId, str: "expression"), in: namespace)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.trailing)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .systemBackground))
            }
            .clipShape(Rectangle())
            .padding(10)

            HStack(alignment: .bottom, spacing: 6) {
                if let warning = manager.warning {
                    Text(warning)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                } else {
                    ScrollView(.horizontal) {
                        ExpressionRow(
                            nodes: [.atom("=")] + manager.solution,
                            path: [],
                            cursor: Cursor(path: [], index: -1),
                            onSetCursor: { _, _ in manager.setActive(expression: manager.solution) }
                        )
                        .matchedGeometryEffect(id: IDStr(uuid: manager.currentId, str: "solution"), in: namespace)
                    }
                    .scrollClipDisabled()
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .topTrailing)

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

                    Button {
                        withAnimation {
                            manager.saveCurrent()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrowshape.up")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.green.opacity(0.10), in: Capsule())
                        .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private var keypad: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                utilityButton("AC", symbol: "xmark.circle", tint: .red) {
                    manager.clear()
                }
                utilityButton(nil, symbol: "chevron.left", tint: .indigo) {
                    manager.moveLeft()
                }
                utilityButton(nil, symbol: "chevron.right", tint: .indigo) {
                    manager.moveRight()
                }

                utilityButton("DEL", symbol: "delete.left", tint: .orange) {
                    manager.deleteBackward()
                }
            }

            VStack(spacing: 9) {
                HStack(spacing: 9) {
                    key("π", style: .function) { manager.insertAtom("π") }
                    key("sin", style: .function) { manager.insertAtom("sin(") }
                    key("cos", style: .function) { manager.insertAtom("cos(") }
                    key("tan", style: .function) { manager.insertAtom("tan(") }
                    key("ln", style: .function) { manager.insertAtom("ln(") }
                    key("ℇ", style: .function) { manager.insertAtom("ℇ") }
                }

                HStack(spacing: 9) {
                    key("a/b", style: .function) { manager.insertFraction() }
                    key("√x", style: .function) { manager.insertSquareRoot() }
                    key("(", style: .function) { manager.insertAtom("(") }
                    key(")", style: .function) { manager.insertAtom(")") }
                    key("x²", style: .function) { manager.insertSquared() }
                    key("x⁻¹", style: .function) { manager.insertInverse() }
                }

                HStack(spacing: 9) {
                    key("m", style: .operatorKey, secondaryActions: [
                        ("m", { manager.insertAtom("m") }),
                        ("km", { manager.insertAtom("km") }),
                        ("cm", { manager.insertAtom("cm") }),
                        ("mm", { manager.insertAtom("mm") }),
                        ("mi", { manager.insertAtom("mi") }),
                        ("ft", { manager.insertAtom("ft") }),
                        ("in", { manager.insertAtom("in") })
                    ]) { manager.insertAtom("m") }
                    key("7", style: .number) { manager.insertAtom("7") }
                    key("8", style: .number) { manager.insertAtom("8") }
                    key("9", style: .number) { manager.insertAtom("9") }
                    key("÷", style: .operatorKey) { manager.insertAtom("÷") }
                }

                HStack(spacing: 9) {
                    key("kg", style: .operatorKey, secondaryActions: [
                        ("kg", { manager.insertAtom("kg") }),
                        ("g", { manager.insertAtom("g") }),
                        ("lb", { manager.insertAtom("lb") })
                    ]) { manager.insertAtom("kg") }
                    key("4", style: .number) { manager.insertAtom("4") }
                    key("5", style: .number) { manager.insertAtom("5") }
                    key("6", style: .number) { manager.insertAtom("6") }
                    key("×", style: .operatorKey) { manager.insertAtom("×") }
                }

                HStack(spacing: 9) {
                    key("s", style: .operatorKey, secondaryActions: [
                        ("s", { manager.insertAtom("s") }),
                        ("h", { manager.insertAtom("h") }),
                        ("min", { manager.insertAtom("min") }),
                        ("ms", { manager.insertAtom("ms") })
                    ]) { manager.insertAtom("s") }
                    key("1", style: .number) { manager.insertAtom("1") }
                    key("2", style: .number) { manager.insertAtom("2") }
                    key("3", style: .number) { manager.insertAtom("3") }
                    key("−", style: .operatorKey) { manager.insertAtom("−") }
                }

                HStack(spacing: 9) {
                    key("as", style: .operatorKey) { manager.insertAtom("→") }
                    key("0", style: .number) { manager.insertAtom("0") }
                    key(".", style: .number) { manager.insertAtom(".") }
                    key("10ˣ", style: .number) { manager.insertTenToPower() }
                    key("+", style: .operatorKey) { manager.insertAtom("+") }
                }
            }
        }
    }

    private enum KeyStyle {
        case number, function, operatorKey, structure

        var background: Color {
            switch self {
            case .number: return Color(uiColor: .systemFill)
            case .function: return Color(uiColor: .secondarySystemBackground)
            case .operatorKey: return Color.indigo.opacity(0.10)
            case .structure: return Color.teal.opacity(0.12)
            }
        }

        var foreground: Color {
            switch self {
            case .number: return .primary
            case .function: return .primary
            case .operatorKey: return .indigo
            case .structure: return .teal
            }
        }

        var height: CGFloat {
            switch self {
            case .number: 48
            case .function: 36
            case .operatorKey: 48
            case .structure: 48
            }
        }
    }

    private func key(_ title: String, style: KeyStyle = .number, action: @escaping () -> Void) -> some View {
        Button(action: {}) {
            Text(title)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: style.height)
                .background(style.background, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(style.foreground)
        }
        .buttonStyle(OnPressedButtonStyle(onPressed: action))
    }

    private func key(
        _ title: String,
        style: KeyStyle = .number,
        secondaryActions: [(label: String, action: () -> Void)],
        primaryAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 2) {
            Button(action: {}) {
                Text(title)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: style.height)
                    .background(style.background, in: UnevenRoundedRectangle(cornerRadii: .init(topLeading: 12, bottomLeading: 12)))
                    .foregroundStyle(style.foreground)
            }
            .buttonStyle(OnPressedButtonStyle(onPressed: primaryAction))

            Menu {
                ForEach(secondaryActions.enumerated(), id: \.offset) { (_, secondaryAction) in
                    Button(secondaryAction.label, action: secondaryAction.action)
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: style.height)
                    .background(style.background, in: UnevenRoundedRectangle(cornerRadii: .init(bottomTrailing: 12, topTrailing: 12)))
                    .foregroundStyle(style.foreground)
            }
        }
    }

    private func utilityButton(
        _ title: String?,
        symbol: String?,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {}) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                }
                if let title {
                    Text(title)
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(tint)
        }
        .buttonStyle(OnPressedButtonStyle(onPressed: action))
    }
}

struct OnPressedButtonStyle: ButtonStyle {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    // Wrapper for isPressed where we can run custom logic via didSet (or willSet)
    @State private var isPressedWrapper: Bool = false {
        didSet {
            // new value is pressed, old value is not pressed -> switching to pressed state
            if (isPressedWrapper && !oldValue) {
                onPressed?()
            }
            // new value is not pressed, old value is pressed -> switching to unpressed state
            else if (oldValue && !isPressedWrapper) {
                onReleased?()
            }
        }
    }

    // return the label unaltered, but add a hook to watch changes in configuration.isPressed
    func makeBody(configuration: Self.Configuration) -> some View {
        return configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in isPressedWrapper = newValue }
    }
}
