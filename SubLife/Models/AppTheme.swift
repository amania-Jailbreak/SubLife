import SwiftUI

struct AppThemeOption: Identifiable {
    let id: String
    let name: String
    let color: Color

    static let `default` = "blue"

    static let all: [AppThemeOption] = [
        .init(id: "blue", name: "ブルー", color: .blue),
        .init(id: "teal", name: "ティール", color: .teal),
        .init(id: "green", name: "グリーン", color: .green),
        .init(id: "orange", name: "オレンジ", color: .orange),
        .init(id: "red", name: "レッド", color: .red),
        .init(id: "pink", name: "ピンク", color: .pink),
        .init(id: "purple", name: "パープル", color: .purple),
        .init(id: "indigo", name: "インディゴ", color: .indigo)
    ]

    static func color(for id: String) -> Color {
        all.first(where: { $0.id == id })?.color ?? .blue
    }

    static func backgroundId(forThemeId id: String) -> String {
        all.contains(where: { $0.id == id }) ? id : `default`
    }
}

struct AppBackgroundOption: Identifiable {
    let id: String
    let name: String
    let topColor: Color
    let bottomColor: Color
    let glowColor: Color

    static let `default` = "blue"

    static let all: [AppBackgroundOption] = [
        .init(
            id: "blue",
            name: "ブルーオーラ",
            topColor: Color(red: 0.08, green: 0.14, blue: 0.3),
            bottomColor: Color(red: 0.01, green: 0.03, blue: 0.12),
            glowColor: .blue
        ),
        .init(
            id: "teal",
            name: "ティールミスト",
            topColor: Color(red: 0.04, green: 0.29, blue: 0.31),
            bottomColor: Color(red: 0.01, green: 0.09, blue: 0.11),
            glowColor: .teal
        ),
        .init(
            id: "green",
            name: "グリーンフォレスト",
            topColor: Color(red: 0.06, green: 0.24, blue: 0.19),
            bottomColor: Color(red: 0.01, green: 0.08, blue: 0.06),
            glowColor: .green
        ),
        .init(
            id: "orange",
            name: "オレンジサンセット",
            topColor: Color(red: 0.42, green: 0.18, blue: 0.12),
            bottomColor: Color(red: 0.13, green: 0.04, blue: 0.07),
            glowColor: .orange
        ),
        .init(
            id: "red",
            name: "レッドネオン",
            topColor: Color(red: 0.35, green: 0.09, blue: 0.13),
            bottomColor: Color(red: 0.12, green: 0.02, blue: 0.07),
            glowColor: .red
        ),
        .init(
            id: "pink",
            name: "ピンクブロッサム",
            topColor: Color(red: 0.36, green: 0.14, blue: 0.31),
            bottomColor: Color(red: 0.11, green: 0.03, blue: 0.13),
            glowColor: .pink
        ),
        .init(
            id: "purple",
            name: "パープルナイト",
            topColor: Color(red: 0.24, green: 0.12, blue: 0.36),
            bottomColor: Color(red: 0.06, green: 0.03, blue: 0.14),
            glowColor: .purple
        ),
        .init(
            id: "indigo",
            name: "インディゴコスモ",
            topColor: Color(red: 0.12, green: 0.11, blue: 0.33),
            bottomColor: Color(red: 0.03, green: 0.02, blue: 0.11),
            glowColor: .indigo
        )
    ]

    static func option(for id: String) -> AppBackgroundOption {
        switch id {
        case "midnightBlue":
            return option(for: "blue")
        case "forest":
            return option(for: "green")
        case "sunset":
            return option(for: "orange")
        case "violetNight":
            return option(for: "purple")
        case "graphite":
            return option(for: "blue")
        default:
            break
        }
        return all.first(where: { $0.id == id }) ?? all[0]
    }
}

struct AppBackgroundView: View {
    let option: AppBackgroundOption

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [option.topColor, option.bottomColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(option.glowColor.opacity(0.34))
                .frame(width: 360, height: 360)
                .blur(radius: 85)
                .offset(x: -150, y: -240)

            Circle()
                .fill(option.glowColor.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 75)
                .offset(x: 170, y: 260)
        }
        .ignoresSafeArea()
    }
}
