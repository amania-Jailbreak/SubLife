import SwiftUI

struct SubscriptionEditorView: View {
    let title: String
    let onSave: (SubscriptionItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var item: SubscriptionItem
    @State private var monthlyBillingDay: Int
    @State private var yearlyBillingMonth: Int
    @State private var yearlyBillingDay: Int
    @State private var selectedSymbolName: String
    @State private var selectedColorId: String
    @State private var selectedCurrencyCode: String

    init(title: String, item: SubscriptionItem, onSave: @escaping (SubscriptionItem) -> Void) {
        self.title = title
        self.onSave = onSave
        _item = State(initialValue: item)
        _monthlyBillingDay = State(initialValue: item.effectiveBillingDayOfMonth)
        _yearlyBillingMonth = State(initialValue: item.effectiveBillingMonth)
        _yearlyBillingDay = State(initialValue: item.effectiveBillingDayOfMonth)
        _selectedSymbolName = State(initialValue: item.effectiveSymbolName)
        _selectedColorId = State(initialValue: item.effectiveAccentColorId)
        _selectedCurrencyCode = State(initialValue: item.effectiveCurrencyCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
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
                    } else {
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
                    Picker("シンボル", selection: $selectedSymbolName) {
                        ForEach(SubscriptionItem.availableSymbolNames, id: \.self) { symbol in
                            Label(symbol, systemImage: symbol)
                                .tag(symbol)
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
                } else {
                    yearlyBillingMonth = item.effectiveBillingMonth
                    yearlyBillingDay = item.effectiveBillingDayOfMonth
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
                            savingItem.billingDayOfMonth = monthlyBillingDay
                            savingItem.nextBillingDate = savingItem.nextChargeDate()
                        } else {
                            savingItem.billingMonth = yearlyBillingMonth
                            savingItem.billingDayOfMonth = yearlyBillingDay
                            savingItem.nextBillingDate = savingItem.nextChargeDate()
                        }

                        onSave(savingItem)
                        dismiss()
                    }
                    .disabled(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || item.price < 0)
                }
            }
        }
    }
}
