import SwiftUI

/// 予定を押したら EventSheet を出し、そこで「準備をかじってもらう」を押したら、閉じてから丸太を投げるシートへ渡す。
/// シートを閉じきる前に次のシートを出すと出ないことがあるので、閉じたあと（onDismiss）に渡す。
struct EventSheetsModifier: ViewModifier {
    @Binding var selected: CalendarEvent?
    @Binding var throwRequest: ThrowRequest?

    @Environment(CalendarUseCase.self) private var calendar
    @State private var pending: ThrowRequest?

    func body(content: Content) -> some View {
        content
            .sheet(item: $selected, onDismiss: {
                if let pending {
                    throwRequest = pending
                    self.pending = nil
                }
            }) { event in
                EventSheet(event: event) {
                    pending = ThrowRequest(memo: calendar.throwMemo(for: event), sourceEventID: event.id)
                    selected = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func eventSheets(selected: Binding<CalendarEvent?>, throwRequest: Binding<ThrowRequest?>) -> some View {
        modifier(EventSheetsModifier(selected: selected, throwRequest: throwRequest))
    }
}
