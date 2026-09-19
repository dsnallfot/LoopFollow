import PhotosUI
import SwiftUI
import UIKit

// MARK: - UserDataViewController

@available(iOS 16.0, *)
struct UserDataViewController: View {
    @State private var profileImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var profile: UserProfileEntry?
    @State private var profiles: [UserProfileEntry] = []
    @State private var editingEntry: UserProfileEntry?
    @State private var profileToDelete: UserProfileEntry?
    @State private var showDeleteAlert: Bool = false
    @State private var viewingEntry: UserProfileEntry?
    @State private var showDeleteImageAlert: Bool = false

    private static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    // Helper to format date and append (Xår Yd) age if in past
    private static func formattedDateWithAge(_ date: Date?) -> String {
        guard let date else { return "ÅÅ-MM-DD" }

        let base = shortDateFormatter.string(from: date)
        let now = Date()
        let calendar = Calendar.current

        // If the date is in the future, just return the formatted date without age.
        guard date <= now else {
            return base
        }

        // First compute full years between date and now.
        let yearComponents = calendar.dateComponents([.year], from: date, to: now)
        let years = yearComponents.year ?? 0

        // Then compute remaining days after subtracting those full years.
        let dateAfterYears = calendar.date(byAdding: .year, value: years, to: date) ?? date
        let dayComponents = calendar.dateComponents([.day], from: dateAfterYears, to: now)
        let days = dayComponents.day ?? 0

        return String(format: "%@ (%då %dd)", base, years, days)
    }

    var body: some View {
        ZStack {
            //ThemeBackground()
                //.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header: profilbild + senaste profilinfo
                let imageSide = UIScreen.main.bounds.width / 4

                HStack(alignment: .top, spacing: 8) {
                    // Frame 1: Profilbild
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground).opacity(0.5))

                            if let img = profileImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: imageSide, height: imageSide)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedItem) { newItem in
                        guard let item = newItem else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    self.profileImage = uiImage
                                    UserProfileImageManager.shared.save(image: uiImage)
                                }
                            }
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                            if profileImage != nil {
                                showDeleteImageAlert = true
                            }
                        }
                    )
                    Spacer()

                    // Frames 2 & 3: Rubriker + värden
                    HStack(alignment: .top, spacing: 12) {
                        // Frame 2: Rubriker
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Namn:")
                            Text("Född:")
                            Text("T1D debut:")
                            Text("Längd:")
                            Text("Vikt (BMI):")
                            Text("Uppdaterades:")
                        }
                        .font(.caption2.monospacedDigit())

                        // Frame 3: Värden (senaste profil eller placeholders)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile?.name ?? "För- Efternamn")
                            Text(Self.formattedDateWithAge(profile?.birthDate))
                            Text(Self.formattedDateWithAge(profile?.t1dSince))
                            Text(profile?.heightCm.map { String(format: "%.1f cm", $0) } ?? "-- cm")
                            Text({
                                if let weight = profile?.weightKg,
                                   let heightCm = profile?.heightCm,
                                   heightCm > 0 {
                                    let heightM = heightCm / 100.0
                                    let bmi = weight / (heightM * heightM)
                                    return String(format: "%.1f kg (%.1f)", weight, bmi)
                                } else if let weight = profile?.weightKg {
                                    return String(format: "%.1f kg", weight)
                                } else {
                                    return "-- kg"
                                }
                            }())
                            Text(profile.map { Self.shortDateFormatter.string(from: $0.updatedAt) } ?? "ÅÅ-MM-DD")
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)

                        //Spacer()
                    }
                    .frame(height: imageSide, alignment: .top)
                }
                .padding(.vertical, 16)
                .padding(.leading, 24)
                .padding(.trailing, 16)
                Divider()

                // Sektion: tabell med historik
                if profiles.isEmpty {
                    Text("Ingen data finns registrerad ännu. Klicka på + uppe till vänster för att göra en första registrering.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(profiles) { entry in
                            UserProfileRow(entry: entry)
                                .listRowBackground(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewingEntry = entry
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        profileToDelete = entry
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Radera", systemImage: "trash")
                                    }

                                    Button {
                                        editingEntry = entry
                                    } label: {
                                        Label("Redigera", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .listStyle(.plain)
                }
                if profiles.isEmpty {
                    Spacer()
                }
            }
            .padding(.top, 12)
        }
        .onAppear {
            if profileImage == nil {
                profileImage = UserProfileImageManager.shared.load()
            }
            reloadProfiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userProfileUpdated)) { _ in
            reloadProfiles()
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                AddUserDataView(existingEntry: entry)
            }
        }
        .sheet(item: $viewingEntry) { entry in
            NavigationStack {
                AddUserDataView(existingEntry: entry, isReadOnly: true)
            }
        }
        .alert("Radera data", isPresented: $showDeleteAlert) {
            Button("Radera", role: .destructive) {
                if let toDelete = profileToDelete {
                    var stored = Storage.shared.userProfiles
                    stored.removeAll { $0.updatedAt == toDelete.updatedAt && $0.name == toDelete.name }
                    Storage.shared.userProfiles = stored
                    reloadProfiles()
                    profileToDelete = nil
                }
            }
            Button("Avbryt", role: .cancel) {
                profileToDelete = nil
            }
        } message: {
            if let toDelete = profileToDelete {
                Text("Vill du verkligen radera data registrerat \(Self.shortDateFormatter.string(from: toDelete.updatedAt))?")
            } else {
                Text("Vill du verkligen radera denna post?")
            }
        }
        .alert("Radera bild", isPresented: $showDeleteImageAlert) {
            Button("Radera", role: .destructive) {
                profileImage = nil
                UserProfileImageManager.shared.clear()
            }
            Button("Avbryt", role: .cancel) { }
        } message: {
            Text("Vill du radera nuvarande profilbild?")
        }
    }
    private func reloadProfiles() {
        let stored = Storage.shared.userProfiles.sorted { $0.updatedAt > $1.updatedAt }
        profiles = stored
        profile = stored.first
    }
}

