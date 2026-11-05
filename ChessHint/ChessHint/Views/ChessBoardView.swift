//
//  ChessBoardView.swift
//  ChessHint
//
//  Доска + перетаскивание фигур + стрелка подсказки.
//

import SwiftUI

struct BoardArrow {
    var from: Int
    var to: Int
}

struct ChessBoardView: View {
    var squares: [Piece?]
    var legalMoves: [Move]
    var hintArrow: BoardArrow?
    var lastMove: Move?

    var onTapSquare: (Int) -> Void
    var onDrop: (Int, Int) -> Void

    var selected: Int? = nil

    private let files = Array("abcdefgh")
    private let lightColor = Color(red: 0.93, green: 0.89, blue: 0.80)
    private let darkColor = Color(red: 0.55, green: 0.66, blue: 0.55)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 8
            ZStack {
                // Клетки
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { c in
                                let idx = r * 8 + c
                                Rectangle()
                                    .fill((r + c) % 2 == 0 ? lightColor : darkColor)
                                    .overlay {
                                        if idx == selected {
                                            Rectangle().stroke(Color.yellow, lineWidth: 3)
                                        } else if let last = lastMove, last.from == idx || last.to == idx {
                                            Rectangle().fill(Color.yellow.opacity(0.25))
                                        }
                                    }
                            }
                        }
                    }
                }
                .frame(width: size, height: size)

                // Подсветка возможных ходов выбранной фигуры
                if let sel = selected {
                    ForEach(legalMoves.filter { $0.from == sel }, id: \.self) { m in
                        Circle()
                            .fill(Color.green.opacity(0.45))
                            .frame(width: cell * 0.3, height: cell * 0.3)
                            .position(
                                x: CGFloat(m.to % 8) * cell + cell / 2,
                                y: CGFloat(m.to / 8) * cell + cell / 2
                            )
                    }
                }

                // Фигуры (текстовые глифы Unicode)
                ForEach(0..<64, id: \.self) { idx in
                    if let p = squares[idx] {
                        Text(glyph(for: p))
                            .font(.system(size: cell * 0.78))
                            .shadow(color: .black.opacity(0.25), radius: 1, x: 1, y: 1)
                            .frame(width: cell, height: cell)
                            .position(
                                x: CGFloat(idx % 8) * cell + cell / 2,
                                y: CGFloat(idx / 8) * cell + cell / 2
                            )
                            .gesture(
                                DragGesture(minimumDistance: 2)
                                    .onEnded { value in
                                        let startIdx = square(at: value.startLocation, cell: cell)
                                        let endIdx = square(at: value.location, cell: cell)
                                        if let s = startIdx, let e = endIdx, s != e {
                                            selected = nil
                                            onDrop(s, e)
                                        }
                                    }
                            )
                            .onTapGesture { onTapSquare(idx) }
                    }
                }

                // Стрелка подсказки
                if let arrow = hintArrow {
                    ArrowShape(
                        from: CGPoint(x: CGFloat(arrow.from % 8) * cell + cell / 2,
                                      y: CGFloat(arrow.from / 8) * cell + cell / 2),
                        to: CGPoint(x: CGFloat(arrow.to % 8) * cell + cell / 2,
                                    y: CGFloat(arrow.to / 8) * cell + cell / 2),
                        headSize: cell * 0.45
                    )
                    .stroke(Color.blue.opacity(0.85), style: StrokeStyle(lineWidth: cell * 0.12, lineCap: .round))
                    .fill(Color.blue.opacity(0.85))
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func square(at point: CGPoint, cell: CGFloat) -> Int? {
        let c = Int(point.x / cell), r = Int(point.y / cell)
        guard (0..<8).contains(c), (0..<8).contains(r) else { return nil }
        return r * 8 + c
    }

    private func glyph(for p: Piece) -> String {
        let map: [PieceType: [PieceColor: String]] = [
            .king:   [.white: "♔", .black: "♚"],
            .queen:  [.white: "♕", .black: "♛"],
            .rook:   [.white: "♖", .black: "♜"],
            .bishop: [.white: "♗", .black: "♝"],
            .knight: [.white: "♘", .black: "♞"],
            .pawn:   [.white: "♙", .black: "♟"],
        ]
        return map[p.type]?[p.color] ?? "?"
    }
}

private struct ArrowShape: Shape {
    var from: CGPoint
    var to: CGPoint
    var headSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let angle = atan2(to.y - from.y, to.x - from.x)
        let headLen = headSize
        let bodyEnd = CGPoint(x: to.x - cos(angle) * headLen * 0.8,
                              y: to.y - sin(angle) * headLen * 0.8)
        p.move(to: from)
        p.addLine(to: bodyEnd)

        // Наконечник
        let spread: CGFloat = .pi / 7
        let a = CGPoint(x: to.x - cos(angle - spread) * headLen,
                        y: to.y - sin(angle - spread) * headLen)
        let b = CGPoint(x: to.x - cos(angle + spread) * headLen,
                        y: to.y - sin(angle + spread) * headLen)
        p.move(to: a)
        p.addLine(to: to)
        p.addLine(to: b)
        return p
    }
}
