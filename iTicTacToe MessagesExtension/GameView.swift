import SwiftUI

struct GameView: View {
    @Binding var gameState: GameState
    var isProcessingMove: Bool = false
    var onMove: (Int) -> Void
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Status text
            statusText
                .font(.headline)
                .padding()
            
            // Game board
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<9) { index in
                    CellView(player: gameState.board[index])
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            // Disable taps while processing a move
                            if !isProcessingMove {
                                onMove(index)
                            }
                        }
                }
            }
            .padding()
            .frame(maxWidth: 280)
            .allowsHitTesting(!isProcessingMove)
            
            // Result message
            if gameState.gameResult != nil {
                resultText
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
    
    private var statusText: some View {
        VStack(spacing: 4) {
            if let myRole = gameState.getCurrentPlayerRole() {
                Text("You are \(myRole.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if gameState.gameResult == nil {
                if gameState.isCurrentPlayerTurn() {
                    Text("Your Turn")
                        .foregroundColor(.green)
                } else {
                    Text("Waiting for \(gameState.currentPlayer.rawValue)...")
                        .foregroundColor(.orange)
                }
            } else {
                Text("Game Over")
            }
        }
    }
    
    private var resultText: some View {
        Group {
            switch gameState.getResult() {
            case .winner(let player):
                Text("\(player.rawValue) Wins!")
                    .foregroundColor(.green)
            case .draw:
                Text("It's a Draw!")
                    .foregroundColor(.orange)
            case .inProgress:
                EmptyView()
            }
        }
    }
}

struct CellView: View {
    let player: Player?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray, lineWidth: 2)
                )
            
            if let player = player {
                Text(player.rawValue)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(player == .x ? .blue : .red)
            }
        }
    }
}

#Preview {
    @Previewable @State var gameState = GameState()
    
    GameView(gameState: $gameState, isProcessingMove: false) { position in
        _ = gameState.makeMove(at: position)
    }
}
