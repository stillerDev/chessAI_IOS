//
//  StockfishEngine.swift
//  ChessHint
//
//  Асинхронная обёртка над C-мостом Stockfish.
//

import Foundation

struct EngineResult {
    var bestMoveUCI: String
    var scoreCp: Int       // центрипешки (+ лучше для белых)
    var isMate: Bool
    var mateIn: Int        // мат через N ходов
    var depth: Int

    var scoreText: String {
        if isMate {
            return mateIn > 0 ? "Мат #\(mateIn)" : "Мат"
        }
        let pawns = Double(scoreCp) / 100.0
        return String(format: "%+.1f", pawns)
    }
}

final class StockfishEngine: @unchecked Sendable {
    static let shared = StockfishEngine()
    private var initialized = false
    private let lock = NSLock()

    private init() {}

    func initialize() {
        lock.lock()
        defer { lock.unlock() }
        guard !initialized else { return }
        sf_initialize()
        initialized = true
    }

    /// Ищет лучший ход. `moves` — история ходов в UCI-нотации.
    func bestMove(fen: String, moves: [String], depth: Int = 15, movetimeMs: Int = 0) async -> EngineResult? {
        initialize()
        return await withCheckedContinuation { continuation in
            let movesStr = moves.joined(separator: " ")
            let callback: @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, Int32, Int32, Int32) -> Void = { best, _, scoreCp, isMate, mateIn in
                let bestStr = best.map { String(cString: $0) } ?? ""
                let result = EngineResult(
                    bestMoveUCI: bestStr,
                    scoreCp: Int(scoreCp),
                    isMate: isMate != 0,
                    mateIn: Int(mateIn),
                    depth: depth
                )
                continuation.resume(returning: bestStr.isEmpty ? nil : result)
            }
            sf_best_move_async(fen, movesStr, Int32(depth), Int32(movetimeMs), callback)
        }
    }

    func stop() {
        sf_stop_search()
    }
}
