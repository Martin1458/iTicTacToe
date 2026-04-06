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
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<9) { index in
                    CellView(player: gameState.board[index])
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(8)
            .frame(maxWidth: 280)

            Text(statusMessage)
                .font(.headline)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private var statusMessage: String {
        switch gameState.getResult() {
        case .winner(let player):
            return player == gameState.localPlayerRole ? "You won!" : "\(player.rawValue) won!"
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
