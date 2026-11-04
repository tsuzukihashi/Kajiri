import SwiftData
import SwiftUI

@main
struct KajiriApp: App {
    private let container: ModelContainer
    @State private var useCase: LogUseCase
    @State private var calendar: CalendarUseCase

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
        _calendar = State(initialValue: CalendarUseCase(repository: EventKitCalendarRepository(), api: KajiriAPI()))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(useCase)
                .environment(calendar)
                #if DEBUG
                .task {
                    await DemoSeeder.seedIfAsked()
                    calendar.refreshAccess()
                    calendar.reload()
                }
                #endif
        }
        .modelContainer(container)
    }
}
