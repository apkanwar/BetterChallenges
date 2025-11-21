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
                                CompletedChallengesLeaderboardView(
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
                            CompletedChallengesView(viewModel: viewModel)
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
                    CreateChallengeView(viewModel: viewModel)
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


#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ContentView()
        }
    }
}
#endif
