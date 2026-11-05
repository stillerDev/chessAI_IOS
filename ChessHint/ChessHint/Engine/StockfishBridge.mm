//
//  StockfishBridge.mm
//  ChessHint
//
//  Обёртка над Stockfish 17 (Engine API). Компилируется как Objective-C++.
//

#import "StockfishBridge.h"

#import <dispatch/dispatch.h>

#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "bitboard.h"
#include "engine.h"
#include "misc.h"
#include "position.h"
#include "score.h"
#include "types.h"

namespace {

std::unique_ptr<Stockfish::Engine> g_engine;
std::mutex g_mutex;

} // namespace

void sf_initialize(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_engine) return;

    Stockfish::Bitboards::init();
    Stockfish::Position::init();

    g_engine = std::make_unique<Stockfish::Engine>("");
    g_engine->set_numa_config_from_option("none");
    g_engine->get_options()["Threads"] = std::string("2");
    g_engine->resize_threads();
    g_engine->set_tt_size(16);
    g_engine->load_networks();
    g_engine->verify_networks();
}

void sf_best_move_async(const char *fen,
                        const char *uciMoves,
                        int depth,
                        int movetimeMs,
                        void (*callback)(const char *bestMoveUci,
                                         const char *ponderUci,
                                         int scoreCp, int isMate, int mateIn)) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        std::lock_guard<std::mutex> lock(g_mutex);
        if (!g_engine) { if (callback) callback("", "", 0, 0, 0); return; }

        // Разбор списка ходов UCI
        std::vector<std::string> moves;
        if (uciMoves) {
            std::string all(uciMoves);
            size_t pos = 0;
            while ((pos = all.find(' ')) != std::string::npos) {
                if (pos > 0) moves.push_back(all.substr(0, pos));
                all.erase(0, pos + 1);
            }
            if (!all.empty()) moves.push_back(all);
        }

        // Результат поиска
        std::string bestMove, ponder;
        int scoreCp = 0, isMate = 0, mateIn = 0;

        g_engine->set_on_bestmove([&](std::string_view best, std::string_view ponderMove) {
            bestMove.assign(best);
            ponder.assign(ponderMove);
        });

        g_engine->set_on_update_full([&](const Stockfish::Search::InfoFull &info) {
            info.score.visit([&](auto &&s) {
                using T = std::decay_t<decltype(s)>;
                if constexpr (std::is_same_v<T, Stockfish::Score::InternalUnits>) {
                    scoreCp = s.value;
                    isMate = 0; mateIn = 0;
                } else if constexpr (std::is_same_v<T, Stockfish::Score::Mate>) {
                    int plies = s.plies;
                    isMate = 1;
                    mateIn = (plies + 1) / 2;
                    scoreCp = 0;
                } else if constexpr (std::is_same_v<T, Stockfish::Score::Tablebase>) {
                    isMate = 0;
                    scoreCp = s.win ? 30000 : -30000;
                    mateIn = 0;
                }
            });
        });

        g_engine->set_position(fen ? fen : Stockfish::StartFEN, moves);

        Stockfish::Search::LimitsType limits;
        if (depth > 0)      limits.depth = depth;
        if (movetimeMs > 0) limits.movetime = movetimeMs;
        if (depth <= 0 && movetimeMs <= 0) limits.depth = 15;

        g_engine->go(limits);
        g_engine->wait_for_search_finished();

        if (callback) {
            callback(bestMove.c_str(), ponder.c_str(), scoreCp, isMate, mateIn);
        }
    });
}

void sf_stop_search(void) {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_engine) g_engine->stop();
}
