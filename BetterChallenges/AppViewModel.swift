//
//  AppViewModel.swift
//  BetterChallenges
//
//  Created by Codex on 2025-11-19.
//

import Combine
import CoreData
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var todaysSnapshot: FitnessRingSnapshot?
    @Published var challenges: [Challenge]
    @Published var contacts: [ChallengeContact] = []
    @Published var healthPermission: PermissionStatus = .notDetermined
    @Published var contactsPermission: PermissionStatus = .notDetermined
    @Published var isSyncingHealth = false
    @Published var isLoadingContacts = false
    @Published var errorMessage: String?

    private let healthKitManager = HealthKitManager()
    private let contactsManager = ContactsManager()
    private let persistence: PersistenceController
    private let context: NSManagedObjectContext
    private let currentParticipantID: UUID
    private static let currentUserIDKey = "BetterChallenges_CurrentUserID"

    init(persistenceController: PersistenceController = .shared) {
        self.persistence = persistenceController
        self.context = persistenceController.container.viewContext
        if let stored = UserDefaults.standard.string(forKey: Self.currentUserIDKey),
           let uuid = UUID(uuidString: stored) {
            self.currentParticipantID = uuid
        } else {
            let newID = UUID()
            UserDefaults.standard.set(newID.uuidString, forKey: Self.currentUserIDKey)
            self.currentParticipantID = newID
        }
        self.challenges = []
        loadPersistedChallenges()
        self.healthPermission = healthKitManager.currentPermissionStatus()
        if case .granted = healthPermission {
            Task {
                await refreshHealthData()
            }
        }
    }

    var activeChallenges: [Challenge] {
        challenges.filter { $0.isActive }.sorted { $0.startDate > $1.startDate }
    }

    var completedChallenges: [Challenge] {
        challenges.filter { $0.isCompleted }.sorted { $0.endDate > $1.endDate }
    }

    func requestHealthAuthorization() {
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                healthPermission = .granted
                await refreshHealthData()
            } catch {
                healthPermission = .denied(message: error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }

    func refreshHealthData() async {
        guard case .granted = healthPermission else { return }
        isSyncingHealth = true
        defer { isSyncingHealth = false }
        do {
            let snapshot = try await healthKitManager.fetchTodayRings()
            apply(snapshot: snapshot)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func ensureContactsLoaded() {
        guard !isLoadingContacts else { return }
        Task {
            await loadContacts()
        }
    }

    private func loadContacts() async {
        isLoadingContacts = true
        defer { isLoadingContacts = false }
        do {
            if case .notDetermined = contactsPermission {
                try await contactsManager.requestAccess()
                contactsPermission = .granted
            }
            guard case .granted = contactsPermission else { return }
            let fetched = try contactsManager.fetchContacts(limit: 80)
            contacts = fetched
        } catch {
            contactsPermission = .denied(message: error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func createChallenge(
        title: String,
        description: String,
        maxPoints: Double,
        startDate: Date,
        durationInDays: Int,
        invitedContactIDs: [ChallengeContact.ID]
    ) {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: max(durationInDays - 1, 0), to: startDate) ?? startDate

        var participants: [ChallengeParticipant] = []

        let currentParticipant = ChallengeParticipant(
            id: currentParticipantID,
            name: "You",
            contactID: nil,
            isCurrentUser: true,
            accentColor: ColorData(red: 0.98, green: 0.36, blue: 0.35),
            todaysSnapshot: todaysSnapshot,
            accumulatedPoints: todaysSnapshot?.totalPoints ?? 0
        )
        participants.append(currentParticipant)

        let contactMap = Dictionary(uniqueKeysWithValues: contacts.map { ($0.id, $0) })
        let maxInvitable = max(0, 8 - 1) // account for the current user already in the list
        for identifier in invitedContactIDs.prefix(maxInvitable) {
            guard let contact = contactMap[identifier] else { continue }
            if participants.contains(where: { $0.contactID == contact.id }) {
                continue
            }
            participants.append(contact.makeParticipant())
        }

        let challenge = Challenge(
            id: UUID(),
            title: title.isEmpty ? "New Challenge" : title,
            description: description.isEmpty ? "Friendly competition to keep your streak going." : description,
            maxDailyPoints: maxPoints,
            startDate: startDate,
            endDate: endDate,
            participants: participants
        )

        challenges.insert(challenge, at: 0)
        persistAllChallenges()
    }

    func addParticipants(_ contactIDs: [ChallengeContact.ID], to challenge: Challenge.ID) {
        guard let challengeIndex = challenges.firstIndex(where: { $0.id == challenge }) else { return }
        guard Date() < challenges[challengeIndex].startDate else { return }
        var selected = Set(contactIDs)
        guard !selected.isEmpty else { return }

        var challengeCopy = challenges[challengeIndex]
        let remainingSlots = max(0, 8 - challengeCopy.participants.count)
        guard remainingSlots > 0 else { return }
        var added = 0
        for contact in contacts where selected.contains(contact.id) {
            guard added < remainingSlots else { break }
            if challengeCopy.participants.contains(where: { $0.contactID == contact.id }) {
                continue
            }
            challengeCopy.participants.append(contact.makeParticipant())
            selected.remove(contact.id)
            added += 1
        }

        challenges[challengeIndex] = challengeCopy
        persistAllChallenges()
    }

    private func apply(snapshot: FitnessRingSnapshot) {
        todaysSnapshot = snapshot
        for index in challenges.indices {
            challenges[index].updateParticipant(currentParticipantID, snapshot: snapshot)
        }
    }

    private func loadPersistedChallenges() {
        let request: NSFetchRequest<ChallengeEntity> = ChallengeEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChallengeEntity.startDate, ascending: false)]
        do {
            let entities = try context.fetch(request)
            if entities.isEmpty {
                seedSampleData()
            } else {
                self.challenges = entities.compactMap { $0.toChallenge() }
            }
        } catch {
            errorMessage = "Failed to load saved challenges: \(error.localizedDescription)"
            self.challenges = []
        }
    }

    private func seedSampleData() {
        let samples = Challenge.sampleData(currentParticipantID: currentParticipantID)
        self.challenges = samples
        persistAllChallenges()
    }

    private func persistAllChallenges() {
        context.performAndWait {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ChallengeEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            do {
                try context.execute(deleteRequest)
            } catch {
                Task { @MainActor in
                    self.errorMessage = "Unable to update saved challenges: \(error.localizedDescription)"
                }
            }

            for challenge in challenges {
                challenge.insert(into: context)
            }

            persistence.save(context: context)
        }
    }
}
