//
//  StockfishBridge.h
//  ChessHint
//
//  C-интерфейс к движку Stockfish 17 (C++). Используется в bridging header.
//

#ifndef StockfishBridge_h
#define StockfishBridge_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Однократная инициализация движка (Bitboards, Position tables, NNUE).
void sf_initialize(void);

/// Асинхронно запускает поиск лучшего хода.
/// Результат приходит через колбэк: bestMoveUci (напр. "e2e4") или "" если ходов нет.
/// Вызывается на внутренней очереди движка — НЕ блокирует вызывающий поток.
void sf_best_move_async(const char *fen,
                        const char *uciMoves,   // ходы через пробел, может быть ""
                        int depth,              // напр. 15 (0 = не ограничивать)
                        int movetimeMs,         // мс на ход (0 = только по depth)
                        void (*callback)(const char *bestMoveUci, const char *ponderUci, int scoreCp, int isMate, int mateIn));

/// Останавливает текущий поиск (если идёт).
void sf_stop_search(void);

#ifdef __cplusplus
}
#endif

#endif /* StockfishBridge_h */
