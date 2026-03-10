import SwiftUI
import UIKit

struct SettingsTabView: View {
  private enum RateField: Hashable {
    case usd
    case eur
  }

  private enum ExportWizardStep: Int, CaseIterable {
    case generateKey
    case runBotExport

    var title: String {
      switch self {
      case .generateKey:
        return "1. このキーをコピー"
      case .runBotExport:
        return "2. Botでexport実行"
      }
    }
  }

  @Binding var currencyCode: String
  @Binding var upcomingWindowDays: Int
  @Binding var usdToJpyRate: Double
  @Binding var eurToJpyRate: Double
  @Binding var notifyOnDueDate: Bool
  @Binding var notifyInAdvance: Bool
  @Binding var notificationLeadDays: Int
  @Binding var themeColorId: String
  @Binding var backgroundThemeId: String
  @FocusState private var focusedRateField: RateField?
  @State private var isPresentingExportWizard = false
  @State private var wizardStep: ExportWizardStep = .generateKey
  @State private var exportKey = ""
  @State private var exportKeyGeneratedAt: Date?
  @State private var exportKeyError: String?
  private let importService = MigrationImportService()
  private let japaneseLocale = Locale(identifier: "ja_JP")

  private let supportedCurrencyCodes = ["JPY", "USD", "EUR"]

  var body: some View {
    NavigationStack {
      ZStack {
        AppBackgroundView(option: AppBackgroundOption.option(for: backgroundThemeId))
        settingsScrollContent
      }
      .scrollIndicators(.hidden)
      .navigationTitle("設定")
    }
    .background(Color.clear)
    .toolbarBackground(.clear, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("完了") {
          focusedRateField = nil
        }
      }
    }
    .sheet(isPresented: $isPresentingExportWizard) {
      exportWizardSheet
    }
    .onChange(of: isPresentingExportWizard) { _, isPresented in
      if isPresented {
        wizardStep = .generateKey
        refreshExportKey()
      }
    }
    .onAppear {
      backgroundThemeId = AppThemeOption.backgroundId(forThemeId: themeColorId)
    }
  }

  private var settingsScrollContent: some View {
    ScrollView {
      VStack(spacing: 14) {
        settingsCard(title: "表示設定") { displaySection }
        settingsCard(title: "為替レート（円換算）") { exchangeRateSection }
        settingsCard(title: "通知") { notificationSection }
        settingsCard(title: "テーマカラー") { themeColorSection }
        settingsCard(title: "データ移行") { migrationSection }
        settingsCard(title: "保存") { storageSection }
      }
      .padding()
    }
  }

  private var displaySection: some View {
    VStack(spacing: 14) {
      Picker("通貨", selection: $currencyCode) {
        ForEach(supportedCurrencyCodes, id: \.self) { code in
          Text(code).tag(code)
        }
      }
      .pickerStyle(.segmented)

      Stepper(value: $upcomingWindowDays, in: 1...30) {
        Text("請求予定の表示期間: \(upcomingWindowDays)日")
      }
    }
  }

  private var exchangeRateSection: some View {
    VStack(spacing: 12) {
      rateInputRow(
        label: "1 USD =",
        value: $usdToJpyRate,
        placeholder: "例: 150",
        focus: .usd
      )
      rateInputRow(
        label: "1 EUR =",
        value: $eurToJpyRate,
        placeholder: "例: 160",
        focus: .eur
      )
    }
  }

  private var notificationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      customToggleRow(
        title: "当日通知（支払日当日 9:00）",
        isOn: $notifyOnDueDate
      )

      Text("事前通知")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)

      customToggleRow(
        title: "事前通知を有効にする",
        isOn: $notifyInAdvance
      )

      Picker("事前通知タイミング", selection: $notificationLeadDays) {
        Text("なし").tag(0)
        Text("1日前 9:00").tag(1)
        Text("3日前 9:00").tag(3)
        Text("7日前 9:00").tag(7)
      }
      .pickerStyle(.segmented)
      .disabled(!notifyInAdvance)
      .opacity(notifyInAdvance ? 1 : 0.45)
    }
  }

  private func customToggleRow(title: String, isOn: Binding<Bool>) -> some View {
    HStack(spacing: 12) {
      Text(title)
        .font(.title3.weight(.medium))
        .foregroundStyle(.white.opacity(0.92))
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Spacer(minLength: 12)

      Button {
        withAnimation(.spring(response: 0.1, dampingFraction: 1)) {
          isOn.wrappedValue.toggle()
        }
      } label: {
        ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
          Capsule(style: .continuous)
            .fill(
              isOn.wrappedValue
                ? AppThemeOption.color(for: themeColorId).opacity(0.45)
                : .white.opacity(0.16)
            )
            .overlay(
              Capsule(style: .continuous)
                .stroke(.white.opacity(isOn.wrappedValue ? 0.2 : 0.2), lineWidth: 1)
            )
            .frame(width: 66, height: 36)

          Circle()
            .fill(.white.opacity(0.98))
            .frame(width: 30, height: 30)
            .padding(3)
            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(title)
      .accessibilityAddTraits(.isButton)
      .accessibilityValue(isOn.wrappedValue ? "オン" : "オフ")
    }
  }

  private var themeColorSection: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(AppThemeOption.all) { option in
          let mappedBackground = AppBackgroundOption.option(
            for: AppThemeOption.backgroundId(forThemeId: option.id))
          Button {
            applyTheme(option.id)
          } label: {
            VStack(spacing: 6) {
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                  LinearGradient(
                    colors: [mappedBackground.topColor, mappedBackground.bottomColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 86, height: 56)
                .overlay(
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                      mappedBackground.glowColor.opacity(themeColorId == option.id ? 0.95 : 0.25),
                      lineWidth: themeColorId == option.id ? 2 : 1
                    )
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.primary.opacity(0.15), lineWidth: 1)
                )
              Text(option.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(option.name)
        }
      }
      .padding(.vertical, 2)
    }
  }

  private var migrationSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button {
        isPresentingExportWizard = true
        wizardStep = .generateKey
      } label: {
        Label("データ移行を開始する", systemImage: "wand.and.sparkles")
          .frame(maxWidth: .infinity)
          .foregroundStyle(.white)
      }
      .padding()
      .glassEffect(
        .regular.tint(AppThemeOption.color(for: themeColorId).opacity(0.2)).interactive(),
        in: .rect(cornerRadius: 12))

      Text("Discordの「お金守君」からサブスクデータの移行を行えます")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  private var storageSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("データは端末内に保存されます", systemImage: "internaldrive")
      Label("ログイン・サーバー通信は不要です", systemImage: "wifi.slash")
    }
    .foregroundStyle(.secondary)
  }

  private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
      content()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(.white.opacity(0.09), lineWidth: 1)
    )
  }

  private func rateInputRow(
    label: String,
    value: Binding<Double>,
    placeholder: String,
    focus: RateField
  ) -> some View {
    HStack(spacing: 10) {
      Text(label)
        .font(.title3.weight(.medium))
        .foregroundStyle(.white.opacity(0.92))
        .frame(width: 120, alignment: .leading)

      TextField(placeholder, value: value, format: .number.precision(.fractionLength(0...2)))
        .keyboardType(.decimalPad)
        .submitLabel(.done)
        .multilineTextAlignment(.trailing)
        .font(.title3.monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(0.08))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(
              focusedRateField == focus ? Color.accentColor.opacity(0.9) : .white.opacity(0.16),
              lineWidth: 1.2)
        )
        .focused($focusedRateField, equals: focus)

      Text("円")
        .font(.title3.weight(.medium))
        .foregroundStyle(.white.opacity(0.88))
    }
  }

  private func refreshExportKey() {
    do {
      exportKey = try importService.makeExportHandshakeKey()
      exportKeyGeneratedAt = .now
      exportKeyError = nil
    } catch {
      let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      exportKeyError = "キー生成失敗: \(message)"
    }
  }

  private func applyTheme(_ id: String) {
    themeColorId = id
    backgroundThemeId = AppThemeOption.backgroundId(forThemeId: id)
  }

  private var exportWizardSheet: some View {
    NavigationStack {
      ZStack {
        AppBackgroundView(option: AppBackgroundOption.option(for: backgroundThemeId))
          .ignoresSafeArea()

        VStack(spacing: 14) {
          HStack(spacing: 10) {
            Image(systemName: "wand.and.sparkles")
              .font(.headline)
              .foregroundStyle(.white.opacity(0.92))
              .padding(8)
              .background(.white.opacity(0.12), in: Circle())
            Text("エクスポート連携")
              .font(.title3.weight(.semibold))
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          HStack(spacing: 8) {
            ForEach(ExportWizardStep.allCases, id: \.rawValue) { step in
              Text(step.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(wizardStep.rawValue >= step.rawValue ? .white : .secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .background(
                  RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                      wizardStep.rawValue >= step.rawValue
                        ? Color.accentColor.opacity(0.27) : .white.opacity(0.08))
                )
            }
          }

          VStack(alignment: .leading, spacing: 12) {
            switch wizardStep {
            case .generateKey:
              wizardStepGenerateKey
            case .runBotExport:
              wizardStepBotExport
            }
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(.white.opacity(0.1), lineWidth: 1)
          )

          HStack(spacing: 10) {
            wizardSecondaryButton(title: "戻る", icon: "chevron.left") {
              if let prev = ExportWizardStep(rawValue: wizardStep.rawValue - 1) {
                wizardStep = prev
              }
            }
            .disabled(wizardStep == .generateKey)

            wizardPrimaryButton(
              title: wizardStep == .runBotExport ? "完了" : "次へ",
              icon: wizardStep == .runBotExport ? "checkmark" : "chevron.right"
            ) {
              if wizardStep == .runBotExport {
                isPresentingExportWizard = false
              } else if let next = ExportWizardStep(rawValue: wizardStep.rawValue + 1) {
                wizardStep = next
              }
            }
          }
          .padding(.top, 2)
        }
        .padding()
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isPresentingExportWizard = false
          } label: {
            Text("閉じる")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white.opacity(0.95))
              .padding(.horizontal, 16)
              .padding(.vertical, 9)
              .background(
                Capsule(style: .continuous)
                  .fill(.white.opacity(0.08))
              )
              .overlay(
                Capsule(style: .continuous)
                  .stroke(.white.opacity(0.18), lineWidth: 1)
              )
          }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }

  private var wizardStepGenerateKey: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("このキーを Bot の `/export` に貼り付けて使います。")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Group {
        if exportKey.isEmpty && exportKeyError == nil {
          HStack(spacing: 8) {
            ProgressView()
              .tint(.white.opacity(0.9))
            Text("キーを生成しています…")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
        } else {
          Text(exportKey.isEmpty ? "キー未生成" : exportKey)
            .font(.footnote.monospaced())
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
      }
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.white.opacity(0.07))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(.white.opacity(0.16), lineWidth: 1)
      )

      if let generatedAt = exportKeyGeneratedAt {
        Text(
          "生成時刻: \(generatedAt.formatted(.dateTime.locale(japaneseLocale).year().month().day().hour().minute().second()))"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      if let exportKeyError {
        Text(exportKeyError)
          .font(.footnote.weight(.medium))
          .foregroundStyle(.red)
      }

      Text("キーはウィザードを開くたびに自動生成されます。")
        .font(.caption)
        .foregroundStyle(.secondary)

      Button {
        UIPasteboard.general.string = exportKey
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "doc.on.doc.fill")
          Text("キーをコピー")
        }
        .font(.headline.weight(.semibold))
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .foregroundStyle(.white)
        .background(
          LinearGradient(
            colors: [
              Color.accentColor.opacity(0.95),
              Color.accentColor.opacity(0.72),
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .clipShape(Capsule(style: .continuous))
        .overlay(
          Capsule(style: .continuous)
            .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.accentColor.opacity(0.35), radius: 12, x: 0, y: 6)
      }
      .disabled(exportKey.isEmpty)
      .opacity(exportKey.isEmpty ? 0.55 : 1)
    }
  }

  private var wizardStepBotExport: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Discord 側で `/export` コマンドを実行してください。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text("返却された `sublife://export?data=...` を開くと、アプリに自動取り込みされます。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func wizardPrimaryButton(title: String, icon: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      HStack(spacing: 8) {
        Text(title)
        Image(systemName: icon)
          .font(.subheadline.weight(.bold))
      }
      .font(.headline.weight(.semibold))
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .foregroundStyle(.white)
      .background(
        LinearGradient(
          colors: [
            Color.accentColor.opacity(0.95),
            Color.accentColor.opacity(0.72),
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .clipShape(Capsule(style: .continuous))
      .overlay(
        Capsule(style: .continuous)
          .stroke(.white.opacity(0.2), lineWidth: 1)
      )
      .shadow(color: Color.accentColor.opacity(0.28), radius: 10, x: 0, y: 5)
    }
  }

  private func wizardSecondaryButton(title: String, icon: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
        Text(title)
      }
      .font(.headline.weight(.semibold))
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .foregroundStyle(.white.opacity(0.92))
      .background(
        Capsule(style: .continuous)
          .fill(.white.opacity(0.09))
      )
      .overlay(
        Capsule(style: .continuous)
          .stroke(.white.opacity(0.2), lineWidth: 1)
      )
    }
  }
}
