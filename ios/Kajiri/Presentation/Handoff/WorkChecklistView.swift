import SwiftUI

/// カジリが作ったチェックリスト。項目を押すとチェックが付き、「メモ」の欄には書きこめる。
/// 見出し（【】）ごとに白い箱に分ける
struct WorkChecklistView: View {
    let document: WorkDocument
    let progress: WorkProgress
    let onToggle: (String) -> Void
    let onNote: (String, String) -> Void
    var focusedNote: FocusState<String?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 10) {
                    if let title = section.title {
                        Text(title)
                            .font(.system(size: 18, weight: .black))
                            .padding(.horizontal, 4)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                            row(block)
                        }
                    }
                    .padding(.vertical, 6)
                    .background(.white, in: .rect(cornerRadius: 20))
                }
            }
        }
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder
    private func row(_ block: WorkDocument.Block) -> some View {
        switch block {
        case .heading:
            EmptyView()
        case let .text(text):
            Text(text)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.sub)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 2)
        case let .check(id, text, initially):
            let isChecked = progress.isChecked(id, initially: initially)
            Button { onToggle(id) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isChecked ? Theme.sub : Theme.ink)
                        .frame(width: 26)
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                    Text(text)
                        .font(.system(size: 15, weight: isChecked ? .regular : .bold))
                        .foregroundStyle(isChecked ? Theme.sub : Theme.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isChecked)
            .accessibilityAddTraits(isChecked ? .isSelected : [])
            .accessibilityHint(Text(isChecked ? "押すと、チェックを外す" : "押すと、チェックを付ける"))
        case let .note(id, label, initial):
            NoteField(
                label: label,
                text: progress.notes[id] ?? initial,
                focus: focusedNote,
                id: id,
                onChange: { onNote(id, $0) }
            )
        }
    }

    private struct Section {
        let title: String?
        var blocks: [WorkDocument.Block]
    }

    /// 見出しごとに分ける。見出しより前の行は、見出しなしの箱にまとめる
    private var sections: [Section] {
        var result: [Section] = []
        for block in document.blocks {
            if case let .heading(title) = block {
                result.append(Section(title: title, blocks: []))
            } else if result.isEmpty {
                result.append(Section(title: nil, blocks: [block]))
            } else {
                result[result.count - 1].blocks.append(block)
            }
        }
        return result.filter { !$0.blocks.isEmpty }
    }
}

/// 「メモ」の欄。書いたそばから保存する
private struct NoteField: View {
    let label: String
    let text: String
    let focus: FocusState<String?>.Binding
    let id: String
    let onChange: (String) -> Void

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.sub)
            TextField(String(localized: "聞いたこと・気づいたことを書く"), text: $draft, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...6)
                .submitLabel(.done)
                .focused(focus, equals: id)
                .onSubmit { focus.wrappedValue = nil }
                .padding(12)
                .background(Theme.ground, in: .rect(cornerRadius: 12))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .onAppear { draft = text }
        .onChange(of: draft) { _, value in
            if value != text { onChange(value) }
        }
    }
}

/// チェックリストの進み具合（「12項目のうち3つ」）
struct WorkChecklistProgress: View {
    let checked: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(checked)").font(.system(size: 22, weight: .black))
                Text("/ \(total)項目 確かめた").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.sub)
            }
            ProgressPips(total: total, done: checked)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 20))
    }
}

#if DEBUG
private struct ChecklistPreview: View {
    @State private var progress = WorkProgress.empty
    @FocusState private var focused: String?
    let body0 = """
    【使い方】
    ・見たら □ を ■ に変える
    【1 物干し竿】
    見る場所
    □ 物干し金物をつける位置（室内・ベランダ）
    □ 竿の長さが入る幅があるか
    聞くこと
    □ 金物はいつ、誰がつけるか
    メモ：
    【2 住所変更】
    □ 表札・ポストをつける位置
    """

    var body: some View {
        let document = WorkDocument.parse(body0)
        ScrollView {
            VStack(spacing: 16) {
                WorkChecklistProgress(checked: progress.checkedCount(in: document), total: document.checkIDs.count)
                WorkChecklistView(
                    document: document,
                    progress: progress,
                    onToggle: { progress.toggle($0) },
                    onNote: { progress.notes[$0] = $1 },
                    focusedNote: $focused
                )
            }
            .padding(18)
        }
        .background(Theme.ground)
    }
}

#Preview("チェックリスト") {
    ChecklistPreview()
}
#endif
