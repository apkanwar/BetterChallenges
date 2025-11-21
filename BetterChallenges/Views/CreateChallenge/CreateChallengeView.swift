import SwiftUI
import UIKit

struct CreateChallengeView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var maxPoints: Double = 600
    @State private var startDate: Date = Date()
    @State private var durationInDays: Int = 7
    @State private var selectedContacts: Set<ChallengeContact.ID> = []
    @State private var contactSearchText: String = ""

    var body: some View {
        Form {
            Section {
                TextField("Friends vs. Fam", text: $title)
                TextField("Optional description", text: $description, axis: .vertical)
            } header: {
                Text("Challenge Name")
            }

            Section {
                Stepper("\\(durationInDays) days", value: $durationInDays, in: 3...30)
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
            } header: {
                Text("Duration")
            }

            Section {
                Stepper("\\(Int(maxPoints)) pts / day", value: $maxPoints, in: 200...1200, step: 50)
            } header: {
                Text("Daily Points Allowed")
            } footer: {
                Text("Apple Fitness caps move points at 600. Customize the number to fit your group challenge.")
                    .font(.caption)
            }

            Section {
                contactList
            } header: {
                Text("Invite contacts")
            } footer: {
                Text("Invite up to seven friends (8 participants max) or keep it solo by leaving this empty.")
                    .font(.caption)
            }
        }
        .navigationTitle("New challenge")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    viewModel.createChallenge(
                        title: title,
                        description: description,
                        maxPoints: maxPoints,
                        startDate: startDate,
                        durationInDays: durationInDays,
                        invitedContactIDs: Array(selectedContacts)
                    )
                    dismiss()
                }
                .disabled(!canCreate)
            }
        }
        .task {
            viewModel.ensureContactsLoaded()
        }
    }

    private var canCreate: Bool {
        let totalParticipants = selectedContacts.count + 1
        return totalParticipants >= 1 && totalParticipants <= 8
    }

    @ViewBuilder
    private var contactList: some View {
        switch viewModel.contactsPermission {
        case .notDetermined:
            PermissionPromptView(
                title: "Allow Contacts Access",
                message: "We need your contacts to send challenge invites.",
                actionTitle: "Grant Access"
            ) {
                viewModel.ensureContactsLoaded()
            }
        case .denied(let message):
            PermissionPromptView(
                title: "Contacts Permission Needed",
                message: message,
                actionTitle: "Open Settings"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .granted:
            if viewModel.isLoadingContacts {
                ProgressView("Loading contacts...")
            } else if viewModel.contacts.isEmpty {
                Text("No contacts found.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Search contacts", text: $contactSearchText)
                        .textFieldStyle(.roundedBorder)
                    if contactSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Type to search your contacts. Leave this blank if you'd like to start the challenge solo.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if filteredContactsForCreation.isEmpty {
                        Text("No contacts match \"\\(contactSearchText)\".")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredContactsForCreation, id: \.id) { (contact: ChallengeContact) in
                            Button {
                                toggle(contact.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(contact.displayName)
                                        if let subtitle = contact.phoneNumber ?? contact.email {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedContacts.contains(contact.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ id: ChallengeContact.ID) {
        if selectedContacts.contains(id) {
            selectedContacts.remove(id)
        } else if selectedContacts.count < 7 {
            selectedContacts.insert(id)
        }
    }

    private var filteredContactsForCreation: [ChallengeContact] {
        let trimmed = contactSearchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return viewModel.contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmed) ||
            ($0.phoneNumber?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            ($0.email?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }
}
