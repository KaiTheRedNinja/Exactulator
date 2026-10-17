import SwiftUI
import Playgrounds

struct ContentView: View {
    @State var expression: String = ""
    @State var result: String = ""

    var body: some View {
        List {
            TextField("Expression", text: $expression)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Calculate") {
                do {
                    let unitsSystem = UnitSystem()
                    let manager = ExpressionManager(
                        registeredOps: .init(
                            all: [
                                AdditionOperator.shared,
                                SubtractionOperator.shared,
                                MultiplicationOperator.shared,
                                DivisionOperator.shared,
                                UnitConvertOperator.shared,
                                LogOperator.shared,
                                SinOperator.shared,
                                CosOperator.shared,
                                TanOperator.shared,
                                SquareRootOperator.shared,
                                ConstValueOperator.pi,
                            ] + unitsSystem.units.values.map {
                                UnitOperator(
                                    unit: $0,
                                    matchTokens: [.letter($0.symbol)]
                                )
                            }
                        ),
                        registeredUnits: unitsSystem
                    )

                    let tree = try manager.computeOperationTree(expression: expression)
                    print(tree.description)
                    let solution = try tree.solve()
                    print(solution)
                    result = solution.description
                } catch {
                    print("Tree error: \(error)")
                    result = "Tree error: \(error)"
                }
            }
            Text("Result: \(result)")
        }
    }
}
