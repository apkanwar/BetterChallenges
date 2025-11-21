import SwiftUI

struct CompletedChallengesView: View {
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
