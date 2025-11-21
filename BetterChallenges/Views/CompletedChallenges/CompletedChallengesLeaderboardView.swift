import SwiftUI
import UIKit

struct CompletedChallengesLeaderboardView: View {
    @Binding var challenge: Challenge
    @ObservedObject var viewModel: AppViewModel
    @State private var showingInviteSheet = false

    private var canInvite: Bool {
        !challenge.isCompleted && Date() < challenge.startDate && challenge.participants.count < 8
    }

    var body: some View {
        List {
            if challenge.isCompleted {
                Section("Leaderboard") {
                    ForEach(Array(challenge.totalLeaderboard.enumerated()), id: \.element.id) { index, participant in
                        LeaderboardRow(participant: participant, challenge: challenge, isTotal: true, position: index)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(challenge.description)
                            .font(.body)
                        Label("\(Int(challenge.maxDailyPoints)) pts max per day", systemImage: "target")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let currentSnapshot = challenge.participants.first(where: { $0.isCurrentUser })?.todaysSnapshot {
                        RingSummaryView(snapshot: currentSnapshot)
                    }
                } header: {
                    Text("Overview")
                }

                Section("Today's leaderboard") {
                    ForEach(Array(challenge.dayLeaderboard.enumerated()), id: \.element.id) { index, participant in
                        LeaderboardRow(participant: participant, challenge: challenge, isTotal: false, position: index)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                }

                Section("Total points") {
                    ForEach(Array(challenge.totalLeaderboard.enumerated()), id: \.element.id) { index, participant in
                        LeaderboardRow(participant: participant, challenge: challenge, isTotal: true, position: index)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                }
            }
        }
        .listRowSpacing(18)
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canInvite {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Invite") {
                        showingInviteSheet = true
                        viewModel.ensureContactsLoaded()
                    }
                }
            }
        }
        .sheet(isPresented: $showingInviteSheet) {
            NavigationStack {
                InviteContactsView(
                    contacts: viewModel.contacts,
                    permission: viewModel.contactsPermission,
                    existingContactIDs: Set(challenge.participants.compactMap { $0.contactID }),
                    currentParticipantCount: challenge.participants.count,
                    onInvite: { ids in
                        viewModel.addParticipants(ids, to: challenge.id)
                        showingInviteSheet = false
                    },
                    requestAccess: viewModel.ensureContactsLoaded
                )
            }
        }
    }
}

struct LeaderboardRow: View {
    var participant: ChallengeParticipant
    var challenge: Challenge
    var isTotal: Bool
    var position: Int

    var body: some View {
        HStack(spacing: 12) {
            rankBadge
            Text(participant.name)
                .font(.headline)
            Spacer()
            Text("\(Int(points.rounded())) pts")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var points: Double {
        if isTotal {
            participant.totalPoints(maxDailyPoints: challenge.maxDailyPoints)
        } else {
            participant.todaysPoints(maxDailyPoints: challenge.maxDailyPoints)
        }
    }

    private var rankBadge: some View {
        Group {
            Circle()
                .fill(position < 3 ? badgeColor : Color(.secondarySystemBackground))
                .frame(width: 34, height: 34)
                .overlay(
                    Text("\(position + 1)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(position < 3 ? .white : .primary)
                )
                .overlay(
                    Circle()
                        .stroke(Color(.separator), lineWidth: 1)
                )
        }
    }

    private var badgeColor: Color {
        switch position {
        case 0:
            return Color(red: 0.96, green: 0.78, blue: 0.22)
        case 1:
            return Color(red: 0.76, green: 0.78, blue: 0.82)
        case 2:
            return Color(red: 0.80, green: 0.56, blue: 0.40)
        default:
            return Color(.tertiaryLabel)
        }
    }
}

struct InviteContactsView: View {
    var contacts: [ChallengeContact]
    var permission: PermissionStatus
    var existingContactIDs: Set<String>
    var currentParticipantCount: Int
    var onInvite: ([ChallengeContact.ID]) -> Void
    var requestAccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selections: Set<ChallengeContact.ID> = []
    @State private var searchText: String = ""

    var body: some View {
        Form {
            Section {
                inviteContent
            } header: {
                Text("Contacts")
            } footer: {
                footerText
            }
        }
        .navigationTitle("Invite friends")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Send Invites") {
                    onInvite(Array(selections))
                    dismiss()
                }
                .disabled(selections.isEmpty)
            }
        }
    }

    private var maxSelectable: Int {
        max(0, 8 - currentParticipantCount)
    }

    private var footerText: some View {
        Group {
            if maxSelectable == 0 {
                Text("This challenge already has the maximum of 8 participants.")
            } else {
                Text("Invite up to \(maxSelectable) more friends (8 participants max). Solo challenges are allowed.")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var inviteContent: some View {
        switch permission {
        case .granted:
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search contacts", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                if contacts.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Fetching your contacts...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                } else if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Type a name, email, or phone number to find contacts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else if filteredContacts.isEmpty {
                    Text("No contacts match \"\(searchText)\".")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(filteredContacts, id: \.id) { (contact: ChallengeContact) in
                        let disabled = existingContactIDs.contains(contact.id)
                        Button {
                            guard !disabled else { return }
                            toggle(contact.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(contact.displayName)
                                    if let subtitle = contactSubtitle(contact) {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if disabled {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                } else if selections.contains(contact.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(disabled)
                    }
                }
            }
        case .notDetermined:
            PermissionPromptView(
                title: "Allow Contacts Access",
                message: "We need access to your contacts to send invites.",
                actionTitle: "Grant Access",
                action: requestAccess
            )
        case .denied(let message):
            PermissionPromptView(
                title: "Contacts Permission Needed",
                message: message,
                actionTitle: "Open Settings",
                action: openSettings
            )
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func toggle(_ id: ChallengeContact.ID) {
        if selections.contains(id) {
            selections.remove(id)
        } else if selections.count < maxSelectable {
            selections.insert(id)
        }
    }

    private func contactSubtitle(_ contact: ChallengeContact) -> String? {
        contact.phoneNumber ?? contact.email
    }

    private var filteredContacts: [ChallengeContact] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmed) ||
            ($0.phoneNumber?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            ($0.email?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }
}
