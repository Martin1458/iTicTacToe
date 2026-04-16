import Foundation

enum Player: String, Codable {
    case x = "X"
    case o = "O"
    
    var opponent: Player {
        return self == .x ? .o : .x
    }
}

enum GameResult {
    case winner(Player)
    case draw
    case inProgress
}

struct GameState: Codable {
    // Board represented as array of 9 positions (0-8)
    // nil = empty, .x = X player, .o = O player
    var board: [Player?]
    var currentPlayer: Player
    var gameResult: String? // "X", "O", "draw", or nil for in progress
    var localPlayerRole: Player? // Which player this device is (X or O)
    var messageSender: Player? // Which player (X or O) sent this message
    var senderWins: Int = 0
    var senderLosses: Int = 0
    var senderDraws: Int = 0
    var receiverWins: Int = 0
    var receiverLosses: Int = 0
    var receiverDraws: Int = 0
    var playerXId: String? // Participant ID of the player using X
    var playerOId: String? // Participant ID of the player using O

    // Perspective-aware stat accessors: correct regardless of whether
    // you are viewing a message you sent or received.
    var myWins: Int {
        guard let local = localPlayerRole, let sender = messageSender else { return 0 }
        return local == sender ? senderWins : receiverWins
    }
    var myLosses: Int {
        guard let local = localPlayerRole, let sender = messageSender else { return 0 }
        return local == sender ? senderLosses : receiverLosses
    }
    var myDraws: Int {
        guard let local = localPlayerRole, let sender = messageSender else { return 0 }
        return local == sender ? senderDraws : receiverDraws
    }
    var theirWins: Int {
        guard let local = localPlayerRole, let sender = messageSender else { return 0 }
        return local == sender ? receiverWins : senderWins
    }
    var theirLosses: Int {
        guard let local = localPlayerRole, let sender = messageSender else { return 0 }
        return local == sender ? receiverLosses : senderLosses
    }
    var theirDraws: Int {
        guard let local = localPlayerRole, let sender = messageSender else { return 0 }
        return local == sender ? receiverDraws : senderDraws
    }

    // Absolute stat accessors by role — used in spectator view.
    private var xIsSender: Bool { messageSender == .x }
    var xWins: Int   { xIsSender ? senderWins   : receiverWins   }
    var xLosses: Int { xIsSender ? senderLosses : receiverLosses }
    var xDraws: Int  { xIsSender ? senderDraws  : receiverDraws  }
    var oWins: Int   { xIsSender ? receiverWins   : senderWins   }
    var oLosses: Int { xIsSender ? receiverLosses : senderLosses }
    var oDraws: Int  { xIsSender ? receiverDraws  : senderDraws  }

    init(startingAs player: Player = .x) {
        self.board = Array(repeating: nil, count: 9)
        self.currentPlayer = .x // X always starts
        self.gameResult = nil
        self.localPlayerRole = player // The device creating the game is this player
    }
    
    init?(queryItems: [URLQueryItem], localRole: Player?) {
        guard let boardString = queryItems.first(where: { $0.name == "board" })?.value,
              boardString.count == 9 else { return nil }

        self.board = boardString.map { char in
            switch char {
            case "X": return .x
            case "O": return .o
            default: return nil
            }
        }

        self.localPlayerRole = localRole

        let xCount = board.filter { $0 == .x }.count
        let oCount = board.filter { $0 == .o }.count
        self.currentPlayer = xCount == oCount ? .x : .o

        if let winner = Self.checkWinner(board) {
            self.gameResult = winner.rawValue
        } else if board.allSatisfy({ $0 != nil }) || Self.isInevitableDraw(board) {
            self.gameResult = "draw"
        } else {
            self.gameResult = nil
        }

        self.messageSender = Player(rawValue: queryItems.first(where: { $0.name == "sender" })?.value ?? "")
        self.senderWins = Int(queryItems.first(where: { $0.name == "senderWins" })?.value ?? "0") ?? 0
        self.senderLosses = Int(queryItems.first(where: { $0.name == "senderLosses" })?.value ?? "0") ?? 0
        self.senderDraws = Int(queryItems.first(where: { $0.name == "senderDraws" })?.value ?? "0") ?? 0
        self.receiverWins = Int(queryItems.first(where: { $0.name == "receiverWins" })?.value ?? "0") ?? 0
        self.receiverLosses = Int(queryItems.first(where: { $0.name == "receiverLosses" })?.value ?? "0") ?? 0
        self.receiverDraws = Int(queryItems.first(where: { $0.name == "receiverDraws" })?.value ?? "0") ?? 0
        self.playerXId = queryItems.first(where: { $0.name == "playerXId" })?.value
        self.playerOId = queryItems.first(where: { $0.name == "playerOId" })?.value
    }

    // Initialize from URL query parameters
    // When receiving a message, the local player is the OPPONENT of who sent it
    init?(queryItems: [URLQueryItem], asOpponentOf sender: Player) {
        guard let boardString = queryItems.first(where: { $0.name == "board" })?.value,
              boardString.count == 9 else {
            return nil
        }
        
        // Parse board string (9 characters: X, O, or -)
        self.board = boardString.map { char in
            switch char {
            case "X": return .x
            case "O": return .o
            default: return nil
            }
        }
        
        // The sender is one player, so we are the opponent
        self.localPlayerRole = sender.opponent
        
        // Determine current player based on move count
        let xCount = board.filter { $0 == .x }.count
        let oCount = board.filter { $0 == .o }.count
        self.currentPlayer = xCount == oCount ? .x : .o
        
        // Check game result
        if let winner = Self.checkWinner(board) {
            self.gameResult = winner.rawValue
        } else if board.allSatisfy({ $0 != nil }) || Self.isInevitableDraw(board) {
            self.gameResult = "draw"
        } else {
            self.gameResult = nil
        }

        self.messageSender = sender
        self.senderWins = Int(queryItems.first(where: { $0.name == "senderWins" })?.value ?? "0") ?? 0
        self.senderLosses = Int(queryItems.first(where: { $0.name == "senderLosses" })?.value ?? "0") ?? 0
        self.senderDraws = Int(queryItems.first(where: { $0.name == "senderDraws" })?.value ?? "0") ?? 0
        self.receiverWins = Int(queryItems.first(where: { $0.name == "receiverWins" })?.value ?? "0") ?? 0
        self.receiverLosses = Int(queryItems.first(where: { $0.name == "receiverLosses" })?.value ?? "0") ?? 0
        self.receiverDraws = Int(queryItems.first(where: { $0.name == "receiverDraws" })?.value ?? "0") ?? 0
    }
    
    // Convert to URL query items
    func toQueryItems() -> [URLQueryItem] {
        let boardString = board.map { player in
            player?.rawValue ?? "-"
        }.joined()
        
        // Include which player is sending this message (the local player)
        let senderRole = localPlayerRole?.rawValue ?? "X"
        
        var items: [URLQueryItem] = [
            URLQueryItem(name: "board", value: boardString),
            URLQueryItem(name: "sender", value: senderRole),
            URLQueryItem(name: "senderWins", value: String(senderWins)),
            URLQueryItem(name: "senderLosses", value: String(senderLosses)),
            URLQueryItem(name: "senderDraws", value: String(senderDraws)),
            URLQueryItem(name: "receiverWins", value: String(receiverWins)),
            URLQueryItem(name: "receiverLosses", value: String(receiverLosses)),
            URLQueryItem(name: "receiverDraws", value: String(receiverDraws))
        ]
        if let xId = playerXId { items.append(URLQueryItem(name: "playerXId", value: xId)) }
        if let oId = playerOId { items.append(URLQueryItem(name: "playerOId", value: oId)) }
        return items
    }
    
    // Make a move at the given position
    mutating func makeMove(at position: Int) -> Bool {
        guard position >= 0 && position < 9,
              board[position] == nil,
              gameResult == nil else {
            return false
        }
        
        board[position] = currentPlayer
        
        // Check for winner
        if let winner = Self.checkWinner(board) {
            gameResult = winner.rawValue
        } else if board.allSatisfy({ $0 != nil }) || Self.isInevitableDraw(board) {
            gameResult = "draw"
        } else {
            currentPlayer = currentPlayer.opponent
        }
        
        return true
    }
    
    // Get the player role for the current device
    func getCurrentPlayerRole() -> Player? {
        return localPlayerRole
    }
    
    // Check if it's the current device's turn
    func isCurrentPlayerTurn() -> Bool {
        return localPlayerRole == currentPlayer
    }
    
    // Check if there's a winner
    static func checkWinner(_ board: [Player?]) -> Player? {
        let winPatterns: [[Int]] = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8], // Rows
            [0, 3, 6], [1, 4, 7], [2, 5, 8], // Columns
            [0, 4, 8], [2, 4, 6]             // Diagonals
        ]
        
        for pattern in winPatterns {
            let positions = pattern.map { board[$0] }
            if let first = positions[0],
               positions.allSatisfy({ $0 == first }) {
                return first
            }
        }
        
        return nil
    }

    // Returns true when every winning line contains both X and O,
    // meaning neither player can ever win regardless of remaining moves.
    static func isInevitableDraw(_ board: [Player?]) -> Bool {
        let winPatterns: [[Int]] = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]
        return winPatterns.allSatisfy { pattern in
            let cells = pattern.map { board[$0] }
            return cells.contains(.x) && cells.contains(.o)
        }
    }

    // True when the game ended as a draw before the board was full.
    var isEarlyDraw: Bool {
        gameResult == "draw" && board.contains(where: { $0 == nil })
    }
    
    func getResult() -> GameResult {
        if let result = gameResult {
            if result == "draw" {
                return .draw
            } else if result == "X" {
                return .winner(.x)
            } else {
                return .winner(.o)
            }
        }
        return .inProgress
    }
}
