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
    
    init(startingAs player: Player = .x) {
        self.board = Array(repeating: nil, count: 9)
        self.currentPlayer = .x // X always starts
        self.gameResult = nil
        self.localPlayerRole = player // The device creating the game is this player
    }
    
    init?(queryItems: [URLQueryItem], localRole: Player) {
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
        } else if board.allSatisfy({ $0 != nil }) {
            self.gameResult = "draw"
        } else {
            self.gameResult = nil
        }
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
        } else if board.allSatisfy({ $0 != nil }) {
            self.gameResult = "draw"
        } else {
            self.gameResult = nil
        }
    }
    
    // Convert to URL query items
    func toQueryItems() -> [URLQueryItem] {
        let boardString = board.map { player in
            player?.rawValue ?? "-"
        }.joined()
        
        // Include which player is sending this message (the local player)
        let senderRole = localPlayerRole?.rawValue ?? "X"
        
        return [
            URLQueryItem(name: "board", value: boardString),
            URLQueryItem(name: "sender", value: senderRole)
        ]
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
        } else if board.allSatisfy({ $0 != nil }) {
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
