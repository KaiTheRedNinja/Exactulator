import SwiftUI
import Playgrounds

struct ContentView: View {
    @ObservedObject var calculatorManager: CalculatorManager = {
        let unitsSystem = UnitSystem()
        return .init(
            expressionManager: .init(
                registeredOps: .init(
                    all: [
                    AdditionOperator.shared,
                    SubtractionOperator.shared,
                    MultiplicationOperator.shared,
                    DivisionOperator.shared,
                    FractionOperator.shared,
                    UnitConvertOperator.shared,
                    LogOperator.shared,
                    SinOperator.shared,
                    CosOperator.shared,
                    TanOperator.shared,
                    SquareRootOperator.shared,
                    PowerOperator.shared,
                    ConstValueOperator.pi,
                    ConstValueOperator.euler
                ] + unitsSystem.units.values.map {
                    UnitOperator(
                        unit: $0,
                        matchTokens: [.letter($0.symbol)]
                    )
                }),
                registeredUnits: unitsSystem
            )
        )
    }()

    var body: some View {
        CalculatorView(manager: calculatorManager)
    }
}
