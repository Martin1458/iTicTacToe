import SwiftUI

private let sharedDefaults = UserDefaults(suiteName: "group.com.martin.itictactoe") ?? .standard

struct ContentView: View {
    @AppStorage("myWins", store: sharedDefaults) private var myWins: Int = 0
    @AppStorage("myLosses", store: sharedDefaults) private var myLosses: Int = 0
    @AppStorage("myDraws", store: sharedDefaults) private var myDraws: Int = 0

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Image(systemName: "message.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                Text("iTicTacToe")
                    .font(.largeTitle)
                    .bold()
                Text("Open in Messages to play")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Text("Your stats")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("\(myWins)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.green)
                        Text("Wins")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        Text("\(myDraws)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("Draws")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        Text("\(myLosses)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.red)
                        Text("Losses")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

