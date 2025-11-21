import Foundation
import SwiftUI

enum PermissionStatus: Equatable {
    case notDetermined
    case granted
    case denied(message: String)

    var message: String? {
        switch self {
        case .denied(let message):
            return message
        default:
            return nil
        }
    }
}

struct RingMetric: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var value: Double
    var goal: Double
    var unitDisplay: String

    var progressFraction: Double {
        guard goal > 0 else { return 0 }
        return value / goal
    }

    var gaugeFraction: Double {
        min(progressFraction, 1.25)
    }

    var percentage: Double {
        min(progressFraction, 1)
    }

    var progressDescription: String {
        "\(Int(value.rounded())) / \(Int(goal.rounded())) \(unitDisplay)"
    }

    var percentagePoints: Double {
        progressFraction * 100
    }
}

struct FitnessRingSnapshot: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var move: RingMetric
    var exercise: RingMetric
    var stand: RingMetric

    var totalPoints: Double {
        move.percentagePoints + exercise.percentagePoints + stand.percentagePoints
    }

    var ringMetrics: [RingMetric] {
        [move, exercise, stand]
    }
}

struct ColorData: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    static func random() -> ColorData {
        let palette: [ColorData] = [
            ColorData(red: 0.98, green: 0.36, blue: 0.35),
            ColorData(red: 0.99, green: 0.64, blue: 0.22),
            ColorData(red: 0.22, green: 0.75, blue: 0.33),
            ColorData(red: 0.27, green: 0.53, blue: 0.97),
            ColorData(red: 0.76, green: 0.37, blue: 0.95),
            ColorData(red: 0.12, green: 0.78, blue: 0.67)
        ]
        return palette.randomElement() ?? palette[0]
    }
}

struct ChallengeParticipant: Identifiable, Hashable {
    let id: UUID
    var name: String
    var contactID: String?
    var isCurrentUser: Bool
    var accentColor: ColorData
    var todaysSnapshot: FitnessRingSnapshot?
    var accumulatedPoints: Double

    var todaysRawPoints: Double {
        todaysSnapshot?.totalPoints ?? 0
    }

    var totalRawPoints: Double {
        accumulatedPoints + todaysRawPoints
    }

    func todaysPoints(maxDailyPoints: Double) -> Double {
        min(todaysRawPoints, maxDailyPoints)
    }

    func totalPoints(maxDailyPoints: Double) -> Double {
        accumulatedPoints + todaysPoints(maxDailyPoints: maxDailyPoints)
    }
}

struct Challenge: Identifiable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var maxDailyPoints: Double
    var startDate: Date
    var endDate: Date
    var participants: [ChallengeParticipant]

    var isActive: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return today >= Calendar.current.startOfDay(for: startDate) && today <= Calendar.current.startOfDay(for: endDate)
    }

    var isCompleted: Bool {
        Calendar.current.startOfDay(for: Date()) > Calendar.current.startOfDay(for: endDate)
    }

    var durationDescription: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate, to: endDate)
    }

    var dayLeaderboard: [ChallengeParticipant] {
        participants.sorted {
            $0.todaysPoints(maxDailyPoints: maxDailyPoints) > $1.todaysPoints(maxDailyPoints: maxDailyPoints)
        }
    }

    var totalLeaderboard: [ChallengeParticipant] {
        participants.sorted {
            $0.totalPoints(maxDailyPoints: maxDailyPoints) > $1.totalPoints(maxDailyPoints: maxDailyPoints)
        }
    }

    mutating func updateParticipant(_ participantID: UUID, snapshot: FitnessRingSnapshot) {
        guard let index = participants.firstIndex(where: { $0.id == participantID }) else { return }
        participants[index].todaysSnapshot = snapshot
    }
}

struct ChallengeContact: Identifiable, Hashable {
    let id: String
    var givenName: String
    var familyName: String
    var phoneNumber: String?
    var email: String?

    var displayName: String {
        let combined = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
        if !combined.isEmpty {
            return combined
        }
        if let phoneNumber {
            return phoneNumber
        }
        if let email {
            return email
        }
        return "Unknown contact"
    }

    var initials: String {
        let names = [givenName, familyName].filter { !$0.isEmpty }
        let initials = names.map { String($0.prefix(1)) }.joined()
        if !initials.isEmpty {
            return initials.uppercased()
        }
        if let phoneNumber {
            return String(phoneNumber.prefix(2))
        }
        if let email {
            return String(email.prefix(2))
        }
        return "??"
    }
}

extension ChallengeContact {
    func makeParticipant(color: ColorData = .random()) -> ChallengeParticipant {
        ChallengeParticipant(
            id: UUID(),
            name: displayName,
            contactID: id,
            isCurrentUser: false,
            accentColor: color,
            todaysSnapshot: nil,
            accumulatedPoints: Double.random(in: 1200...4500)
        )
    }
}

extension Challenge {
    static func sampleData(currentParticipantID: UUID) -> [Challenge] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"

        let today = Date()
        let calendar = Calendar.current

        let group1Participants: [ChallengeParticipant] = [
            ChallengeParticipant(
                id: currentParticipantID,
                name: "You",
                contactID: nil,
                isCurrentUser: true,
                accentColor: ColorData(red: 0.98, green: 0.36, blue: 0.35),
                todaysSnapshot: nil,
                accumulatedPoints: 2200
            ),
            ChallengeParticipant(
                id: UUID(),
                name: "Camila",
                contactID: UUID().uuidString,
                isCurrentUser: false,
                accentColor: ColorData(red: 0.22, green: 0.75, blue: 0.33),
                todaysSnapshot: nil,
                accumulatedPoints: 2600
            ),
            ChallengeParticipant(
                id: UUID(),
                name: "Jordan",
                contactID: UUID().uuidString,
                isCurrentUser: false,
                accentColor: ColorData(red: 0.27, green: 0.53, blue: 0.97),
                todaysSnapshot: nil,
                accumulatedPoints: 2400
            )
        ]

        let group2Participants: [ChallengeParticipant] = [
            ChallengeParticipant(
                id: currentParticipantID,
                name: "You",
                contactID: nil,
                isCurrentUser: true,
                accentColor: ColorData(red: 0.98, green: 0.36, blue: 0.35),
                todaysSnapshot: nil,
                accumulatedPoints: 1800
            ),
            ChallengeParticipant(
                id: UUID(),
                name: "Chris",
                contactID: UUID().uuidString,
                isCurrentUser: false,
                accentColor: ColorData(red: 0.99, green: 0.64, blue: 0.22),
                todaysSnapshot: nil,
                accumulatedPoints: 2100
            ),
            ChallengeParticipant(
                id: UUID(),
                name: "Sam",
                contactID: UUID().uuidString,
                isCurrentUser: false,
                accentColor: ColorData(red: 0.76, green: 0.37, blue: 0.95),
                todaysSnapshot: nil,
                accumulatedPoints: 2050
            ),
            ChallengeParticipant(
                id: UUID(),
                name: "Priya",
                contactID: UUID().uuidString,
                isCurrentUser: false,
                accentColor: ColorData(red: 0.12, green: 0.78, blue: 0.67),
                todaysSnapshot: nil,
                accumulatedPoints: 2300
            )
        ]

        let firstChallenge = Challenge(
            id: UUID(),
            title: "Friendsgiving Burn",
            description: "Close your rings every day leading up to the big feast.",
            maxDailyPoints: 800,
            startDate: calendar.date(byAdding: .day, value: -21, to: today) ?? today,
            endDate: calendar.date(byAdding: .day, value: -10, to: today) ?? today,
            participants: group1Participants
        )

        let secondChallenge = Challenge(
            id: UUID(),
            title: "Morning Crew",
            description: "30-minute workouts before 9AM. Beat your team!",
            maxDailyPoints: 600,
            startDate: calendar.date(byAdding: .day, value: -40, to: today) ?? today,
            endDate: calendar.date(byAdding: .day, value: -28, to: today) ?? today,
            participants: group2Participants
        )

        return [firstChallenge, secondChallenge]
    }
}
