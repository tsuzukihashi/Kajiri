import SwiftUI

/// 色と絵。地は冷たい薄いグレー、文字はほぼ黒、差し色はカジリのハチマキの琥珀色1色だけ。
enum Theme {
    static let ground = Color(red: 0xEF / 255, green: 0xEF / 255, blue: 0xF4 / 255)
    static let card = Color(red: 0xF8 / 255, green: 0xF8 / 255, blue: 0xFA / 255)
    static let ink = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    static let sub = Color(red: 0x6C / 255, green: 0x6C / 255, blue: 0x70 / 255)
    static let chip = Color(red: 0xE3 / 255, green: 0xE3 / 255, blue: 0xE8 / 255)
    static let line = Color(red: 0xD5 / 255, green: 0xD5 / 255, blue: 0xDA / 255)
    static let freeTime = Color(red: 0xE2 / 255, green: 0xE2 / 255, blue: 0xE7 / 255)
    static let amber = Color(red: 0xF5 / 255, green: 0xB8 / 255, blue: 0x3D / 255)
    static let amberSoft = Color(red: 0xFC / 255, green: 0xEB / 255, blue: 0xC6 / 255)
    /// まとまりとまとまりの間。行どうし（0〜10）よりはっきり大きく空ける
    static let sectionSpacing: CGFloat = 30
}

/// カジリの絵（ChatGPT の Image で作った、絵本の水彩の絵）
enum KajiriPose: String {
    case sit = "kajiri_sit"
    case hand = "kajiri_hand"
    case gnaw = "kajiri_gnaw"
    case think = "kajiri_think"
    case dam = "kajiri_dam"
    case face = "kajiri_face"
}

struct KajiriImage: View {
    let pose: KajiriPose
    let size: CGFloat

    var body: some View {
        Image(pose.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Text("カジリ"))
    }
}

/// 黒い角丸の大きなボタン（いちばん押すボタン）
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Theme.ink.opacity(configuration.isPressed ? 0.8 : 1), in: .rect(cornerRadius: 16))
    }
}

/// グレーの角丸ボタン（2番目のボタン）。押せないときは薄くする（押しても反応しないように見せない）
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SecondaryButtonBody(configuration: configuration)
    }

    private struct SecondaryButtonBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.chip.opacity(configuration.isPressed ? 0.7 : 1), in: .rect(cornerRadius: 14))
                .opacity(isEnabled ? 1 : 0.45)
        }
    }
}

/// カジリのひとこと。カジリは脇役なので、絵は小さく言葉の横に添える（画面の主役は、やること・数・届いたもの）
struct KajiriSays: View {
    let pose: KajiriPose
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            KajiriImage(pose: pose, size: 52)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.card, in: .rect(cornerRadius: 16))
            Spacer(minLength: 0)
        }
    }
}

/// カジリの吹き出し
struct KajiriBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 17, weight: .heavy))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Theme.card, in: .rect(cornerRadius: 20))
            Triangle()
                .fill(Theme.card)
                .frame(width: 20, height: 10)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("ボタンと吹き出し") {
    VStack(spacing: 16) {
        KajiriSays(pose: .hand, text: "これだけ持って。ほかは、おれが持ってる。")
        Button("できた") {}.buttonStyle(PrimaryButtonStyle())
        Button("あとで") {}.buttonStyle(SecondaryButtonStyle())
    }
    .padding()
    .background(Theme.ground)
}
