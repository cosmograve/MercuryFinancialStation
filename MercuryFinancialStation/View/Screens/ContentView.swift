import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        RootTabBarView()
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: StationState.self, TransactionRecord.self, ShiftDaySummary.self,
        configurations: configuration
    )
    container.mainContext.insert(StationState())

    return ContentView()
        .modelContainer(container)
}
