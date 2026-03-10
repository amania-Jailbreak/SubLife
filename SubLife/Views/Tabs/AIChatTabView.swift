import SwiftUI

struct AIChatTabView: View {
  let backgroundThemeId: String

  var body: some View {
    NavigationStack {
      ZStack {
        AppBackgroundView(option: AppBackgroundOption.option(for: backgroundThemeId))
        VStack {
          Image(systemName: "message")
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 100)
            .foregroundStyle(.secondary)
          Text("AIチャット機能は現在開発中です。")
            .font(.headline)
            .foregroundStyle(.primary)

          Text("AIチャットで何ができますか?")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text("・オンデバイスAIを使用したチャット ※\n・サブスクリプションの管理や質問に対応\n・将来的には、おすすめのプランの提案も予定")
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
          Text(
            "※ AI機能は全てオンデバイスで行う予定です。そのため、iPhone15以降のデバイス向けに開発しています。 \nなお予期せずオンライン処理になる可能性もございます。"
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.top, 8)
          .padding()
        }

      }
      .navigationTitle("AIチャット")
    }
    .background(Color.clear)
    .toolbarBackground(.clear, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
  }
}
