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
        let gameState = conversation.selectedMessage.flatMap {
            loadGameState(from: $0, conversation: conversation)
        } ?? GameState(startingAs: .x)

        removeExistingChildViewControllers()

        switch style {
        case .compact, .transcript:
            let hc = UIHostingController(rootView: BoardBubbleView(gameState: gameState) {
                self.requestPresentationStyle(.expanded)
            })
            show(hc)
        case .expanded:
            show(UIHostingController(rootView: GameViewController(gameState: gameState) { [weak self] position in
                self?.handleMove(at: position, conversation: conversation)
            }))
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
        let localRole: Player = isSender ? sender : sender.opponent
        return GameState(queryItems: queryItems, localRole: localRole)
    }

    private func sendMessage(with gameState: GameState, conversation: MSConversation) {
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

        conversation.insert(message)
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

// MARK: - SwiftUI Game View

struct GameViewController: View {
    @State var gameState: GameState
    @State private var isProcessingMove = false
    var onMove: (Int) -> Void

    var body: some View {
        GameView(gameState: $gameState, isProcessingMove: isProcessingMove) { position in
            guard !isProcessingMove, gameState.isCurrentPlayerTurn() else { return }
            guard position >= 0 && position < 9,
                  gameState.board[position] == nil,
                  gameState.gameResult == nil else { return }

            isProcessingMove = true
            var updated = gameState
            guard updated.makeMove(at: position) else {
                isProcessingMove = false
                return
            }
            gameState = updated
            onMove(position)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isProcessingMove = false
            }
        }
    }
}
