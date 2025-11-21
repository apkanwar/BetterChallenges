import CoreData
import Foundation

@objc(ChallengeEntity)
public class ChallengeEntity: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChallengeEntity> {
        NSFetchRequest<ChallengeEntity>(entityName: "ChallengeEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var challengeDescription: String?
    @NSManaged public var maxDailyPoints: Double
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var participants: NSSet?
}

@objc(ParticipantEntity)
public class ParticipantEntity: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ParticipantEntity> {
        NSFetchRequest<ParticipantEntity>(entityName: "ParticipantEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var contactID: String?
    @NSManaged public var isCurrentUser: Bool
    @NSManaged public var accentRed: Double
    @NSManaged public var accentGreen: Double
    @NSManaged public var accentBlue: Double
    @NSManaged public var accentOpacity: Double
    @NSManaged public var accumulatedPoints: Double
    @NSManaged public var challenge: ChallengeEntity?
}

extension ChallengeEntity {
    @objc(addParticipantsObject:)
    @NSManaged public func addToParticipants(_ value: ParticipantEntity)

    var participantArray: [ParticipantEntity] {
        let set = participants as? Set<ParticipantEntity> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    func toChallenge() -> Challenge? {
        guard let id = id,
              let title = title,
              let startDate = startDate,
              let endDate = endDate else {
            return nil
        }

        let participantModels = participantArray.compactMap { $0.toParticipant() }
        return Challenge(
            id: id,
            title: title,
            description: challengeDescription ?? "",
            maxDailyPoints: maxDailyPoints,
            startDate: startDate,
            endDate: endDate,
            participants: participantModels
        )
    }
}

extension ParticipantEntity {
    func toParticipant() -> ChallengeParticipant? {
        guard let id = id,
              let name = name else {
            return nil
        }

        return ChallengeParticipant(
            id: id,
            name: name,
            contactID: contactID,
            isCurrentUser: isCurrentUser,
            accentColor: ColorData(red: accentRed, green: accentGreen, blue: accentBlue, opacity: accentOpacity),
            todaysSnapshot: nil,
            accumulatedPoints: accumulatedPoints
        )
    }
}

extension Challenge {
    func insert(into context: NSManagedObjectContext) {
        let challengeEntity = ChallengeEntity(context: context)
        challengeEntity.id = id
        challengeEntity.title = title
        challengeEntity.challengeDescription = description
        challengeEntity.maxDailyPoints = maxDailyPoints
        challengeEntity.startDate = startDate
        challengeEntity.endDate = endDate

        for participant in participants {
            let participantEntity = ParticipantEntity(context: context)
            participantEntity.id = participant.id
            participantEntity.name = participant.name
            participantEntity.contactID = participant.contactID
            participantEntity.isCurrentUser = participant.isCurrentUser
            participantEntity.accentRed = participant.accentColor.red
            participantEntity.accentGreen = participant.accentColor.green
            participantEntity.accentBlue = participant.accentColor.blue
            participantEntity.accentOpacity = participant.accentColor.opacity
            participantEntity.accumulatedPoints = participant.accumulatedPoints
            challengeEntity.addToParticipants(participantEntity)
        }
    }
}
