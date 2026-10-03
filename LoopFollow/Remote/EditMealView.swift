import SwiftUI
import HealthKit

@available(iOS 16.0, *)
struct EditMealView: View {
    let original: MealEditDraft
    let originalTreatment: [String: Any]
    @State private var draft: MealEditDraft
    @State private var isLoading = false
    @State private var status: String?
    @State private var succeeded = false
    @State private var showConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var receipts = RemoteCommandReceiptTracker.shared
    @ObservedObject private var maxCarbs = Storage.shared.maxCarbs
    @ObservedObject private var maxProtein = Storage.shared.maxProtein
    @ObservedObject private var maxFat = Storage.shared.maxFat

    init(raw: [String: Any], date: Date) {
        let original = MealEditDraft(raw: raw, date: date)
        self.original = original
        originalTreatment = raw
        _draft = State(initialValue: original)
    }

    private var limits: [Double] {
        [maxCarbs.value, maxProtein.value, maxFat.value].map { $0.doubleValue(for: .gram()) }
    }
    private var validationError: String? { draft.validationError(originalDate: original.date, limits: limits) }
    private var canSend: Bool {
        !isLoading && !receipts.hasPendingCommands && draft.differs(from: original) && validationError == nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackground().ignoresSafeArea()
                VStack(spacing: 0) {
                    RemoteCommandPendingBanner()
                    Form {
                        Section {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Ursprunglig måltid").bold()
                                Text("• Kolhydrater: \(original.carbs) g")
                                if (MealEditDraft.number(original.protein) ?? 0) > 0 { Text("• Protein: \(original.protein) g") }
                                if (MealEditDraft.number(original.fat) ?? 0) > 0 { Text("• Fett: \(original.fat) g") }
                                Text("• Anteckning: \(original.notes)")
                                Text("• Tid: \(original.date.formatted(.dateTime.hour().minute().second()))")
                            }
                            .font(.caption2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .listRowBackground(Color(.systemGray).opacity(0.15))
                        Section {
                            nutrientRow("Kolhydrater", value: $draft.carbs)
                            nutrientRow("Protein", value: $draft.protein)
                            nutrientRow("Fett", value: $draft.fat)

                            HStack {
                                Text("Anteckning")
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                TextField("Anteckning", text: $draft.notes, axis: .vertical)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .listRowBackground(Color(.systemGray).opacity(0.15))
                        Section {
                            DatePicker("Tid", selection: $draft.date, in: Date().addingTimeInterval(-MealEditDraft.historyLimit)...Date(),
                                       displayedComponents: [.date, .hourAndMinute])
                            .environment(\.locale, Locale(identifier: "sv_SE"))
                        }
                        .listRowBackground(Color(.systemGray).opacity(0.15))
                        if let error = validationError {
                            Section { Text(error).foregroundColor(.red).font(.footnote) }
                        }
                        LoadingButtonView(buttonText: "Skicka ändrad måltid", progressText: "Skickar ändrad måltid…",
                                          isLoading: isLoading, action: { showConfirmation = true }, isDisabled: !canSend)
                            .listRowBackground(Color.clear)
                    }
                    .scrollContentBackground(.hidden)
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Redigera måltid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() }.disabled(isLoading) }
                ToolbarItemGroup(placement: .keyboard) {
                        Spacer()

                        Button {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil,
                                from: nil,
                                for: nil
                            )
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                    }
                }
            .interactiveDismissDisabled(isLoading)
            .alert("Bekräfta ändrad måltid", isPresented: $showConfirmation) {
                Button("Avbryt", role: .cancel) { }
                Button("Bekräfta") { send() }
            } message: {
                Text("Kolhydrater: \(draft.carbs) g\nProtein: \(draft.protein) g\nFett: \(draft.fat) g\nAnteckning: \(draft.notes)\nTid: \(draft.date.formatted(.dateTime.hour().minute().second()))")
            }
            .alert(succeeded ? "Lyckades" : "Fel", isPresented: Binding(get: { status != nil }, set: { if !$0 { status = nil } })) {
                Button("OK") { if succeeded { dismiss() } }
            } message: { Text(status ?? "") }
        }
    }

    private func nutrientRow(_ title: String, value: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: value).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .frame(maxWidth: 100).accessibilityLabel(title)
            Text("g").foregroundColor(.secondary)
        }
    }

    private func send() {
        guard canSend else { return }
        isLoading = true
        PushNotificationManager().sendEditMealPushNotification(draft: draft, originalDate: original.date,
                                                              originalTreatment: originalTreatment) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                succeeded = success
                status = success ? "Ändringskommando skickades. Väntar på registrering i Nightscout." : (error ?? "Måltidsredigeringen misslyckades.")
            }
        }
    }
}
