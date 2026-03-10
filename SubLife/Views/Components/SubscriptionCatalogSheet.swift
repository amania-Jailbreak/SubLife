import SwiftUI

struct SubscriptionCatalogSheet: View {
  let catalogService: CatalogServicing
  let onSelect: (CatalogAppSummary, CatalogPlan) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @State private var searchResults: [CatalogAppSummary] = []
  @State private var isLoading = false
  @State private var hasSearched = false
  @State private var validationMessage: String?
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Group {
        if isLoading {
          VStack(spacing: 12) {
            ProgressView()
            Text("検索中...")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
          VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
              .font(.title2)
              .foregroundStyle(.secondary)
            Text(errorMessage)
              .multilineTextAlignment(.center)
              .foregroundStyle(.secondary)
            Button("再試行") {
              Task { await search() }
            }
            .buttonStyle(.borderedProminent)
          }
          .padding()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !hasSearched {
          ContentUnavailableView(
            "カタログ検索",
            systemImage: "magnifyingglass",
            description: Text("キーワードを入力して検索してください")
          )
        } else if searchResults.isEmpty {
          ContentUnavailableView(
            "一致するサービスはありません",
            systemImage: "tray",
            description: Text("キーワードを変えて再検索してください")
          )
        } else {
          List(searchResults) { app in
            NavigationLink {
              CatalogPlanPickerView(app: app) { selectedPlan in
                onSelect(app, selectedPlan)
                dismiss()
              }
            } label: {
              CatalogAppRow(app: app)
            }
            .disabled(app.plans.isEmpty)
            .opacity(app.plans.isEmpty ? 0.55 : 1)
          }
          .listStyle(.plain)
        }
      }
      .navigationTitle("カタログから選択")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("閉じる") { dismiss() }
        }
      }
      .safeAreaInset(edge: .top) {
        searchHeader
      }
    }
  }

  private var searchHeader: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        TextField("サービス名で検索", text: $query)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled(true)
          .textFieldStyle(.roundedBorder)

        Button("検索") {
          Task { await search() }
        }
        .buttonStyle(.borderedProminent)
      }

      if let validationMessage {
        Text(validationMessage)
          .font(.caption)
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.horizontal)
    .padding(.top, 6)
    .padding(.bottom, 10)
    .background(.ultraThinMaterial)
  }

  @MainActor
  private func search() async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      validationMessage = "キーワードを入力してください"
      return
    }

    validationMessage = nil
    errorMessage = nil
    isLoading = true
    hasSearched = true

    do {
      searchResults = try await catalogService.searchApps(query: trimmed)
    } catch {
      searchResults = []
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    isLoading = false
  }
}

private struct CatalogAppRow: View {
  let app: CatalogAppSummary

  var body: some View {
    HStack(spacing: 12) {
      iconView

      VStack(alignment: .leading, spacing: 3) {
        Text(app.name)
          .font(.body.weight(.semibold))
          .lineLimit(1)
        Text(app.company)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      if app.plans.isEmpty {
        Text("プランなし")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.thinMaterial, in: Capsule())
      }
    }
    .padding(.vertical, 4)
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
      .frame(width: 42, height: 42)
      .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    } else {
      fallbackIcon
        .frame(width: 42, height: 42)
    }
  }

  private var fallbackIcon: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(Color.secondary.opacity(0.12))
      Image(systemName: app.symbolNameFallback ?? "creditcard.fill")
        .foregroundStyle(.secondary)
    }
  }
}

struct CatalogPlanPickerView: View {
  let app: CatalogAppSummary
  let onSelect: (CatalogPlan) -> Void

  var body: some View {
    List(app.plans) { plan in
      Button {
        onSelect(plan)
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(plan.name)
              .font(.body.weight(.semibold))
            Text(plan.billingCycle.label)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text(plan.price, format: .currency(code: plan.currencyCode))
            .font(.body.weight(.semibold))
        }
        .padding(.vertical, 4)
      }
      .buttonStyle(.plain)
    }
    .listStyle(.plain)
    .navigationTitle("プラン選択")
    .navigationBarTitleDisplayMode(.inline)
  }
}
