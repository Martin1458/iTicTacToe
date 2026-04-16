import SwiftUI

struct GameView: View {
    @Binding var gameState: GameState
    var isProcessingMove: Bool = false
    var pendingPosition: Int? = nil
    var onMove: (Int) -> Void
    var onSend: () -> Void = {}
    var onUndo: () -> Void = {}
    var onCollapse: () -> Void = {}

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 50) {
            // Status / result
            if gameState.gameResult != nil {
                VStack(spacing: 10) {
                    resultText
                        .font(.title3)
                        .fontWeight(.bold)

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
                }
            } else {
                statusText
                    .font(.subheadline)
            }

            // Game board
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<9) { index in
                    let isPending = pendingPosition == index
                    CellView(
                        player: isPending ? gameState.currentPlayer : gameState.board[index],
                        isPending: isPending
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture {
                        if !isProcessingMove && pendingPosition == nil {
                            onMove(index)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: 280)
            .allowsHitTesting(!isProcessingMove && gameState.gameResult == nil)

            // Pending move confirmation buttons
            if pendingPosition != nil {
                HStack(spacing: 16) {
                    Button(action: onUndo) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.vertical, 6)

                    Button(action: onSend) {
                        Label("Send", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.vertical, 6)
                }
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()

            Button(action: onCollapse) {
                Label("Collapse", systemImage: "chevron.down")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 12)
        }
        .animation(.easeInOut(duration: 0.2), value: pendingPosition)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
                if player == gameState.localPlayerRole {
                    Text("You Win!")
                        .foregroundColor(.green)
                } else {
                    Text("You Lost!")
                        .foregroundColor(.red)
                }
            case .draw:
                VStack(spacing: 4) {
                    Text("It's a Draw!")
                        .foregroundColor(.orange)
                    if gameState.isEarlyDraw {
                        Text("No winning moves remain")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            case .inProgress:
                EmptyView()
            }
        }
    }
}

struct CellView: View {
    let player: Player?
    var isPending: Bool = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isPending ? Color.blue.opacity(0.5) : Color.gray, lineWidth: isPending ? 3 : 2)
                )
            
            if let player = player {
                Text(player.rawValue)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(player == .x ? .blue : .red)
                    .opacity(isPending ? 0.4 : 1.0)
            }
        }
    }
}

#Preview {
    @Previewable @State var gameState = GameState()

    NavigationStack {
        GameView(gameState: $gameState, isProcessingMove: false) { position in
            _ = gameState.makeMove(at: position)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
