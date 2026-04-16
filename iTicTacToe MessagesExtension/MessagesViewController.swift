import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {

    // MARK: - Lifecycle

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        present(for: conversation, style: presentationStyle)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        guard let conversation = activeConversation else { return }
        present(for: conversation, style: presentationStyle)
    }

    private func present(for conversation: MSConversation, style: MSMessagesAppPresentationStyle) {
        let selectedMessage = conversation.selectedMessage
        let gameState = selectedMessage.flatMap {
            loadGameState(from: $0, conversation: conversation)
        } ?? GameState(startingAs: .x)

        if let message = selectedMessage {
            let isSender = message.senderParticipantIdentifier == conversation.localParticipantIdentifier
            ScoreStore.record(gameState: gameState, message: message, isSender: isSender)
        }

        removeExistingChildViewControllers()

        switch style {
        case .compact, .transcript:
            let hc = UIHostingController(rootView: BoardBubbleView(gameState: gameState) {
                self.requestPresentationStyle(.expanded)
            })
            show(hc)
        case .expanded:
            show(UIHostingController(rootView: GameViewController(
                gameState: gameState,
                onMove: { [weak self] position in
                    self?.handleMove(at: position, conversation: conversation)
                },
                onCollapse: { [weak self] in
                    self?.dismiss()
                }
            )))
        default:
            break
        }
    }

    private func show(_ hostingController: UIHostingController<some View>) {
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    private func removeExistingChildViewControllers() {
        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
    }

    // MARK: - Game Logic

    private func handleMove(at position: Int, conversation: MSConversation) {
        var gameState = conversation.selectedMessage.flatMap {
            loadGameState(from: $0, conversation: conversation)
        } ?? GameState(startingAs: .x)

        guard gameState.makeMove(at: position) else { return }

        sendMessage(with: gameState, conversation: conversation)
    }

    // MARK: - Messaging

    private func loadGameState(from message: MSMessage, conversation: MSConversation) -> GameState? {
        guard let url = message.url,
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let senderString = queryItems.first(where: { $0.name == "sender" })?.value,
              let sender = Player(rawValue: senderString) else { return nil }

        let isSender = message.senderParticipantIdentifier == conversation.localParticipantIdentifier
        let localIdString = conversation.localParticipantIdentifier.uuidString
        let playerXId = queryItems.first(where: { $0.name == "playerXId" })?.value
        let playerOId = queryItems.first(where: { $0.name == "playerOId" })?.value

        // Detect spectators: both player IDs are known and neither matches this device.
        let localRole: Player?
        if let xId = playerXId, let oId = playerOId,
           localIdString != xId && localIdString != oId {
            localRole = nil // spectator
        } else {
            localRole = isSender ? sender : sender.opponent
        }

        // If this message is from the opponent, save their stats locally
        if !isSender && localRole != nil {
            let wins = Int(queryItems.first(where: { $0.name == "senderWins" })?.value ?? "0") ?? 0
            let losses = Int(queryItems.first(where: { $0.name == "senderLosses" })?.value ?? "0") ?? 0
            let draws = Int(queryItems.first(where: { $0.name == "senderDraws" })?.value ?? "0") ?? 0
            ScoreStore.opponentWins = wins
            ScoreStore.opponentLosses = losses
            ScoreStore.opponentDraws = draws
        }

        return GameState(queryItems: queryItems, localRole: localRole)
    }

    private func sendMessage(with gameState: GameState, conversation: MSConversation) {
        // Attach this device's personal stats before sending.
        // If this move just ended the game, include the updated count proactively
        // so the receiver immediately sees the correct opponent score.
        var gameState = gameState
        // If the local player just won, send the already-incremented count
        // so the receiver immediately sees the correct "Them" score.
        // Also update opponentLosses here — this is the only reliable moment
        // on the sender's device where we know the opponent just lost.
        var winsToSend = ScoreStore.myWins
        var drawsToSend = ScoreStore.myDraws
        var receiverLossesToSend = ScoreStore.opponentLosses
        var receiverDrawsToSend = ScoreStore.opponentDraws

        switch gameState.getResult() {
        case .winner(let winner) where winner == gameState.localPlayerRole:
            winsToSend += 1
            receiverLossesToSend += 1
        case .draw:
            drawsToSend += 1
            receiverDrawsToSend += 1
        default:
            break
        }

        gameState.messageSender = gameState.localPlayerRole
        // Stamp this player's participant ID so spectators can be detected later.
        let localIdString = conversation.localParticipantIdentifier.uuidString
        if gameState.localPlayerRole == .x {
            gameState.playerXId = localIdString
        } else if gameState.localPlayerRole == .o {
            gameState.playerOId = localIdString
        }
        gameState.senderWins = winsToSend
        gameState.senderLosses = ScoreStore.myLosses
        gameState.senderDraws = drawsToSend
        gameState.receiverWins = ScoreStore.opponentWins
        gameState.receiverLosses = receiverLossesToSend
        gameState.receiverDraws = receiverDrawsToSend

        var components = URLComponents()
        components.scheme = "https"
        components.host = "tictactoe.game"
        components.path = "/play"
        components.queryItems = gameState.toQueryItems()
        guard let url = components.url else { return }

        let message = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
        message.url = url

        let fallback = MSMessageTemplateLayout()
        fallback.image = generateBoardImage(for: gameState)
        fallback.caption = "Tic Tac Toe"
        fallback.subcaption = gameState.isCurrentPlayerTurn() ? "Your turn" : "Opponent's turn"
        message.layout = MSMessageLiveLayout(alternateLayout: fallback)

        conversation.send(message, completionHandler: nil)
    }

    private func generateBoardImage(for gameState: GameState) -> UIImage? {
        let size = CGSize(width: 300, height: 300)
        let cellSize: CGFloat = 90
        let spacing: CGFloat = 10
        let boardSize: CGFloat = cellSize * 3 + spacing * 2
        let offset = (size.width - boardSize) / 2

        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            for row in 0..<3 {
                for col in 0..<3 {
                    let x = offset + CGFloat(col) * (cellSize + spacing)
                    let y = offset + CGFloat(row) * (cellSize + spacing)
                    let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)

                    UIColor.secondarySystemBackground.setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
                    UIColor.separator.setStroke()
                    let border = UIBezierPath(roundedRect: rect, cornerRadius: 12)
                    border.lineWidth = 2
                    border.stroke()

                    let index = row * 3 + col
                    if let player = gameState.board[index] {
                        let text = player.rawValue
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                            .foregroundColor: player == .x ? UIColor.systemBlue : UIColor.systemRed
                        ]
                        let textSize = (text as NSString).size(withAttributes: attributes)
                        let textRect = CGRect(
                            x: x + (cellSize - textSize.width) / 2,
                            y: y + (cellSize - textSize.height) / 2,
                            width: textSize.width,
                            height: textSize.height
                        )
                        (text as NSString).draw(in: textRect, withAttributes: attributes)
                    }
                }
            }
        }
    }
}

// MARK: - Score Store

enum ScoreStore {
    static let suiteName = "group.com.martin.itictactoe"
    static let defaults: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard

    private static let myWinsKey = "myWins"
    private static let myLossesKey = "myLosses"
    private static let myDrawsKey = "myDraws"
    private static let countedGamesKey = "countedGames"

    static var myWins: Int { defaults.integer(forKey: myWinsKey) }
    static var myLosses: Int { defaults.integer(forKey: myLossesKey) }
    static var myDraws: Int { defaults.integer(forKey: myDrawsKey) }

    static var opponentWins: Int {
        get { defaults.integer(forKey: "opponentWins") }
        set { defaults.set(newValue, forKey: "opponentWins") }
    }
    static var opponentLosses: Int {
        get { defaults.integer(forKey: "opponentLosses") }
        set { defaults.set(newValue, forKey: "opponentLosses") }
    }
    static var opponentDraws: Int {
        get { defaults.integer(forKey: "opponentDraws") }
        set { defaults.set(newValue, forKey: "opponentDraws") }
    }

    /// Records the result of a finished game, ignoring games already counted.
    static func record(gameState: GameState, message: MSMessage, isSender: Bool) {
        guard gameState.gameResult != nil,
              let gameID = message.url?.absoluteString else { return }

        var seen = Set(defaults.stringArray(forKey: countedGamesKey) ?? [])
        guard !seen.contains(gameID) else { return }
        seen.insert(gameID)
        defaults.set(Array(seen), forKey: countedGamesKey)

        switch gameState.getResult() {
        case .winner(let winner):
            if winner == gameState.localPlayerRole {
                defaults.set(myWins + 1, forKey: myWinsKey)
                if isSender { opponentLosses += 1 }
            } else {
                defaults.set(myLosses + 1, forKey: myLossesKey)
            }
        case .draw:
            defaults.set(myDraws + 1, forKey: myDrawsKey)
        case .inProgress:
            break
        }
    }
}

// MARK: - SwiftUI Game View

struct GameViewController: View {
    @State var gameState: GameState
    @State private var isProcessingMove = false
    @State private var pendingPosition: Int? = nil
    var onMove: (Int) -> Void
    var onCollapse: () -> Void = {}

    var body: some View {
        GameView(
            gameState: $gameState,
            isProcessingMove: isProcessingMove,
            pendingPosition: pendingPosition,
            onMove: { position in
                guard !isProcessingMove,
                      pendingPosition == nil,
                      gameState.isCurrentPlayerTurn(),
                      gameState.board[position] == nil,
                      gameState.gameResult == nil else { return }
                pendingPosition = position
            },
            onSend: {
                guard let position = pendingPosition else { return }
                pendingPosition = nil
                isProcessingMove = true
                var updated = gameState
                guard updated.makeMove(at: position) else {
                    isProcessingMove = false
                    return
                }
                gameState = updated
                onMove(position)
                // Keep the expanded view open for an inevitable draw so the
                // user can read the explanation before collapsing manually.
                if !updated.isEarlyDraw {
                    onCollapse()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isProcessingMove = false
                }
            },
            onUndo: {
                pendingPosition = nil
            },
            onCollapse: onCollapse
        )
    }
}
