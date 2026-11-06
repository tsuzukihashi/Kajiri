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
        #if DEBUG
        // App Store のスクリーンショット用: メモリの中の見本データと、決まった答えを返す中継サーバ
        if StoreShots.isOn {
            let shots = try! ModelContainer(for: Log.self, Step.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            StoreShots.seed(shots.mainContext, now: AppClock.now)
            self.container = shots
            _useCase = State(initialValue: LogUseCase(context: shots.mainContext, api: StoreShotAPI(), notifications: MockNotificationScheduler()))
            _calendar = State(initialValue: CalendarUseCase(repository: EventKitCalendarRepository(), google: MockGoogleCalendarRepository(isAvailable: false, account: nil, connectsAs: nil, events: [], failure: nil), api: StoreShotAPI()))
            return
        }
        #endif
        self.container = container
        _useCase = State(initialValue: LogUseCase(context: container.mainContext, api: KajiriAPI(), notifications: NotificationScheduler()))
        _calendar = State(initialValue: CalendarUseCase(repository: EventKitCalendarRepository(), google: GoogleCalendarRepository(), api: KajiriAPI()))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(useCase)
                .environment(calendar)
                .onOpenURL { GoogleCalendarRepository.handle($0) }
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
