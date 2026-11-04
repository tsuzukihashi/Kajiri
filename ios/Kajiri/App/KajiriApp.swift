import SwiftData
import SwiftUI

@main
struct KajiriApp: App {
    private let container: ModelContainer
    @State private var useCase: LogUseCase

    init() {
        FirebaseSetup.configure()
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Log.self, Step.self)
        } catch {
            // 保存先が開けないときは、落とさずにメモリの中だけで動かす
            container = try! ModelContainer(for: Log.self, Step.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        self.container = container
        _useCase = State(initialValue: LogUseCase(context: container.mainContext, api: KajiriAPI()))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(useCase)
        }
        .modelContainer(container)
    }
}
