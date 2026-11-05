# Chess Hint — сборка и установка (iPhone / iOS)

Приложение на Swift + SwiftUI со встроенным движком **Stockfish 17**.
Нажимаешь «Подсказка» — на доске рисуется синяя стрелка лучшего хода и оценка позиции.

---

## ⚠️ Важно понимать (честно)

1. **Это НЕ мод поверх chess.com.** iOS технически запрещает:
   - рисовать поверх чужих приложений (нет единого окна-оверлея как на Android),
   - читать экран другого приложения в реальном времени,
   - внедрять код в чужой процесс (песочница).

   Поэтому единственная рабочая схема на iPhone — **отдельное приложение-доска**:
   делаешь ходы в chess.com на телефоне → повторяешь их здесь → получаешь стрелку
   лучшего хода. Или качаешь позицию по FEN.

2. **Использование движка в живых партиях на chess.com = читерство.**
   Аккаунт банят, т.к. chess.com детектит совпадения с движком. Используй
   подсказки для разбора своих партий, тренировки и головоломок.

3. **Для сборки нужен Mac с Xcode 15+** (у тебя Windows — Xcode на нём не ставится).
   Бесплатная сборка на своё устройство возможна через бесплатный Apple ID.

---

## Состав проекта

```
ChessHint/
├── project.yml                  # XcodeGen-спецификация
├── ChessHint/
│   ├── App/
│   │   ├── ChessHintApp.swift   # точка входа
│   │   └── ContentView.swift    # главный экран
│   ├── Views/
│   │   └── ChessBoardView.swift # доска, drag&drop, стрелка подсказки
│   ├── Model/
│   │   └── ChessGame.swift      # генерация легальных ходов на Swift
│   └── Engine/
│       ├── StockfishBridge.h    # C-интерфейс (bridging header)
│       ├── StockfishBridge.mm   # обёртка над C++ API Stockfish
│       └── StockfishEngine.swift# async-обёртка для Swift
└── StockfishSrc/                # исходники Stockfish 17 (скопированы)
```

## Сборка через XcodeGen (проще всего)

На Mac:

```bash
brew install xcodegen
cd ChessHint
xcodegen generate          # создаст ChessHint.xcodeproj
open ChessHint.xcodeproj
```

В Xcode: подключи iPhone кабелем → выбери его как destination →
Team: свой Apple ID (Signing & Capabilities) → Run (Cmd+R).

### Структура исходников Stockfish внутри проекта

XcodeGen уже включает `ChessHint/Engine/*` с флагами `-std=c++20 -O2 -DNDEBUG`.
Саму папку `StockfishSrc` добавь в проект так:

- Перетащи папку `StockfishSrc` в навигатор Xcode (File → Add Files),
  **сними галочку** «Copy items if needed»,
- Убедись, что `main.cpp`, `benchmark.cpp` и `ucioption.cpp`-шный `main` НЕ входят
  в target: исключи `main.cpp` из Compile Sources (он конфликтует со SwiftUI-приложением —
  там свой `main()`).
- В Build Settings таргета проверь:
  - `SWIFT_OBJC_BRIDGING_HEADER = ChessHint/Engine/StockfishBridge.h`
  - `CLANG_CXX_LANGUAGE_STANDARD = c++20`
  - `GCC_OPTIMIZATION_LEVEL = 2` (или 3)

NNUE-сеть (весы) встроены в исходники Stockfish 17 — скачивать ничего не нужно,
оценка работает сразу.

## Сборка вручную (без XcodeGen)

1. Xcode → File → New → Project → iOS App, имя `ChessHint`, Interface: SwiftUI.
2. Удали сгенерированный `ContentView.swift`, скопируй папки `App/`, `Views/`, `Model/`, `Engine/`.
3. Перетащи папку `StockfishSrc` в проект, исключи `main.cpp` из компиляции.
4. Build Settings → `SWIFT_OBJC_BRIDGING_HEADER = ChessHint/Engine/StockfishBridge.h`.
5. Build Settings → C++ Language Standard → `C++20`.

## Известные ограничения

- Скорость: ~1–3 секунды на ход при глубине 15 на iPhone (движок в 3–5 раз медленнее
  десктопного — это нормально для NNUE на мобильном CPU).
- Если Xcode ругается на `USE_PTHREADS`/SSE — оставь только `-O2 -std=c++20 -DNDEBUG`
  (AVX-флаги на iOS не нужны, Neon компилятор включит сам через `-DUSE_NEON` при желании:
  добавь `-DUSE_NEON` в compilerFlags для устройства).
- Лицензия: Stockfish — **GPL-3**. Публично выкладывать приложение в App Store можно
  только под GPL с открытым исходным кодом. Для личного использования — без разницы.

## Идеи развития

- Поле «вставить FEN» для анализа любой позиции из chess.com (правый клик → Copy FEN).
- Режим «помощник» — авто-подсказка после каждого твоего хода.
- Импорт PGN партии и построчный разбор с графиком оценки.
