import SwiftUI
import Playgrounds

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .padding()
            .onTapGesture {
                print(FunctionOperation(
                    op: SinOperator(),
                    elements: [
                        ValueOperation(value: .exact(.init(1, div: 3, pi: 1)))
                    ]
                )
                .solve().description)
            }
    }
}
