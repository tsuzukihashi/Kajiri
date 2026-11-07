import SwiftUI

/// カジリがかじっている間（20秒ほどかかる）
struct SplittingCard: View {
    var body: some View {
        HStack(spacing: 14) {
            KajiriImage(pose: .gnaw, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                Text("カジリがかじっています…")
                    .font(.system(size: 16, weight: .heavy))
                Text("すぐ手が動く大きさに分けて、誰がやるかも決めています。20秒ほどかかります。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amberSoft, in: .rect(cornerRadius: 18))
    }
}

/// メールや LINE からも投げられる、の案内。メモの次に読むものではないので、箱に入れず控えめに
struct ShareHintRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15))
                .foregroundStyle(Theme.sub)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("メール・LINE・Safari からも投げられる")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("共有から「Kajiri」を選ぶと、ここに入ります。まとめて書いても、いちばん大きい丸太から分けます")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    VStack {
        SplittingCard()
        ShareHintRow()
    }
    .padding()
    .background(Theme.ground)
}
