//
//  ContentView.swift
//  ChessHint
//
//  Главный экран: доска + кнопка подсказки от Stockfish.
//

import SwiftUI

struct ContentView: View {
    @State private var game = ChessGame()
    @State private var history: [(game: ChessGame, move: Move)] = []
    @State private var hintArrow: BoardArrow? = nil
    @State private var hintText: String = "Сделай ход или нажми «Подсказка»"
    @State private var isThinking = false
    @State private var depth = 15
    @State private var pendingPromotion: Move? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text("Chess Hint · Stockfish 17")
                .font(.headline)

            ChessBoardView(
                squares: game.squares,
                legalMoves: game.legalMoves(),
                hintArrow: hintArrow,
                lastMove: history.last?.move,
                onTapSquare: { idx in handleTap(idx) },
                onDrop: { from, to in handleDrop(from: from, to: to) },
                selected: selectedIdx
            )
            .padding(.horizontal)

            Text(hintText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if isThinking {
                ProgressView("Stockfish думает…")
            }

            HStack(spacing: 16) {
                Button {
                    requestHint()
                } label: {
                    Label("Подсказка", systemImage: "lightbulb.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(isThinking)

                Button {
                    undoMove()
                } label: {
                    Label("Назад", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(history.isEmpty)

                Button {
                    newGame()
                } label: {
                    Label("Заново", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Picker("Сила анализа", selection: $depth) {
                Text("Быстро (8)").tag(8)
                Text("Средне (12)").tag(12)
                Text("Сильно (15)").tag(15)
                Text("Максимум (18)").tag(18)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .sheet(item: $pendingPromotion) { move in
            promotionSheet(for: move)
        }
    }

    // MARK: - Логика

    private func handleTap(_ idx: Int) {
        if let sel = selectedPending() {
            // попытка сделать ход
            let candidate = game.legalMoves().filter { $0.from == sel && $0.to == idx }
            if let m = candidate.first {
                commit(m)
                return
            }
        }
        if let p = game.piece(at: idx), p.color == game.turn {
            selectedIdx = idx
        } else {
            selectedIdx = nil
        }
    }

    private func handleDrop(from: Int, to: Int) {
        let candidates = game.legalMoves().filter { $0.from == from && $0.to == to }
        if let m = candidates.first {
            if candidates.count > 1, m.promotion != nil {
                // превращение — показать выбор
                pendingPromotion = m
            } else {
                commit(m)
            }
        }
    }

    @State private var selectedIdx: Int? = nil

    private func selectedPending() -> Int? { selectedIdx }

    private func promotionSheet(for move: Move) -> some View {
        VStack(spacing: 20) {
            Text("Превращение пешки").font(.headline)
            HStack(spacing: 24) {
                ForEach([PieceType.queen, .rook, .bishop, .knight], id: \.self) { t in
                    Button {
                        pendingPromotion = nil
                        var m = move
                        m.promotion = t
                        commit(m)
                    } label: {
                        Text(t.rawValue.uppercased())
                            .font(.title)
                            .frame(width: 60, height: 60)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(30)
        .presentationDetents([.height(180)])
    }

    private func commit(_ move: Move) {
        history.append((game, move))
        game.make(move)
        hintArrow = nil
        selectedIdx = nil
        hintText = "Ход \(move.uci). Сторона: \(game.turn == .white ? "белые" : "чёрные")"
    }

    private func undoMove() {
        guard let last = history.popLast() else { return }
        game = last.game
        hintArrow = nil
        hintText = "Ход отменён"
    }

    private func newGame() {
        game = ChessGame()
        history.removeAll()
        hintArrow = nil
        hintText = "Новая партия"
    }

    private func requestHint() {
        isThinking = true
        hintArrow = nil
        hintText = "Анализирую позицию…"
        let fen = game.fen()
        let moves = history.map { $0.move.uci }
        let d = depth
        Task {
            let result = await StockfishEngine.shared.bestMove(fen: fen, moves: moves, depth: d)
            await MainActor.run {
                isThinking = false
                guard let result else {
                    hintText = "Ходов нет — партия окончена"
                    return
                }
                hintText = "Лучший ход: \(result.bestMoveUCI) · оценка \(result.scoreText) · глубина \(result.depth)"
                hintArrow = BoardArrow(
                    from: squareIndex(uci: result.bestMoveUCI, part: 0),
                    to: squareIndex(uci: result.bestMoveUCI, part: 1)
                )
            }
        }
    }

    private func squareIndex(uci: String, part: Int) -> Int {
        let files = Array("abcdefgh")
        let s = Array(uci)
        let file = files.firstIndex(of: s[part * 2]) ?? 0
        let rank = Int(String(s[part * 2 + 1])) ?? 8
        return (8 - rank) * 8 + file
    }
}

extension Move: Identifiable {
    var id: String { uci }
}
