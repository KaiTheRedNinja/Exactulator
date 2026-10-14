import SwiftUI
import Playgrounds

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .padding()
            .onTapGesture {
                do {
                    let manager = ExpressionManager()
                    manager.expression = "1+2+3+4"
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
                    // manager.expression =

                    let tree = try manager.computeOperationTree()
                    print(tree.description)
                    print(try tree.solve())
                } catch {
                    print("Tree error: \(error)")
                }
            }
    }
}
