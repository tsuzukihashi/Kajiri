import SwiftUI

/// 分解の結果の1行。左の印で、誰がやるかが分かる
struct StepRow: View {
    let step: StepDTO

    var body: some View {
        let owner = StepOwner(rawValue: step.owner) ?? .me
        let quadrant = Quadrant(rawValue: step.quadrant) ?? .stock
        HStack(spacing: 12) {
            OwnerBadge(owner: owner)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 15, weight: .bold))
                Text(detail(owner: owner, quadrant: quadrant))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay {
            if owner == .wait {
                RoundedRectangle(cornerRadius: 18).stroke(Color(white: 0.66), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(owner: StepOwner, quadrant: Quadrant) -> String {
        var parts = [owner.label]
        if owner == .me { parts.append(String(localized: "\(step.minutes)分")) }
        if let who = step.askWho, owner == .other { parts.append(who) }
        if let work = step.kajiriWork, owner == .kajiri { parts.append(work) }
        parts.append(quadrant.label)
        if step.needsComputer { parts.append(String(localized: "パソコンが要る")) }
        return parts.joined(separator: " · ")
    }
}

/// 誰がやるかの印（じぶん・カジリ・仲間・待ち）
struct OwnerBadge: View {
    let owner: StepOwner

    var body: some View {
        Group {
            switch owner {
            case .kajiri:
                KajiriImage(pose: .face, size: 30)
            case .me:
                Image(systemName: "person")
            case .other:
                Image(systemName: "person.2")
            case .wait:
                Image(systemName: "hourglass")
            }
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(Theme.ink)
        .frame(width: 40, height: 40)
        .background(owner == .kajiri ? Theme.amberSoft : Theme.chip, in: .rect(cornerRadius: 12))
        .accessibilityLabel(Text(owner.label))
    }
}

#if DEBUG
#Preview {
    VStack {
        ForEach(DecomposeResult.sampleTax.steps, id: \.title) { StepRow(step: $0) }
    }
    .padding()
    .background(Theme.ground)
}
#endif
