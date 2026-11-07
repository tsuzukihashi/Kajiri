import SwiftUI

/// 分解の結果の1行。誰がやるかは見出しで分けてあるので、行には印を付けず、2行目は時間・4象限・要るもの
struct StepRow: View {
    let step: StepDTO

    var body: some View {
        let owner = StepOwner(rawValue: step.owner) ?? .me
        let quadrant = Quadrant(rawValue: step.quadrant) ?? .stock
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(detail(owner: owner, quadrant: quadrant))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    private func detail(owner: StepOwner, quadrant: Quadrant) -> String {
        var parts: [String] = []
        if owner == .me { parts.append(String(localized: "\(step.minutes)分")) }
        if let who = step.askWho, owner == .other { parts.append(who) }
        if owner == .wait { parts.append(String(localized: "返事待ち")) }
        if let work = step.kajiriWork, owner == .kajiri { parts.append(work) }
        parts.append(quadrant.label)
        if step.needsComputer { parts.append(String(localized: "パソコンが要る")) }
        return parts.joined(separator: " · ")
    }
}

#if DEBUG
#Preview {
    SectionBox(title: "薪", detail: nil) {
        ForEach(DecomposeResult.sampleTax.steps, id: \.title) { StepRow(step: $0) }
    }
    .padding()
    .background(Theme.ground)
}
#endif
