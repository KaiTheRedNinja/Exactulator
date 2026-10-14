import SwiftUI
import Playgrounds

struct ContentView: View {
    @State var expression: String = ""
    @State var result: String = ""

    var body: some View {
        List {
            TextField("Expression", text: $expression)
                .keyboardType(.asciiCapable)
            Button("Calculate") {
                do {
                    let manager = ExpressionManager()
                    manager.registeredOps = [
                        AdditionOperator.shared,
                        SubtractionOperator.shared,
                        MultiplicationOperator.shared,
                        DivisionOperator.shared,
                        SubexpressionOperator.shared,
                        LogOperator.shared,
                        SinOperator.shared,
                        CosOperator.shared,
                        TanOperator.shared
                    ]

                    manager.expression = expression
                    let tree = try manager.computeOperationTree()
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
