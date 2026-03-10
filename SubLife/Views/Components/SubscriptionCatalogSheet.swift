import SwiftUI

struct SubscriptionCatalogSheet: View {
  let catalogService: CatalogServicing
  let onSelect: (CatalogAppSummary, CatalogPlan) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @State private var searchResults: [CatalogAppSummary] = []
  @State private var isLoading = false
  @State private var hasSearched = false
  @State private var errorMessage: String?
  @State private var searchTask: Task<Void, Never>?
  @State private var lastSearchedQuery = ""
  @State private var latestRequestedQuery = ""

  var body: some View {
    NavigationStack {
      ZStack {
        CatalogSheetBackground()

        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            headerSection
            contentSection
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 36)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .scrollIndicators(.hidden)
      .onChange(of: query) { _, newValue in
        scheduleSearch(for: newValue)
      }
      .onDisappear {
        searchTask?.cancel()
      }
    }
  }

  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 12) {
        Button("閉じる") {
          dismiss()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.white.opacity(0.08), in: Capsule(style: .continuous))
        .overlay(
          Capsule(style: .continuous)
            .stroke(.white.opacity(0.14), lineWidth: 1)
        )

        Spacer(minLength: 0)

        VStack(alignment: .trailing, spacing: 4) {
          Text("カタログから選択")
            .font(.title2.weight(.bold))
            .foregroundStyle(.white.opacity(0.97))
        }
      }

      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.white.opacity(0.54))

        TextField("サービス名で検索", text: $query)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled(true)
          .submitLabel(.search)
          .foregroundStyle(.white)
          .onSubmit {
            submitSearch()
          }

        if isLoading {
          ProgressView()
            .scaleEffect(0.9)
            .tint(.white.opacity(0.85))
        } else if !query.isEmpty {
          Button {
            query = ""
            resetSearchState()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.white.opacity(0.38))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(18)
      .frame(height: 58)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .stroke(.white.opacity(0.12), lineWidth: 1)
      )
      .shadow(color: .blue.opacity(0.16), radius: 28, x: 0, y: 18)
    }
  }

  @ViewBuilder
  private var contentSection: some View {
    if let errorMessage {
      CatalogStatusCard(
        title: "検索に失敗しました",
        message: errorMessage,
        systemImage: "wifi.exclamationmark",
        accentColor: .red,
        actionTitle: "再試行",
        action: { submitSearch() }
      )
    } else if !hasSearched && !isLoading {
      CatalogStatusCard(
        title: "探したいサービスを検索",
        message: "動画、音楽、ソフトウェアなどを入力すると候補をまとめて表示します。",
        systemImage: "sparkle.magnifyingglass",
        accentColor: .blue
      )
    } else if isLoading && searchResults.isEmpty {
      loadingSection
    } else if hasSearched && searchResults.isEmpty {
      CatalogStatusCard(
        title: "一致するサービスはありません",
        message: "キーワードを少し変えると見つかる可能性があります。",
        systemImage: "tray",
        accentColor: .orange
      )
    } else {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("検索結果")
              .font(.headline.weight(.semibold))
              .foregroundStyle(.white.opacity(0.96))
            Text("\(searchResults.count)件の候補")
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.65))
          }

          Spacer()

          if isLoading {
            ProgressView()
              .tint(.white.opacity(0.9))
          }
        }

        LazyVStack(spacing: 14) {
          ForEach(searchResults) { app in
            NavigationLink {
              CatalogPlanPickerView(app: app) { selectedPlan in
                onSelect(app, selectedPlan)
                dismiss()
              }
            } label: {
              CatalogAppRow(app: app)
            }
            .buttonStyle(.plain)
            .disabled(app.plans.isEmpty)
            .opacity(app.plans.isEmpty ? 0.66 : 1)
          }
        }
      }
    }
  }

  private var loadingSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("検索中...")
        .font(.headline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.92))

      ForEach(0..<3, id: \.self) { _ in
        CatalogLoadingCard()
      }
    }
  }

  private func scheduleSearch(for value: String) {
    searchTask?.cancel()

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      resetSearchState()
      return
    }

    searchTask = Task {
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      await runSearch(trimmed, triggeredByUser: false)
    }
  }

  private func submitSearch() {
    searchTask?.cancel()
    guard !trimmedQuery.isEmpty else {
      resetSearchState()
      return
    }

    Task {
      await runSearch(trimmedQuery, triggeredByUser: true)
    }
  }

  @MainActor
  private func runSearch(_ trimmed: String, triggeredByUser: Bool) async {
    guard !trimmed.isEmpty else {
      resetSearchState()
      return
    }

    guard triggeredByUser || trimmed != lastSearchedQuery else {
      return
    }

    latestRequestedQuery = trimmed
    errorMessage = nil
    hasSearched = true
    isLoading = true

    let requestQuery = trimmed
    do {
      let results = try await catalogService.searchApps(query: requestQuery)
      guard latestRequestedQuery == requestQuery else { return }
      searchResults = results
      lastSearchedQuery = requestQuery
    } catch {
      guard latestRequestedQuery == requestQuery else { return }
      searchResults = []
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    isLoading = false
  }

  @MainActor
  private func resetSearchState() {
    searchTask?.cancel()
    searchResults = []
    isLoading = false
    hasSearched = false
    errorMessage = nil
    lastSearchedQuery = ""
    latestRequestedQuery = ""
  }
}

private struct CatalogAppRow: View {
  let app: CatalogAppSummary

  var body: some View {
    HStack(spacing: 14) {
      iconView

      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text(app.name)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white.opacity(0.95))
            .lineLimit(1)
          Text(app.company)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.62))
            .lineLimit(1)
        }

        HStack(spacing: 8) {
          if let category = app.category {
            badge(title: category.label, systemImage: "square.grid.2x2")
          }
          badge(
            title: app.plans.isEmpty ? "プラン未登録" : "\(app.plans.count)プラン",
            systemImage: app.plans.isEmpty ? "exclamationmark.triangle" : "checkmark.circle"
          )
        }
      }

      Spacer(minLength: 12)

      VStack(alignment: .trailing, spacing: 10) {
        if app.plans.isEmpty {
          Text("選択不可")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.4))
        } else {
          Text("プランを見る")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.cyan.opacity(0.92))

          Image(systemName: "arrow.right.circle.fill")
            .font(.title3)
            .foregroundStyle(.white.opacity(0.88), .cyan.opacity(0.65))
        }
      }
    }
    .padding(16)
    .background(
      LinearGradient(
        colors: [
          Color.white.opacity(app.plans.isEmpty ? 0.06 : 0.11),
          Color.white.opacity(app.plans.isEmpty ? 0.03 : 0.05)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(.white.opacity(app.plans.isEmpty ? 0.08 : 0.12), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
  }

  @ViewBuilder
  private var iconView: some View {
    if let url = app.iconURL {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          fallbackIcon
        }
      }
      .frame(width: 56, height: 56)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    } else {
      fallbackIcon
        .frame(width: 56, height: 56)
    }
  }

  private var fallbackIcon: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
      Image(systemName: app.symbolNameFallback ?? "creditcard.fill")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.white.opacity(0.82))
    }
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(.white.opacity(0.08), lineWidth: 1)
    )
  }

  private func badge(title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
      .font(.caption.weight(.medium))
      .foregroundStyle(.white.opacity(0.72))
      .lineLimit(1)
      .minimumScaleFactor(0.9)
      .fixedSize(horizontal: true, vertical: false)
      .layoutPriority(1)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.white.opacity(0.08), in: Capsule(style: .continuous))
  }
}

struct CatalogPlanPickerView: View {
  let app: CatalogAppSummary
  let onSelect: (CatalogPlan) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      CatalogSheetBackground()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 14) {
            Button {
              dismiss()
            } label: {
              Label("戻る", systemImage: "chevron.left")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.white.opacity(0.08), in: Capsule(style: .continuous))
                .overlay(
                  Capsule(style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Text(app.name)
              .font(.largeTitle.weight(.bold))
              .foregroundStyle(.white.opacity(0.96))

            HStack(spacing: 8) {
              if let category = app.category {
                Label(category.label, systemImage: "square.grid.2x2")
              }
              Label("\(app.plans.count)プラン", systemImage: "checkmark.circle")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.74))
          }
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
              .stroke(.white.opacity(0.12), lineWidth: 1)
          )

          LazyVStack(spacing: 14) {
            ForEach(app.plans) { plan in
              Button {
                onSelect(plan)
              } label: {
                HStack(spacing: 14) {
                  VStack(alignment: .leading, spacing: 8) {
                    Text(plan.name)
                      .font(.headline.weight(.semibold))
                      .foregroundStyle(.white.opacity(0.94))
                      .frame(maxWidth: .infinity, alignment: .leading)

                    Label(plan.billingCycle.label, systemImage: "calendar")
                      .font(.caption.weight(.medium))
                      .foregroundStyle(.white.opacity(0.68))
                  }

                  Spacer(minLength: 12)

                  VStack(alignment: .trailing, spacing: 8) {
                    Text(plan.price, format: .currency(code: plan.currencyCode))
                      .font(.title3.weight(.bold))
                      .foregroundStyle(.white.opacity(0.98))
                    Text("このプランを選択")
                      .font(.caption.weight(.semibold))
                      .foregroundStyle(.cyan.opacity(0.9))
                  }
                }
                .padding(18)
                .background(
                  LinearGradient(
                    colors: [Color.white.opacity(0.11), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ),
                  in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
              }
              .buttonStyle(.plain)
            }
          }

          Spacer(minLength: 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 36)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .scrollIndicators(.hidden)
  }
}

private struct CatalogSheetBackground: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.06, green: 0.1, blue: 0.22),
          Color(red: 0.03, green: 0.04, blue: 0.1),
          Color(red: 0.02, green: 0.03, blue: 0.07)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Circle()
        .fill(Color.cyan.opacity(0.22))
        .frame(width: 320, height: 320)
        .blur(radius: 90)
        .offset(x: 160, y: -220)

      Circle()
        .fill(Color.blue.opacity(0.26))
        .frame(width: 340, height: 340)
        .blur(radius: 100)
        .offset(x: -170, y: -260)

      Circle()
        .fill(Color.indigo.opacity(0.2))
        .frame(width: 280, height: 280)
        .blur(radius: 100)
        .offset(x: 180, y: 260)
    }
    .ignoresSafeArea()
  }
}

private struct CatalogStatusCard: View {
  let title: String
  let message: String
  let systemImage: String
  let accentColor: Color
  var actionTitle: String? = nil
  var action: (() -> Void)? = nil

  var body: some View {
    VStack(spacing: 18) {
      ZStack {
        Circle()
          .fill(accentColor.opacity(0.18))
          .frame(width: 74, height: 74)
        Image(systemName: systemImage)
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(.white.opacity(0.94))
      }

      VStack(spacing: 8) {
        Text(title)
          .font(.title3.weight(.bold))
          .foregroundStyle(.white.opacity(0.96))
          .multilineTextAlignment(.center)

        Text(message)
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.64))
          .multilineTextAlignment(.center)
      }

      if let actionTitle, let action {
        Button(actionTitle) {
          action()
        }
        .buttonStyle(.borderedProminent)
        .tint(accentColor)
      }
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 28)
    .frame(maxWidth: .infinity)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .stroke(.white.opacity(0.12), lineWidth: 1)
    )
    .shadow(color: accentColor.opacity(0.16), radius: 24, x: 0, y: 16)
  }
}

private struct CatalogLoadingCard: View {
  var body: some View {
    HStack(spacing: 14) {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(.white.opacity(0.08))
        .frame(width: 56, height: 56)

      VStack(alignment: .leading, spacing: 10) {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(.white.opacity(0.12))
          .frame(maxWidth: 180)
          .frame(height: 16)

        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(.white.opacity(0.08))
          .frame(maxWidth: 120)
          .frame(height: 12)

        HStack(spacing: 8) {
          RoundedRectangle(cornerRadius: 999, style: .continuous)
            .fill(.white.opacity(0.08))
            .frame(width: 76, height: 24)
          RoundedRectangle(cornerRadius: 999, style: .continuous)
            .fill(.white.opacity(0.08))
            .frame(width: 62, height: 24)
        }
      }

      Spacer()
    }
    .padding(16)
    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(.white.opacity(0.08), lineWidth: 1)
    )
  }
}
