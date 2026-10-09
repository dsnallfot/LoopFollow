import SwiftUI

struct HealthLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = HealthLoggingService()
    @State private var eventDate = Date()
    @State private var kind: HealthLogKind?
    @State private var selectedTitle = "Egen rubrik"
    @State private var customTitle = ""
    @State private var noteBody = ""
    @State private var isSaving = false
    @State private var result: ResultMessage?
    @FocusState private var textFocused: Bool
    @AppStorage("healthLogging.reminderList") private var listID = ""
    @AppStorage("healthLogging.pump") private var pump: HealthLogPump = .medtrum
    @AppStorage("healthLogging.omnipodHours") private var omnipodHours = 64
    @AppStorage("healthLogging.medtrumHours") private var medtrumHours = 72
    @AppStorage("healthLogging.sensorHours") private var sensorHours = 240
    @AppStorage("healthLogging.pumpWindowHours") private var pumpWindowHours = 8
    @AppStorage("healthLogging.sensorWindowHours") private var sensorWindowHours = 12

    private struct ResultMessage: Identifiable {
        let id = UUID()
        let text: String
        let success: Bool
    }

    private var hours: Binding<Int> {
        if kind == .sensor { return $sensorHours }
        return pump == .omnipod ? $omnipodHours : $medtrumHours
    }
    private var windowHours: Binding<Int> { kind == .sensor ? $sensorWindowHours : $pumpWindowHours }
    private var reminderDate: Date { HealthLoggingRules.reminderDate(eventDate: eventDate, hours: hours.wrappedValue) }
    private var title: String { selectedTitle == "Egen rubrik" ? customTitle : selectedTitle }
    private var isButtonDisabled: Bool { isSaving || !valid || service.isLoadingLists }
    private var valid: Bool {
        guard let kind else { return false }
        if kind.isReminder {
            return service.hasReminderAccess && service.lists.contains(where: { $0.id == listID }) && reminderDate > Date()
        }
        return kind == .insulin || (!title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                   !noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        Form {
            Section() {
                DatePicker("Datum och tid", selection: $eventDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    .environment(\.locale, Locale(identifier: "sv_SE"))
                Picker("Registrera", selection: $kind) {
                    Text("Välj…").tag(nil as HealthLogKind?)
                    ForEach(HealthLogKind.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
            }
            .listRowBackground(Color(.systemGray).opacity(0.15))
            if let kind {
                if kind.isReminder {
                    reminderSection(kind: kind)
                } else {
                    noteSection
                }
                LoadingButtonView(
                    buttonText: kind.isReminder ? "Utför" : "Registrera i Nightscout",
                    progressText: "Sparar…",
                    isLoading: isSaving,
                    action: {
                        textFocused = false
                        perform()
                    },
                    isDisabled: isButtonDisabled
                )
                .tint(isButtonDisabled ? .gray : .accentColor)
                .listRowBackground(Color.clear)
            }
        }
        .disabled(isSaving)
        .scrollContentBackground(.hidden)
        .background(ThemeBackground().ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Hälsologgning")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSaving)
        .interactiveDismissDisabled(isSaving)
        .task { await loadLists(requestAccess: false) }
        .alert(item: $result) { result in
            Alert(title: Text(result.success ? "Klart" : "Kunde inte spara"), message: Text(result.text),
                  dismissButton: .default(Text("OK")) { if result.success { dismiss() } })
        }
    }

    private func reminderSection(kind: HealthLogKind) -> some View {
        Section {
            if kind == .pump {
                Picker("Pump", selection: $pump) {
                    ForEach(HealthLogPump.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            if !service.lists.isEmpty {
                Picker("Påminnelselista", selection: $listID) {
                    Text("Välj lista").tag("")
                    ForEach(service.lists) { Text($0.displayName).tag($0.id) }
                }
            }
            Button {
                Task { await loadLists(requestAccess: true) }
            } label: {
                HStack {
                    Text(service.lists.isEmpty ? "Hämta påminnelselistor" : "Uppdatera listor")
                    if service.isLoadingLists { ProgressView() }
                }
            }
            .disabled(service.isLoadingLists)
            Stepper("Påminn efter \(hours.wrappedValue) timmar", value: hours, in: 1...720)
            Stepper("Byt inom \(windowHours.wrappedValue) timmar", value: windowHours, in: 1...72)
            VStack(alignment: .leading, spacing: 6) {
                Text(HealthLoggingRules.reminderTitle(kind: kind, pump: pump, windowHours: windowHours.wrappedValue))
                    .font(.headline)
                Text(HealthLoggingRules.formattedDate(reminderDate))
                if reminderDate <= Date() {
                    Text("Påminnelsetiden har passerat. Justera datum eller antal timmar.").foregroundStyle(.red)
                }
            }
        } header: {
            Text("Påminnelse")
        } footer: {
            Text("Välj er delade lista, exempelvis Byten. Tidigare bytespåminnelser av samma typ i den valda listan raderas och ersätts. Övriga påminnelser behålls. Delningen och synkroniseringen sköts av Påminnelser.")
        }
        .listRowBackground(Color(.systemGray).opacity(0.15))
    }

    private var noteSection: some View {
        Section {
            if kind == .note {
                Picker("Rubrik", selection: $selectedTitle) {
                    ForEach(HealthLoggingRules.noteTitles, id: \.self) { Text($0).tag($0) }
                }
                if selectedTitle == "Egen rubrik" {
                    TextField("Egen rubrik", text: $customTitle)
                        .focused($textFocused)
                }
            }
            TextField(kind == .note ? "Brödtext" : "Anteckning (valfri)", text: $noteBody, axis: .vertical)
                .lineLimit(3...8)
                .focused($textFocused)
        } header: {
            Text(kind == .note ? "Notering" : "Nytt insulin")
        } footer: {
            Text("Registreras på det valda datumet i den Nightscout-instans som är inställd i Loop Follow.")
        }
        .listRowBackground(Color(.systemGray).opacity(0.15))
    }

    private func loadLists(requestAccess: Bool) async {
        do {
            try await service.loadLists(requestAccess: requestAccess)
            if !service.lists.contains(where: { $0.id == listID }) {
                let matching = service.lists.filter { $0.title == "Byten" }
                listID = matching.count == 1 ? matching[0].id : ""
            }
            if requestAccess && service.lists.isEmpty {
                result = ResultMessage(text: "Inga skrivbara påminnelselistor hittades. Lägg till eller acceptera den delade listan i Påminnelser och försök igen.", success: false)
            }
        } catch {
            result = ResultMessage(text: error.localizedDescription, success: false)
        }
    }

    private func perform() {
        guard let kind, valid, !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let message: String
                if kind.isReminder {
                    message = try await service.replaceReminder(kind: kind, pump: pump, eventDate: eventDate,
                                                                hours: hours.wrappedValue, windowHours: windowHours.wrappedValue,
                                                                calendarID: listID)
                } else {
                    try await service.upload(kind: kind, date: eventDate, title: title, body: noteBody)
                    message = "\(kind.rawValue) registrerades i Nightscout."
                }
                result = ResultMessage(text: message, success: true)
            } catch {
                result = ResultMessage(text: error.localizedDescription, success: false)
            }
        }
    }
}
