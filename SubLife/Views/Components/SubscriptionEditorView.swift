import SwiftUI

struct SubscriptionEditorView: View {
    private enum SymbolGroup: String, CaseIterable, Identifiable {
        case all
        case media
        case device
        case work
        case life

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "すべて"
            case .media: return "メディア"
            case .device: return "デバイス"
            case .work: return "仕事"
            case .life: return "生活"
            }
        }

        var symbols: [String] {
            switch self {
            case .all:
                return SubscriptionItem.availableSymbolNames
            case .media:
                return ["play.rectangle.fill", "music.note", "sparkles", "gamecontroller.fill", "book.fill", "star.fill"]
            case .device:
                return ["cellularbars", "macbook", "macmini", "ipod", "iphone", "network", "airpods.max", "airpods", "cloud.fill", "cpu"]
            case .work:
                return ["creditcard.fill", "briefcase.fill", "shippingbox.fill", "cart.fill"]
            case .life:
                return ["house.fill", "heart.fill", "link"]
            }
        }
    }

    private enum InstallmentPreset: Int, CaseIterable, Identifiable {
        case m3 = 3
        case m6 = 6
        case m12 = 12
        case m24 = 24
        case m48 = 48
        case custom = -1

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .custom: return "カスタム"
            default: return "\(rawValue)回"
            }
        }
    }

    let title: String
    let catalogService: CatalogServicing
    let onSave: (SubscriptionItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var item: SubscriptionItem
    @State private var monthlyBillingDay: Int
    @State private var yearlyBillingMonth: Int
    @State private var yearlyBillingDay: Int
    @State private var installmentPreset: InstallmentPreset
    @State private var customInstallmentMonths: Int
    @State private var installmentStartDate: Date
    @State private var selectedSymbolGroup: SymbolGroup
    @State private var selectedSymbolName: String
    @State private var selectedColorId: String
    @State private var selectedCurrencyCode: String
    @State private var isPresentingCatalog = false

    init(
        title: String,
        item: SubscriptionItem,
        catalogService: CatalogServicing = CatalogService.live,
        onSave: @escaping (SubscriptionItem) -> Void
    ) {
        let initialMonths = min(max(item.installmentTotalMonths ?? 3, 1), 240)
        let preset = InstallmentPreset(rawValue: initialMonths) ?? .custom
        self.title = title
        self.catalogService = catalogService
        self.onSave = onSave
        _item = State(initialValue: item)
        _monthlyBillingDay = State(initialValue: item.effectiveBillingDayOfMonth)
        _yearlyBillingMonth = State(initialValue: item.effectiveBillingMonth)
        _yearlyBillingDay = State(initialValue: item.effectiveBillingDayOfMonth)
        _installmentPreset = State(initialValue: preset)
        _customInstallmentMonths = State(initialValue: initialMonths)
        _installmentStartDate = State(initialValue: item.installmentStartDate ?? .now)
        _selectedSymbolGroup = State(initialValue: .all)
        _selectedSymbolName = State(initialValue: item.effectiveSymbolName)
        _selectedColorId = State(initialValue: item.effectiveAccentColorId)
        _selectedCurrencyCode = State(initialValue: item.effectiveCurrencyCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    Button {
                        isPresentingCatalog = true
                    } label: {
                        Label("カタログから選択", systemImage: "magnifyingglass")
                    }
                    TextField("サービス名", text: $item.name)
                    TextField("金額", value: $item.price, format: .number)
                        .keyboardType(.decimalPad)

                    Picker("通貨", selection: $selectedCurrencyCode) {
                        ForEach(SubscriptionCurrency.allCases) { currency in
                            Text(currency.label).tag(currency.rawValue)
                        }
                    }

                    Picker("請求サイクル", selection: $item.billingCycle) {
                        ForEach(BillingCycle.allCases) { cycle in
                            Text(cycle.label).tag(cycle)
                        }
                    }

                    if item.billingCycle == .monthly {
                        Picker("請求日", selection: $monthlyBillingDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)日").tag(day)
                            }
                        }
                    } else if item.billingCycle == .yearly {
                        Picker("請求月", selection: $yearlyBillingMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)月").tag(month)
                            }
                        }

                        Picker("請求日", selection: $yearlyBillingDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)日").tag(day)
                            }
                        }
                    } else {
                        Picker("分割回数", selection: $installmentPreset) {
                            ForEach(InstallmentPreset.allCases) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }

                        if installmentPreset == .custom {
                            Stepper(value: $customInstallmentMonths, in: 1...240) {
                                Text("カスタム回数: \(customInstallmentMonths)回")
                            }
                        }

                        DatePicker(
                            "開始日",
                            selection: $installmentStartDate,
                            displayedComponents: .date
                        )

                        Picker("支払日", selection: $monthlyBillingDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)日").tag(day)
                            }
                        }
                    }
                }

                Section("分類") {
                    Picker("カテゴリ", selection: $item.category) {
                        ForEach(SubscriptionCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }

                    Picker("ステータス", selection: $item.status) {
                        ForEach(SubscriptionStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }

                Section("アイコン") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SymbolGroup.allCases) { group in
                                Button {
                                    selectedSymbolGroup = group
                                } label: {
                                    Text(group.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(selectedSymbolGroup == group ? .white : .secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(selectedSymbolGroup == group ? Color.accentColor.opacity(0.34) : .white.opacity(0.08))
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(selectedSymbolGroup == group ? Color.accentColor.opacity(0.85) : .white.opacity(0.12), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    let filteredSymbols = selectedSymbolGroup.symbols.filter {
                        SubscriptionItem.availableSymbolNames.contains($0)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                        ForEach(filteredSymbols, id: \.self) { symbol in
                            Button {
                                selectedSymbolName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(selectedSymbolName == symbol ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .fill(selectedSymbolName == symbol ? Color.accentColor.opacity(0.38) : .white.opacity(0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(selectedSymbolName == symbol ? Color.accentColor.opacity(0.9) : .white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(SubscriptionItem.colorOptions) { option in
                                Button {
                                    selectedColorId = option.id
                                } label: {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(.white.opacity(selectedColorId == option.id ? 0.95 : 0), lineWidth: 2)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(.primary.opacity(0.15), lineWidth: 1)
                                        )
                                }
                                .accessibilityLabel(option.name)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("メモ") {
                    TextField("任意メモ", text: $item.memo, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .onChange(of: item.billingCycle) { _, cycle in
                if cycle == .monthly {
                    monthlyBillingDay = item.effectiveBillingDayOfMonth
                } else if cycle == .yearly {
                    yearlyBillingMonth = item.effectiveBillingMonth
                    yearlyBillingDay = item.effectiveBillingDayOfMonth
                } else {
                    monthlyBillingDay = item.effectiveBillingDayOfMonth
                    installmentStartDate = item.installmentStartDate ?? .now
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        var savingItem = item
                        savingItem.symbolName = selectedSymbolName
                        savingItem.accentColorId = selectedColorId
                        savingItem.currencyCode = selectedCurrencyCode

                        if savingItem.billingCycle == .monthly {
                            savingItem.billingMonth = nil
                            savingItem.installmentTotalMonths = nil
                            savingItem.installmentStartDate = nil
                            savingItem.billingDayOfMonth = monthlyBillingDay
                            savingItem.nextBillingDate = savingItem.nextChargeDate()
                        } else if savingItem.billingCycle == .yearly {
                            savingItem.billingMonth = yearlyBillingMonth
                            savingItem.installmentTotalMonths = nil
                            savingItem.installmentStartDate = nil
                            savingItem.billingDayOfMonth = yearlyBillingDay
                            savingItem.nextBillingDate = savingItem.nextChargeDate()
                        } else {
                            savingItem.billingMonth = nil
                            savingItem.billingDayOfMonth = monthlyBillingDay
                            savingItem.installmentStartDate = installmentStartDate
                            savingItem.installmentTotalMonths =
                                installmentPreset == .custom
                                ? customInstallmentMonths
                                : installmentPreset.rawValue
                            savingItem.nextBillingDate = savingItem.nextChargeDate()
                        }

                        onSave(savingItem)
                        dismiss()
                    }
                    .disabled(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || item.price < 0)
                }
            }
        }
        .sheet(isPresented: $isPresentingCatalog) {
            SubscriptionCatalogSheet(catalogService: catalogService) { app, plan in
                applyCatalogSelection(app: app, plan: plan)
                isPresentingCatalog = false
            }
        }
    }

    private func applyCatalogSelection(app: CatalogAppSummary, plan: CatalogPlan) {
        item.name = app.name
        item.price = plan.price
        selectedCurrencyCode = plan.currencyCode
        item.billingCycle = plan.billingCycle

        if let symbolName = app.symbolNameFallback,
           SubscriptionItem.availableSymbolNames.contains(symbolName) {
            selectedSymbolName = symbolName
        }

        if let category = app.category {
            item.category = category
        }

        item.memo = mergeProviderIntoMemo(company: app.company, memo: item.memo)
    }

    private func mergeProviderIntoMemo(company: String, memo: String) -> String {
        let providerLine = "提供元: \(company)"
        let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return providerLine }

        var lines = memo.components(separatedBy: .newlines)
        if let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           first.hasPrefix("提供元:") {
            lines[0] = providerLine
            return lines.joined(separator: "\n")
        }
        return providerLine + "\n" + memo
    }
}
