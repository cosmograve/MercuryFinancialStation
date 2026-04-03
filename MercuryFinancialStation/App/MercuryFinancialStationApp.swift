import SwiftUI
import SwiftData

@main
struct MercuryFinancialStationApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            StationState.self,
            TransactionRecord.self,
            ShiftDaySummary.self
        ])
        let configuration = ModelConfiguration("MercuryFinancialStation")
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
