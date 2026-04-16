//
//  BoardBubbleView.swift
//  iTicTacToe MessagesExtension
//
//  Created by Martin Třasák on 07.03.2026.
//

import SwiftUI

struct BoardBubbleView: View {
    var gameState: GameState
    var onTap: (() -> Void)? = nil

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        Group {
            if gameState.gameResult != nil {
                // Game over
                if gameState.localPlayerRole == nil {
                    // Spectator view
                    VStack(spacing: 10) {
                        Text("You didn't participate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        VStack(spacing: 2) {
                            Text(spectatorResultMessage)
                                .font(.headline)
                            if gameState.isEarlyDraw {
                                Text("No winning moves remain")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 24) {
                            VStack(spacing: 2) {
                                Text("X")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.blue)
                                Text("\(gameState.xWins)W / \(gameState.xDraws)D / \(gameState.xLosses)L")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text("vs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            VStack(spacing: 2) {
                                Text("O")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.red)
                                Text("\(gameState.oWins)W / \(gameState.oDraws)D / \(gameState.oLosses)L")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .padding(.bottom, 4)
                    }
                } else {
                    // Participant view: image + result + scores
                    VStack(spacing: 10) {
                        if let imageName = outcomeImageName {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 80)
                        }

                        VStack(spacing: 2) {
                            Text(statusMessage)
                                .font(.headline)
                            if gameState.isEarlyDraw {
                                Text("No winning moves remain")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 24) {
                            VStack(spacing: 2) {
                                Text("You")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                Text("\(gameState.myWins)W / \(gameState.myDraws)D / \(gameState.myLosses)L")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Text("vs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            VStack(spacing: 2) {
                                Text("Them")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                Text("\(gameState.theirWins)W / \(gameState.theirDraws)D / \(gameState.theirLosses)L")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            } else {
                // In progress: board + status
                VStack(spacing: 8) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(0..<9) { index in
                            CellView(player: gameState.board[index])
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: 280)

                    if gameState.localPlayerRole == nil {
                        Text("You are not playing")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    } else {
                        Text(statusMessage)
                            .font(.headline)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private var outcomeImageName: String? {
        switch gameState.getResult() {
        case .winner(let winner):
            return winner == gameState.localPlayerRole ? "winn" : "defeat"
        case .draw:
            return "draw"
        case .inProgress:
            return nil
        }
    }

    private var spectatorResultMessage: String {
        switch gameState.getResult() {
        case .winner(let player): return "\(player.rawValue) won!"
        case .draw: return "It's a draw!"
        case .inProgress: return ""
        }
    }

    private var statusMessage: String {
        switch gameState.getResult() {
        case .winner(let player):
            return player == gameState.localPlayerRole ? "You won!" : "You lost!"
        case .draw:
            return "It's a draw!"
        case .inProgress:
            return gameState.isCurrentPlayerTurn() ? "Your turn" : "Waiting for \(gameState.currentPlayer.rawValue)..."
        }
    }
}

#Preview {
    var state = GameState()
    _ = state.makeMove(at: 0)
    _ = state.makeMove(at: 4)
    return BoardBubbleView(gameState: state)
        .frame(width: 260, height: 300)
}
