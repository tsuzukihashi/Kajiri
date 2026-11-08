import SwiftUI

/// 設定の Debug（Xcode と TestFlight の版だけ）。これまでのデータを全部消す
struct DebugDataSection: View {
    enum Phase: Equatable {
        case idle
        case deleting
        case done
        case failed(String)
    }

    let logCount: Int
    let stepCount: Int
    let phase: Phase
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionBox(title: "Debug", detail: String(localized: "TestFlight と開発中の版だけ")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("いま残っているデータ: 丸太\(logCount)本・薪\(stepCount)本")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                    Button(action: onDelete) {
                        HStack(spacing: 8) {
                            switch phase {
                            case .deleting:
                                ProgressView().tint(.white)
                                Text("消しています")
                            case .done:
                                Image(systemName: "checkmark.circle.fill")
                                Text("すべて消しました")
                            case .idle, .failed:
                                Image(systemName: "trash")
                                Text("これまでのデータをすべて消す")
                            }
                        }
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(phase == .done ? Theme.sub : Color.red, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(phase == .deleting || phase == .done || (logCount == 0 && stepCount == 0))
                    .opacity(logCount == 0 && stepCount == 0 && phase == .idle ? 0.45 : 1)
                    if logCount == 0 && stepCount == 0 && phase == .idle {
                        Text("消すデータはありません。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sub)
                    }
                    if case let .failed(message) = phase {
                        Label("消せませんでした。\(message)", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .padding(16)
            }
        }
    }
}

#Preview("消す前") {
    DebugDataSection(logCount: 4, stepCount: 18, phase: .idle, onDelete: {})
        .padding()
        .background(Theme.ground)
}

#Preview("消している") {
    DebugDataSection(logCount: 4, stepCount: 18, phase: .deleting, onDelete: {})
        .padding()
        .background(Theme.ground)
}

#Preview("消せなかった") {
    DebugDataSection(logCount: 4, stepCount: 18, phase: .failed("保存できませんでした。"), onDelete: {})
        .padding()
        .background(Theme.ground)
}

#Preview("データなし") {
    DebugDataSection(logCount: 0, stepCount: 0, phase: .idle, onDelete: {})
        .padding()
        .background(Theme.ground)
}
