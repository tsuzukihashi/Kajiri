import SwiftUI

/// カジリが作った一覧・チェックリスト・調べもの。
///
/// ADHD の人は長い文から要点を拾うのが苦手で、作業の記憶も4つくらいで埋まる（docs/research-readable-output.md）。
/// だから、読むのは各行の頭だけで済むように組む:
/// - 項目は太字1行。説明は下に小さく1行だけ出し、残りは「くわしく」にたたむ
/// - まだチェックしていない最初の項目に「次はこれ」を付ける
/// - チェックリストは、今やっている段だけを開き、済んだ段と先の段は見出しと数だけにする
/// - 行ごとの「要確認」は外して、いちばん下に1行だけ注意を出す
struct WorkChecklistView: View {
    let document: WorkDocument
    let progress: WorkProgress
    let onToggle: (String) -> Void
    let onNote: (String, String) -> Void
    var focusedNote: FocusState<String?>.Binding

    /// 押して開け閉めした段（押していない段は、今の段だけ開く）
    @State private var sectionOverrides: [Int: Bool] = [:]
    /// 説明を全部ひらいた項目
    @State private var expanded: Set<String> = []

    var body: some View {
        let sections = WorkSection.split(document)
        let next = progress.nextCheckID(in: document)
        let current = sections.firstIndex { $0.remaining(progress) > 0 }
        VStack(alignment: .leading, spacing: 16) {
            ForEach(sections.indices, id: \.self) { index in
                sectionView(sections[index], index: index, isOpen: isOpen(index, sections: sections, current: current), next: next)
            }
            ForEach(document.footnotes, id: \.self) { text in
                Label(text, systemImage: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                    .lineSpacing(3)
                    .padding(.horizontal, 6)
            }
        }
        .foregroundStyle(Theme.ink)
        .animation(.easeInOut(duration: 0.25), value: progress)
    }

    // MARK: - 段

    private func isOpen(_ index: Int, sections: [WorkSection], current: Int?) -> Bool {
        if let override = sectionOverrides[index] { return override }
        let section = sections[index]
        // 見出しの無い段と、チェックの無い一覧（調べもの・手続きの並び）は、いつも開いておく
        guard section.title != nil, document.hasChecklist, section.total > 0 else { return true }
        return index == current
    }

    @ViewBuilder
    private func sectionView(_ section: WorkSection, index: Int, isOpen: Bool, next: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = section.title {
                sectionHeader(title, section: section, index: index, isOpen: isOpen)
            }
            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                        row(block, inTitledSection: section.title != nil, next: next)
                    }
                }
                .padding(.vertical, 6)
                .background(.white, in: .rect(cornerRadius: 20))
            }
        }
    }

    private func sectionHeader(_ title: String, section: WorkSection, index: Int, isOpen: Bool) -> some View {
        Button {
            sectionOverrides[index] = !isOpen
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if section.total > 0, section.remaining(progress) == 0 {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sub)
                }
                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if section.total > 0 {
                    Text("\(section.total - section.remaining(progress))/\(section.total)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.sub)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sub)
                    .rotationEffect(.degrees(isOpen ? 0 : -90))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(isOpen ? "押すと、この段をたたむ" : "押すと、この段を開く"))
    }

    // MARK: - 行

    @ViewBuilder
    private func row(_ block: WorkDocument.Block, inTitledSection: Bool, next: String?) -> some View {
        switch block {
        case .heading, .footnote:
            EmptyView()
        case let .text(text):
            if inTitledSection, text.count <= 14 {
                // 「見る場所」「聞くこと」のような小見出し
                Text(text)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.sub)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
            } else {
                Text(text)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case let .bullet(text, details):
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 6, height: 6)
                        .frame(width: 26)
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                    itemText(text, details: details, key: "b\(text)", isDone: false)
                }
                moreButton(details: details, key: "b\(text)", isDone: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        case let .check(id, text, initially, details):
            checkRow(id: id, text: text, details: details, isChecked: progress.isChecked(id, initially: initially), isNext: id == next)
        case let .note(id, label, initial, hint):
            NoteField(
                label: label,
                hint: hint,
                text: progress.notes[id] ?? initial,
                focus: focusedNote,
                id: id,
                onChange: { onNote(id, $0) }
            )
        case let .choice(id, label, options):
            ChoiceRow(label: label, options: options, selected: progress.notes[id]) { option in
                onNote(id, progress.notes[id] == option ? "" : option)
            }
        }
    }

    private func checkRow(id: String, text: String, details: [String], isChecked: Bool, isNext: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { onToggle(id) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isChecked ? Theme.sub : Theme.ink)
                        .frame(width: 26)
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                    VStack(alignment: .leading, spacing: 4) {
                        if isNext {
                            Text("次はこれ")
                                .font(.system(size: 11, weight: .heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.amber, in: .capsule)
                        }
                        itemText(text, details: details, key: id, isDone: isChecked)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isChecked)
            .accessibilityAddTraits(isChecked ? .isSelected : [])
            .accessibilityHint(Text(isChecked ? "押すと、チェックを外す" : "押すと、チェックを付ける"))
            moreButton(details: details, key: id, isDone: isChecked)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isNext ? Theme.amberSoft : .clear, in: .rect(cornerRadius: 14))
        .padding(.horizontal, isNext ? 6 : 0)
    }

    /// 項目の1行と、その下の説明。説明は1行だけ出し、残りは「くわしく」にたたむ。済んだ項目は説明を出さない
    private func itemText(_ text: String, details: [String], key: String, isDone: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.system(size: 16, weight: isDone ? .regular : .bold))
                .foregroundStyle(isDone ? Theme.sub : Theme.ink)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(shownDetails(details, key: key, isDone: isDone).enumerated()), id: \.offset) { _, detail in
                Text(detail)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func shownDetails(_ details: [String], key: String, isDone: Bool) -> [String] {
        if isDone { return [] }
        return expanded.contains(key) ? details : Array(details.prefix(1))
    }

    /// 2行目からの説明を開く。項目を押す場所とは分けておく（押し間違えてチェックしない）
    @ViewBuilder
    private func moreButton(details: [String], key: String, isDone: Bool) -> some View {
        let hidden = details.count - shownDetails(details, key: key, isDone: isDone).count
        if !isDone, hidden > 0 {
            Button {
                expanded.insert(key)
            } label: {
                Text("くわしく（あと\(hidden)行）")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.sub)
                    .underline()
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 36)
        }
    }
}

/// 見出し（【】）ごとに分けた段。見出しより前の行は、見出しなしの段にまとめる
private struct WorkSection {
    let title: String?
    var blocks: [WorkDocument.Block]

    var checks: [(id: String, initially: Bool)] {
        blocks.compactMap { if case let .check(id, _, initially, _) = $0 { return (id, initially) } else { return nil } }
    }

    var total: Int { checks.count }

    func remaining(_ progress: WorkProgress) -> Int {
        checks.filter { !progress.isChecked($0.id, initially: $0.initially) }.count
    }

    static func split(_ document: WorkDocument) -> [WorkSection] {
        var result: [WorkSection] = []
        for block in document.blocks {
            switch block {
            case let .heading(title):
                result.append(WorkSection(title: title, blocks: []))
            case .footnote:
                continue
            default:
                if result.isEmpty {
                    result.append(WorkSection(title: nil, blocks: [block]))
                } else {
                    result[result.count - 1].blocks.append(block)
                }
            }
        }
        return result.filter { !$0.blocks.isEmpty }
    }
}

/// 書きこむ欄。書いたそばから保存する
private struct NoteField: View {
    let label: String
    let hint: String?
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
            TextField(hint.map { String(localized: "\($0)を書く") } ?? String(localized: "聞いたこと・気づいたことを書く"), text: $draft, axis: .vertical)
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

/// 選ぶだけの欄（「はい」「いいえ」など）。もう一度押すと外れる
private struct ChoiceRow: View {
    let label: String
    let options: [String]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .lineSpacing(3)
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selected
                    Button { onSelect(option) } label: {
                        Text(option)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 40)
                            .background(isSelected ? Theme.amber : Theme.ground, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .sensoryFeedback(.selection, trigger: isSelected)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
    let source: String
    @State private var progress = WorkProgress.empty
    @FocusState private var focused: String?

    var body: some View {
        let document = WorkDocument.parse(source)
        ScrollView {
            VStack(spacing: 16) {
                if document.hasChecklist {
                    WorkChecklistProgress(checked: progress.checkedCount(in: document), total: document.checkIDs.count)
                }
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
    ChecklistPreview(source: StoreShots.checklistSample)
}

#Preview("手続きの並び（前の版の長い文）") {
    ChecklistPreview(source: StoreShots.longProcedureSample)
}
#endif
