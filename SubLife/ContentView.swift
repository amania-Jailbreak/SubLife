//
//  ContentView.swift
//  SubLife
//
//  Created by amania on 2026/02/26.
//

import SwiftUI

enum RootTab: Hashable {
    case dashboard
    case calendar
    case settings
}

struct ContentView: View {
    private struct ImportAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @StateObject private var store = SubscriptionStore()
    @State private var draft = SubscriptionItem.sample
    @State private var isPresentingAdd = false
    @State private var editingItem: SubscriptionItem?
    @State private var selectedTab: RootTab = .dashboard
    @State private var importAlert: ImportAlert?

    @AppStorage("preferredCurrencyCode") private var preferredCurrencyCode = "JPY"
    @AppStorage("upcomingWindowDays") private var upcomingWindowDays = 7
    @AppStorage("usdToJpyRate") private var usdToJpyRate = 150.0
    @AppStorage("eurToJpyRate") private var eurToJpyRate = 160.0
    @AppStorage("notificationLeadDays") private var notificationLeadDays = 0
    @AppStorage("themeColorId") private var themeColorId = AppThemeOption.default
    @AppStorage("backgroundThemeId") private var backgroundThemeId = AppBackgroundOption.default
    private let importService = MigrationImportService()

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardTabView(
                store: store,
                upcomingWindowDays: upcomingWindowDays,
                usdToJpy: usdToJpyRate,
                eurToJpy: eurToJpyRate,
                backgroundThemeId: backgroundThemeId,
                onAddTapped: prepareAdd,
                onEditTapped: { editingItem = $0 }
            )
            .tabItem {
                Label("ホーム", systemImage: "house")
            }
            .tag(RootTab.dashboard)

            CalendarTabView(
                items: store.items,
                usdToJpy: usdToJpyRate,
                eurToJpy: eurToJpyRate,
                backgroundThemeId: backgroundThemeId
            )
            .tabItem {
                Label("カレンダー", systemImage: "calendar")
            }
            .tag(RootTab.calendar)

            SettingsTabView(
                currencyCode: $preferredCurrencyCode,
                upcomingWindowDays: $upcomingWindowDays,
                usdToJpyRate: $usdToJpyRate,
                eurToJpyRate: $eurToJpyRate,
                notificationLeadDays: $notificationLeadDays,
                themeColorId: $themeColorId,
                backgroundThemeId: $backgroundThemeId
            )
            .tabItem {
                Label("設定", systemImage: "gearshape")
            }
            .tag(RootTab.settings)
        }
        .background(.clear)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(AppThemeOption.color(for: themeColorId))
        .sheet(isPresented: $isPresentingAdd) {
            SubscriptionEditorView(
                title: "サブスク追加",
                item: draft,
                onSave: { store.add($0) }
            )
        }
        .sheet(item: $editingItem) { item in
            SubscriptionEditorView(
                title: "サブスク編集",
                item: item,
                onSave: { store.update($0) }
            )
        }
        .task {
            await NotificationScheduler.shared.requestAuthorizationIfNeeded()
            await NotificationScheduler.shared.reschedule(items: store.items, leadDays: notificationLeadDays)
        }
        .onChange(of: store.items) { _, newItems in
            Task {
                await NotificationScheduler.shared.reschedule(items: newItems, leadDays: notificationLeadDays)
            }
        }
        .onChange(of: notificationLeadDays) { _, newLeadDays in
            Task {
                await NotificationScheduler.shared.reschedule(items: store.items, leadDays: newLeadDays)
            }
        }
        .onOpenURL(perform: handleIncomingURL)
        .alert(item: $importAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func prepareAdd() {
        draft = SubscriptionItem(
            id: UUID(),
            name: "",
            price: 0,
            currencyCode: "JPY",
            billingCycle: .monthly,
            symbolName: "creditcard.fill",
            accentColorId: "blue",
            billingMonth: nil,
            billingDayOfMonth: Calendar.current.component(.day, from: .now),
            nextBillingDate: .now,
            category: .other,
            status: .active,
            memo: ""
        )
        isPresentingAdd = true
    }

    private func handleImport(_ importedItems: [SubscriptionItem]) {
        store.importMerge(importedItems)
        Task {
            await NotificationScheduler.shared.reschedule(items: store.items, leadDays: notificationLeadDays)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "sublife" else { return }

        guard url.host?.lowercased() == "export" else {
            importAlert = .init(title: "移行リンクエラー", message: "対応していないURLです。")
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == "data" })?.value,
              !encoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            importAlert = .init(title: "移行リンクエラー", message: "data パラメータが見つかりません。")
            return
        }

        do {
            let payload = try importService.decodeImportPayload(from: encoded)
            let result = importService.mapToSubscriptionItems(payload)

            if !result.validItems.isEmpty {
                handleImport(result.validItems)
                selectedTab = .dashboard
            }

            var message = "\(result.validItems.count)件取り込み / \(result.skippedCount)件スキップ"
            if let firstError = result.errors.first {
                message += "\n例: \(firstError)"
            }
            importAlert = .init(title: "移行完了", message: message)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            importAlert = .init(title: "移行失敗", message: message)
        }
    }
}

#Preview {
    ContentView()
}
