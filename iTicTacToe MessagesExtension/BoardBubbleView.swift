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
        VStack(spacing: 5) {
            
            // Game board
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<9) { index in
                    CellView(player: gameState.board[index])
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(8)
            
            // Status text
            statusText
                .font(.headline)
                .padding(.bottom, 4)
        }
        .background(Color.red.opacity(0.3))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
    
    private var statusText: some View {
        Text(gameState.isCurrentPlayerTurn() ? "Your turn" : "Waiting for \(gameState.currentPlayer.rawValue)...")
    }
}

#Preview {
    var state = GameState()
    _ = state.makeMove(at: 0)
    _ = state.makeMove(at: 4)
    return BoardBubbleView(gameState: state)
        .frame(width: 160, height: 160) // simulate bubble dimensions
}
