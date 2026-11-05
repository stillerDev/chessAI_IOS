//
//  ChessGame.swift
//  ChessHint
//
//  Лёгкий генератор ходов на Swift (для интерфейса доски).
//  Полная легальность ходов: рокировка, взятие на проходе, превращение, шах/мат.
//

import Foundation

enum PieceColor: Character, CaseIterable {
    case white = "w"
    case black = "b"

    var opponent: PieceColor { self == .white ? .black : .white }
}

enum PieceType: Character, CaseIterable {
    case pawn = "p", knight = "n", bishop = "b", rook = "r", queen = "q", king = "k"
}

struct Piece: Equatable {
    var color: PieceColor
    var type: PieceType

    var fenChar: Character {
        let base = type.rawValue
        return color == .white ? Character(base.uppercased()) : base
    }

    static func from(fenChar: Character) -> Piece? {
        let isWhite = fenChar.isUppercase
        guard let type = PieceType(rawValue: Character(fenChar.lowercased())) else { return nil }
        return Piece(color: isWhite ? .white : .black, type: type)
    }
}

// Индексы 0..63: 0 = a8, 7 = h8, 56 = a1, 63 = h1 (порядок FEN)
struct Move: Equatable {
    var from: Int
    var to: Int
    var promotion: PieceType? = nil
    var isEnPassant: Bool = false
    var isCastle: Bool = false

    var uci: String {
        let files = "abcdefgh"
        var s = "\(files[from % 8])\(8 - from / 8)\(files[to % 8])\(8 - to / 8)"
        if let p = promotion { s.append(p.rawValue) }
        return s
    }
}

struct ChessGame {
    var squares: [Piece?] = Array(repeating: nil, count: 64)
    var turn: PieceColor = .white
    var castling: String = "KQkq"   // права в FEN-нотации
    var epSquare: Int? = nil        // клетка взятия на проходе
    var halfmoveClock: Int = 0
    var moveNumber: Int = 1

    init(fen: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") {
        _ = load(fen: fen)
    }

    mutating func load(fen: String) -> Bool {
        let parts = fen.split(separator: " ")
        guard parts.count >= 2 else { return false }
        squares = Array(repeating: nil, count: 64)
        var idx = 0
        for ch in parts[0] {
            if ch == "/" { continue }
            if let n = ch.wholeNumberValue {
                idx += n
            } else if let piece = Piece.from(fenChar: ch), idx < 64 {
                squares[idx] = piece
                idx += 1
            }
        }
        guard idx == 64 else { return false }
        turn = parts.count > 1 && parts[1] == "b" ? .black : .white
        castling = parts.count > 2 ? String(parts[2]) : "-"
        if parts.count > 3, parts[3] != "-" {
            let files = Array("abcdefgh")
            let file = files.firstIndex(of: parts[3].first!) ?? 0
            let rank = Int(String(parts[3].last!)) ?? 8
            epSquare = (8 - rank) * 8 + file
        } else {
            epSquare = nil
        }
        halfmoveClock = parts.count > 4 ? Int(parts[4]) ?? 0 : 0
        moveNumber = parts.count > 5 ? Int(parts[5]) ?? 1 : 1
        return true
    }

    func fen() -> String {
        var rows: [String] = []
        for r in 0..<8 {
            var row = ""
            var empty = 0
            for c in 0..<8 {
                if let p = squares[r * 8 + c] {
                    if empty > 0 { row += String(empty); empty = 0 }
                    row.append(p.fenChar)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += String(empty) }
            rows.append(row)
        }
        let ep = epSquare.map { sq -> String in
            let files = Array("abcdefgh")
            return "\(files[sq % 8])\(8 - sq / 8)"
        } ?? "-"
        return "\(rows.joined(separator: "/")) \(turn.rawValue) \(castling) \(ep) \(halfmoveClock) \(moveNumber)"
    }

    func piece(at index: Int) -> Piece? { squares[index] }

    // MARK: - Генерация ходов

    func legalMoves() -> [Move] {
        var result: [Move] = []
        for from in 0..<64 {
            guard let p = squares[from], p.color == turn else { continue }
            pseudoLegalMoves(from: from, piece: p, into: &result)
        }
        return result.filter { isLegal($0) }
    }

    private func pseudoLegalMoves(from: Int, piece: Piece, into moves: inout [Move]) {
        let r = from / 8, c = from % 8
        func sq(_ rr: Int, _ cc: Int) -> Int? {
            (0..<8).contains(rr) && (0..<8).contains(cc) ? rr * 8 + cc : nil
        }
        let enemy = turn.opponent

        switch piece.type {
        case .pawn:
            let dir = turn == .white ? -1 : 1
            let startRank = turn == .white ? 6 : 1
            let promoRank = turn == .white ? 0 : 7
            if let one = sq(r + dir, c), squares[one] == nil {
                addPawnMove(from: from, to: one, promoRank: promoRank, into: &moves)
                if r == startRank, let two = sq(r + 2 * dir, c), squares[two] == nil {
                    moves.append(Move(from: from, to: two))
                }
            }
            for dc in [-1, 1] {
                if let to = sq(r + dir, c + dc) {
                    if let target = squares[to], target.color == enemy {
                        addPawnMove(from: from, to: to, promoRank: promoRank, into: &moves)
                    } else if squares[to] == nil, to == epSquare {
                        moves.append(Move(from: from, to: to, isEnPassant: true))
                    }
                }
            }
        case .knight:
            for (dr, dc) in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] {
                if let to = sq(r + dr, c + dc), squares[to]?.color != turn {
                    moves.append(Move(from: from, to: to))
                }
            }
        case .bishop:
            slide(from: from, dirs: [(-1,-1),(-1,1),(1,-1),(1,1)], into: &moves)
        case .rook:
            slide(from: from, dirs: [(-1,0),(1,0),(0,-1),(0,1)], into: &moves)
        case .queen:
            slide(from: from, dirs: [(-1,-1),(-1,1),(1,-1),(1,1),(-1,0),(1,0),(0,-1),(0,1)], into: &moves)
        case .king:
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr == 0 && dc == 0 { continue }
                    if let to = sq(r + dr, c + dc), squares[to]?.color != turn {
                        moves.append(Move(from: from, to: to))
                    }
                }
            }
            // Рокировка
            let kingSide = turn == .white ? "K" : "k"
            let queenSide = turn == .white ? "Q" : "q"
            let homeRank = turn == .white ? 7 : 0
            if from == homeRank * 8 + 4, squares[from]?.type == .king {
                if castling.contains(kingSide),
                   squares[homeRank * 8 + 5] == nil, squares[homeRank * 8 + 6] == nil,
                   squares[homeRank * 8 + 7]?.type == .rook, squares[homeRank * 8 + 7]?.color == turn,
                   !isSquareAttacked(homeRank * 8 + 4, by: enemy),
                   !isSquareAttacked(homeRank * 8 + 5, by: enemy),
                   !isSquareAttacked(homeRank * 8 + 6, by: enemy) {
                    moves.append(Move(from: from, to: homeRank * 8 + 6, isCastle: true))
                }
                if castling.contains(queenSide),
                   squares[homeRank * 8 + 3] == nil, squares[homeRank * 8 + 2] == nil, squares[homeRank * 8 + 1] == nil,
                   squares[homeRank * 8]?.type == .rook, squares[homeRank * 8]?.color == turn,
                   !isSquareAttacked(homeRank * 8 + 4, by: enemy),
                   !isSquareAttacked(homeRank * 8 + 3, by: enemy),
                   !isSquareAttacked(homeRank * 8 + 2, by: enemy) {
                    moves.append(Move(from: from, to: homeRank * 8 + 2, isCastle: true))
                }
            }
        }
    }

    private func addPawnMove(from: Int, to: Int, promoRank: Int, into moves: inout [Move]) {
        if to / 8 == promoRank {
            for promo in [PieceType.queen, .rook, .bishop, .knight] {
                moves.append(Move(from: from, to: to, promotion: promo))
            }
        } else {
            moves.append(Move(from: from, to: to))
        }
    }

    private func slide(from: Int, dirs: [(Int, Int)], into moves: inout [Move]) {
        let r = from / 8, c = from % 8
        for (dr, dc) in dirs {
            var rr = r + dr, cc = c + dc
            while (0..<8).contains(rr) && (0..<8).contains(cc) {
                let to = rr * 8 + cc
                if let target = squares[to] {
                    if target.color != turn { moves.append(Move(from: from, to: to)) }
                    break
                }
                moves.append(Move(from: from, to: to))
                rr += dr; cc += dc
            }
        }
    }

    private func isLegal(_ move: Move) -> Bool {
        var test = self
        test.makeUnchecked(move)
        let kingIdx = test.squares.firstIndex {
            $0?.type == .king && $0?.color == turn
        } ?? 0
        return !test.isSquareAttacked(kingIdx, by: turn.opponent)
    }

    func isSquareAttacked(_ square: Int, by attacker: PieceColor) -> Bool {
        let r = square / 8, c = square % 8
        func sq(_ rr: Int, _ cc: Int) -> Int? {
            (0..<8).contains(rr) && (0..<8).contains(cc) ? rr * 8 + cc : nil
        }
        // Пешки
        let pr = attacker == .white ? r + 1 : r - 1
        for dc in [-1, 1] {
            if let to = sq(pr, c + dc), let p = squares[to],
               p.color == attacker, p.type == .pawn { return true }
        }
        // Кони
        for (dr, dc) in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] {
            if let to = sq(r + dr, c + dc), let p = squares[to],
               p.color == attacker, p.type == .knight { return true }
        }
        // Король
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                if let to = sq(r + dr, c + dc), let p = squares[to],
                   p.color == attacker, p.type == .king { return true }
            }
        }
        // Слоны/ферзи (диагонали)
        for (dr, dc) in [(-1,-1),(-1,1),(1,-1),(1,1)] {
            var rr = r + dr, cc = c + dc
            while let to = sq(rr, cc) {
                if let p = squares[to] {
                    if p.color == attacker && (p.type == .bishop || p.type == .queen) { return true }
                    break
                }
                rr += dr; cc += dc
            }
        }
        // Ладьи/ферзи (линии)
        for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)] {
            var rr = r + dr, cc = c + dc
            while let to = sq(rr, cc) {
                if let p = squares[to] {
                    if p.color == attacker && (p.type == .rook || p.type == .queen) { return true }
                    break
                }
                rr += dr; cc += dc
            }
        }
        return false
    }

    // MARK: - Выполнение хода

    mutating func make(_ move: Move) {
        makeUnchecked(move)
        if turn == .black { moveNumber += 1 }
        turn = turn.opponent
    }

    private mutating func makeUnchecked(_ move: Move) {
        let piece = squares[move.from]
        let wasCapture = squares[move.to] != nil || move.isEnPassant
        squares[move.from] = nil

        if move.isEnPassant {
            let captured = move.to + (turn == .white ? 8 : -8)
            squares[captured] = nil
        }

        if move.isCastle {
            let homeRank = turn == .white ? 7 : 0
            if move.to == homeRank * 8 + 6 {
                squares[homeRank * 8 + 5] = squares[homeRank * 8 + 7]
                squares[homeRank * 8 + 7] = nil
            } else {
                squares[homeRank * 8 + 3] = squares[homeRank * 8]
                squares[homeRank * 8] = nil
            }
        }

        if var p = piece, let promo = move.promotion {
            p.type = promo
            squares[move.to] = p
        } else {
            squares[move.to] = piece
        }

        // Права на рокировку
        func strip(_ chars: String) {
            for ch in chars { castling.remove(at: castling.firstIndex(of: ch) ?? castling.endIndex) }
            if castling.isEmpty { castling = "-" }
        }
        if move.from == 60 || move.to == 60 { strip("KQ") }
        if move.from == 63 || move.to == 63 { strip("K") }
        if move.from == 56 || move.to == 56 { strip("Q") }
        if move.from == 4 || move.to == 4 { strip("kq") }
        if move.from == 7 || move.to == 7 { strip("k") }
        if move.from == 0 || move.to == 0 { strip("q") }

        // Взятие на проходе
        epSquare = nil
        if let p = piece, p.type == .pawn, abs(move.to - move.from) == 16 {
            epSquare = (move.from + move.to) / 2
        }

        halfmoveClock = (piece?.type == .pawn || wasCapture) ? 0 : halfmoveClock + 1
    }
}
