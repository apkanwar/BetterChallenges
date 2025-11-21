//
//  ContentView.swift
//  BetterChallenges
//
//  Created by Atinderpaul Kanwar on 2025-11-19.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var showingNewChallenge = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ringSection
                }

                Section("Active challenges") {
                    if viewModel.activeChallenges.isEmpty {
                        Text("You do not have any active group challenges. Start a new one to see it here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical)
                    } else {
                        ForEach(viewModel.activeChallenges) { challenge in
                            NavigationLink {
                                ChallengeDetailView(
                                    challenge: binding(for: challenge),
                                    viewModel: viewModel
                                )
                            } label: {
                                ChallengeRowView(challenge: challenge)
                            }
                        }
                    }
                }

                if !viewModel.completedChallenges.isEmpty {
                    Section {
                        NavigationLink {
                            PastChallengesView(viewModel: viewModel)
                        } label: {
                            Label("View completed challenges", systemImage: "clock.arrow.circlepath")
                                .font(.headline)
                        }
                    }
                }
            }
            .listRowSpacing(18)
            .listStyle(.insetGrouped)
            .navigationTitle("Better Challenges")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.isSyncingHealth {
                        ProgressView()
                    } else {
                        Button {
                            Task { await viewModel.refreshHealthData() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.healthPermission != .granted)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewChallenge = true
                        viewModel.ensureContactsLoaded()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $showingNewChallenge) {
                NavigationStack {
                    NewChallengeView(viewModel: viewModel)
                }
            }
            .alert("Heads up", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var ringSection: some View {
        if let snapshot = viewModel.todaysSnapshot {
            RingSummaryView(snapshot: snapshot)
        } else if viewModel.healthPermission == .granted {
            VStack(alignment: .leading, spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Syncing your rings from Apple Health...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .task {
                await viewModel.refreshHealthData()
            }
        } else {
            HealthPermissionView(
                permission: viewModel.healthPermission,
                isLoading: viewModel.isSyncingHealth,
                requestAccess: viewModel.requestHealthAuthorization
            )
        }
    }

    private func binding(for challenge: Challenge) -> Binding<Challenge> {
        Binding(
            get: {
                viewModel.challenges.first(where: { $0.id == challenge.id }) ?? challenge
            },
            set: { updated in
                if let index = viewModel.challenges.firstIndex(where: { $0.id == updated.id }) {
                    viewModel.challenges[index] = updated
                }
            }
        )
    }
}

struct RingSummaryView: View {
    var snapshot: FitnessRingSnapshot

    private var titleFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Today's Rings")
                        .font(.headline)
                    Text(titleFormatter.string(from: snapshot.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total points")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(Int(snapshot.totalPoints.rounded())) pts earned so far today")
                        .font(.headline)
                }
                Spacer()
            }

            ForEach(snapshot.ringMetrics) { metric in
                Gauge(value: metric.gaugeFraction, in: 0...1.25) {
                    Text(metric.title)
                } currentValueLabel: {
                    Text(metric.progressDescription)
                        .font(.caption2)
                }
                .gaugeStyle(.accessoryLinear)
                .tint(gaugeTint(for: metric.title))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func gaugeTint(for title: String) -> Color {
        switch title {
        case "Move":
            return Color(red: 0.98, green: 0.36, blue: 0.35)
        case "Exercise":
            return Color(red: 0.22, green: 0.75, blue: 0.33)
        default:
            return Color(red: 0.27, green: 0.53, blue: 0.97)
        }
    }
}

struct HealthPermissionView: View {
    var permission: PermissionStatus
    var isLoading: Bool
    var requestAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect to Apple Health")
                .font(.headline)
            Text("Authorize Better Challenges to read your Move, Exercise, and Stand rings so we can score each challenge.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if case .denied(let message) = permission {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                requestAccess()
            } label: {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Grant Health Access")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct ChallengeRowView: View {
    var challenge: Challenge

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text(challenge.title)
                        .font(.headline)
                    Text(challenge.durationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(Int(challenge.maxDailyPoints)) pts")
                        .font(.subheadline)
                    Text(challenge.isActive ? "Active" : "Completed")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(challenge.isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        )
                }
            }

            ParticipantAvatarStack(participants: challenge.participants)

            if let leader = challenge.totalLeaderboard.first {
                HStack {
                    let title = challenge.isCompleted ? "\(leader.name) won" : "\(leader.name) leads"
                    Label(title, systemImage: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(leader.totalPoints(maxDailyPoints: challenge.maxDailyPoints).rounded())) pts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

struct ParticipantAvatarStack: View {
    var participants: [ChallengeParticipant]

    var body: some View {
        HStack(spacing: -12) {
            ForEach(participants.prefix(5)) { participant in
                Text(initials(for: participant))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(participant.accentColor.color)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .accessibilityLabel("\(participant.name)")
            }
            if participants.count > 5 {
                Text("+\(participants.count - 5)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
    }

    private func initials(for participant: ChallengeParticipant) -> String {
        let parts = participant.name.split(separator: " ")
        let initials = parts.prefix(2).map { $0.prefix(1) }.joined()
        return initials.isEmpty ? String(participant.name.prefix(2)) : initials
    }
}

struct ChallengeDetailView: View {
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

struct PastChallengesView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        List {
            if viewModel.completedChallenges.isEmpty {
                Text("You have not completed any challenges yet.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical)
            } else {
                ForEach(viewModel.completedChallenges) { challenge in
                    NavigationLink {
                        ChallengeDetailView(
                            challenge: binding(for: challenge),
                            viewModel: viewModel
                        )
                    } label: {
                        ChallengeRowView(challenge: challenge)
                    }
                }
            }
        }
        .listRowSpacing(18)
        .listStyle(.insetGrouped)
        .navigationTitle("Completed Challenges")
    }

    private func binding(for challenge: Challenge) -> Binding<Challenge> {
        Binding(
            get: {
                viewModel.challenges.first(where: { $0.id == challenge.id }) ?? challenge
            },
            set: { updated in
                if let index = viewModel.challenges.firstIndex(where: { $0.id == updated.id }) {
                    viewModel.challenges[index] = updated
                }
            }
        )
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
            if position < 3 {
                Circle()
                    .fill(badgeColor)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text("\(position + 1)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            } else {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Text("\(position + 1)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(.separator), lineWidth: 1)
                    )
            }
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

struct NewChallengeView: View {
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
                Stepper("\(durationInDays) days", value: $durationInDays, in: 3...30)
                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
            } header: {
                Text("Duration")
            }

            Section {
                Stepper("\(Int(maxPoints)) pts / day", value: $maxPoints, in: 200...1200, step: 50)
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
                        Text("No contacts match \"\(contactSearchText)\".")
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

struct PermissionPromptView: View {
    var title: String
    var message: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ContentView()
        }
    }
}
#endif
