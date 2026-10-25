import SwiftUI
import Combine

enum SelectionType: Hashable {
    case flag
    case box(row: Int, col: Int)
}

// Represents an animatable piece on the board
struct MovingPiece: Identifiable, Hashable{
    let id: String       // stable identity: "flag" or "box-r-c" based on initial position
    var row: Int
    var col: Int
    var type: TileType   // .flag or .box
    var isSelected: Bool
}

// Snapshot of all mutable game state, used for undo
private struct GameSnapshot: Hashable {
    let grid: [[Int]]
    let pieces: [MovingPiece]
    let flagRow: Int
    let flagCol: Int
    let steps: Int
    let selectedItem: SelectionType?
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.grid == rhs.grid
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(grid)
    }
    func copy() -> GameSnapshot {
        return GameSnapshot(grid: grid, pieces: pieces, flagRow: flagRow, flagCol: flagCol, steps: steps, selectedItem: selectedItem)
    }
}

class GameViewModel: ObservableObject {
    @Published var currentLevel: Level
    @Published var grid: [[Int]]           // Used only for background cell rendering
    @Published var pieces: [MovingPiece]   // Animatable piece overlays
    @Published var steps: Int = 0
    @Published var isGameOver: Bool = false
    @Published var isWin: Bool = false
    @Published var isPerfectWin: Bool = false // Whether the player solved it in the minimum number of steps
    @Published var isTesting: Bool = false

    @Published var selectedItem: SelectionType? = nil

    private var flagRow: Int
    private var flagCol: Int

    // History stack for undo support
    private var snapshots: [GameSnapshot] = []

    var canUndo: Bool { !snapshots.isEmpty }

    init(level: Level) {
        self.currentLevel = level
        self.grid = level.grid
        self.flagRow = level.startPos.row
        self.flagCol = level.startPos.col
        self.pieces = GameViewModel.buildPieces(from: level.grid)
        if level.checkOptimal {
            self.currentLevel.minSteps = findOptimal(maxSteps: 10)
        }
        if level.generateEasy {
            generateEasyLevelCaller()
        }
        if level.generateMedium {
            generateMediumLevelCaller()
        }
    }

    // MARK: - Easy level generation

    func generateEasyLevelCaller() {
        var activated = false
        while true {
            if generateEasyLevel() {
                print("Easy level activated: ", activated)
                break
            }
            activated = true
        }
    }

    func generateEasyLevel() -> Bool {
        grid = [
            [-1, -1, -1, -1, -1, -1, -1, -1],
            [-1, -1, -1, -1, -1, -1, -1, -1],
            [-1, -1, -1, -1, -1, -1, -1, -1],
            [-1, -1, -1, -1, -1, -1, -1, -1],
            [-1, -1, -1, -1, -1, -1, -1, -1],
            [-1, -1, -1, -1, -1, -1, -1, -1],
            [-1, -1, -1, -1, -1, -1, -1, -1],
            [-1, -1, -1, -1, -1, -1, -1, -1]
        ]
        flagRow = Int.random(in: 0..<grid.count)
        flagCol = Int.random(in: 0..<grid[0].count)
        grid[flagRow][flagCol] = TileType.flag.rawValue
        var path: [[Int]] = [[flagRow, flagCol]]
        var pointer: [Int] = [flagRow, flagCol]
        var direction = MoveDirection.allCases[Int.random(in: 0...3)]
        var previousDirection: MoveDirection? = nil
        var steps = Int.random(in: 4...7)
        var currentStep = 0
        var loops = 0
        for line in grid { print(line) }
        print(pointer, "\n")
        while currentStep < steps {
            var repeats = 0
            let pointerReset = pointer
            let gridReset = grid
            repeat {
                repeats = -1
                pointer = pointerReset
                grid = gridReset
                let delta = Int.random(in: 1..<6)
                for _ in 0...delta where !isOutOfBounds(row: pointer[0] + 2 * getDirectionDelta(direction).0, col: pointer[1] + 2 * getDirectionDelta(direction).1) {
                    pointer[0] += getDirectionDelta(direction).0
                    pointer[1] += getDirectionDelta(direction).1
                    if grid[pointer[0]][pointer[1]] > 0 {
                        repeats = -1
                        break
                    } else {
                        grid[pointer[0]][pointer[1]] = 0
                    }
                    repeats += 1
                    for line in grid { print(line) }
                    print(pointer, ", ", repeats, ", ", previousDirection ?? "nil", "\n")
                }
                if repeats < 0 || grid[pointer[0] + getDirectionDelta(direction).0][pointer[1] + getDirectionDelta(direction).1] == 2 {
                    loops += 1
                    if loops > 10 { return false }
                    var newDirection = direction
                    repeat {
                        newDirection = MoveDirection.allCases[Int.random(in: 0...3)]
                    } while newDirection == previousDirection || newDirection == oppositeDirection(direction: previousDirection)
                    print(direction, ", ", newDirection)
                    direction = newDirection
                }
            } while repeats < 0

            if grid[pointer[0] + getDirectionDelta(direction).0][pointer[1] + getDirectionDelta(direction).1] == 0 ||
               grid[pointer[0] + getDirectionDelta(direction).0][pointer[1] + getDirectionDelta(direction).1] == 2 {
                pointer = pointerReset
                grid = gridReset
                loops += 1
                if loops < 10 { continue } else { steps = currentStep; break }
            } else {
                grid[pointer[0] + getDirectionDelta(direction).0][pointer[1] + getDirectionDelta(direction).1] = TileType.box.rawValue
            }
            loops = 0
            path.append(pointer)
            previousDirection = direction
            var newDirection = direction
            repeat {
                newDirection = MoveDirection.allCases[Int.random(in: 0...3)]
            } while newDirection == direction || newDirection == oppositeDirection(direction: direction)
            direction = newDirection
            for line in grid { print(line) }
            print(pointer)
            print("\n")
            currentStep += 1
        }
        while grid[pointer[0]][pointer[1]] == 1 || grid[pointer[0]][pointer[1]] == 2 {
            pointer[0] -= getDirectionDelta(direction).0
            pointer[1] -= getDirectionDelta(direction).1
        }
        grid[pointer[0]][pointer[1]] = TileType.target.rawValue
        for row in 0..<grid.count {
            for col in 0..<grid[row].count {
                if grid[row][col] == -1 { grid[row][col] = 0 }
            }
        }
        currentLevel = Level(id: currentLevel.id, name: currentLevel.name, grid: grid,
                             startPos: (row: path[0][0], col: path[0][1]),
                             targetPos: (row: pointer[0], col: pointer[1]),
                             minSteps: steps, checkOptimal: false,
                             generateEasy: true, generateMedium: false)
        pieces = GameViewModel.buildPieces(from: grid)
        let optimal = findOptimal(maxSteps: steps)
        if optimal == -1 {
            return false
        }
        if optimal < steps {
            currentLevel.minSteps = optimal
        }
        return true
    }

    // MARK: - Medium level generation

    func generateMediumLevelCaller() {
        while true {
            if generateMediumLevel() { break }
        }
    }

    // Generates a puzzle where the optimal solution is 6–10 steps and requires
    // moving at least 3 distinct boxes. Uses BFS that tracks which boxes have
    // been moved so the box-count constraint can be enforced exactly.
    func generateMediumLevel() -> Bool {
        let size = 8
        var g = Array(repeating: Array(repeating: 0, count: size), count: size)

        var occupied = Set<Int>()
        func randomCell() -> (Int, Int)? {
            for _ in 0..<200 {
                let r = Int.random(in: 0..<size)
                let c = Int.random(in: 0..<size)
                if occupied.insert(r * size + c).inserted { return (r, c) }
            }
            return nil
        }

        guard let (fr, fc) = randomCell() else { return false }
        guard let (tr, tc) = randomCell() else { return false }
        guard fr != tr && fc != tc else { return false }

        g[fr][fc] = TileType.flag.rawValue
        g[tr][tc] = TileType.target.rawValue

        // Place 5–8 boxes — more boxes give BFS more options to reach 3+ box moves
        let boxCount = Int.random(in: 5...8)
        for _ in 0..<boxCount {
            guard let (br, bc) = randomCell() else { return false }
            g[br][bc] = TileType.box.rawValue
        }

        // Temporarily apply the grid so the BFS helper can read self.grid / flagRow / flagCol
        let savedGrid    = grid
        let savedFlagRow = flagRow
        let savedFlagCol = flagCol
        let savedLevel   = currentLevel

        grid    = g
        flagRow = fr
        flagCol = fc
        currentLevel = Level(id: currentLevel.id, name: currentLevel.name, grid: g,
                             startPos: (row: fr, col: fc),
                             targetPos: (row: tr, col: tc),
                             minSteps: -1, checkOptimal: false,
                             generateEasy: false, generateMedium: true)

        let result = findOptimalMedium(minSteps: 6, maxSteps: 10, minBoxesMoved: 3)

        guard result >= 6 else {
            // Restore state and reject
            grid        = savedGrid
            flagRow     = savedFlagRow
            flagCol     = savedFlagCol
            currentLevel = savedLevel
            return false
        }

        currentLevel = Level(id: currentLevel.id, name: currentLevel.name, grid: g,
                             startPos: (row: fr, col: fc),
                             targetPos: (row: tr, col: tc),
                             minSteps: result, checkOptimal: false,
                             generateEasy: false, generateMedium: true)
        grid   = g
        pieces = GameViewModel.buildPieces(from: g)
        print("[generateMediumLevel] Generated puzzle with optimal = \(result) steps")
        return true
    }

    // BFS variant for medium-level generation.
    // The node state includes a bitmask of which original box cell-indices have
    // been moved at least once, so we can enforce a minimum distinct-box count.
    // Returns the depth of the shallowest solution that satisfies both constraints,
    // or -1 if none is found within maxSteps.
    private func findOptimalMedium(minSteps: Int, maxSteps: Int, minBoxesMoved: Int) -> Int {
        let startTime = Date()

        let rows      = grid.count
        let cols      = grid[0].count
        let target    = currentLevel.targetPos
        let targetIdx = target.row * cols + target.col

        let flagRaw  = TileType.flag.rawValue
        let boxRaw   = TileType.box.rawValue
        let emptyRaw = TileType.empty.rawValue

        let deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        // Extended node: bitboard + flag index + bitmask of original box cells moved.
        // We use a UInt64 bitmask over the 64 cell indices — one bit per cell that
        // held a box in the initial state and has been slid at least once.
        struct MediumNode: Hashable {
            var state:      BFSState
            var flagIdx:    Int
            var boxesMoved: UInt64  // bit i set → cell i was an initial box that got moved
        }

        // Record original box positions as a bitmask for fast bit-setting later
        let initialState = packGrid()
        let initialBoxMask: UInt64 = {
            var mask: UInt64 = 0
            for idx in initialState.boxIndices() { mask |= (1 << idx) }
            return mask
        }()

        let initial  = MediumNode(state: initialState,
                                  flagIdx: flagRow * cols + flagCol,
                                  boxesMoved: 0)
        var frontier = [initial]
        var visited  = [MediumNode: Int]()   // node → first depth seen
        visited[initial] = 0

        let bestResult = -1

        for step in 1...maxSteps {
            var next = [MediumNode]()
            next.reserveCapacity(frontier.count * 4)

            for node in frontier {
                let st    = node.state
                let fIdx  = node.flagIdx
                let fRow  = fIdx / cols
                let fCol  = fIdx % cols
                let boxes = st.boxIndices()

                for (dRow, dCol) in deltas {

                    // ── Move flag ──────────────────────────────────────────
                    var tRow = fRow, tCol = fCol, hitBox = false
                    while true {
                        let nRow = tRow + dRow; let nCol = tCol + dCol
                        if nRow < 0 || nRow >= rows || nCol < 0 || nCol >= cols { break }
                        if st.tile(at: nRow * cols + nCol) == boxRaw { hitBox = true; break }
                        tRow = nRow; tCol = nCol
                    }
                    if hitBox && !(tRow == fRow && tCol == fCol) {
                        let newFIdx = tRow * cols + tCol
                        let newSt   = st.setting(index: fIdx,    to: emptyRaw)
                                        .setting(index: newFIdx, to: flagRaw)
                        if newFIdx == targetIdx {
                            // Win — check both constraints
                            let boxCount = node.boxesMoved.nonzeroBitCount
                            if step >= minSteps && boxCount >= minBoxesMoved {
                                let elapsed = Date().timeIntervalSince(startTime)
                                print("[findOptimalMedium] Found in \(step) step(s), \(boxCount) boxes moved. Time: \(String(format: "%.4f", elapsed))s")
                                return step
                            }
                            // Doesn't satisfy constraints — don't propagate this path
                            continue
                        }
                        let newNode = MediumNode(state: newSt, flagIdx: newFIdx,
                                                 boxesMoved: node.boxesMoved)
                        if visited[newNode] == nil {
                            visited[newNode] = step
                            next.append(newNode)
                        }
                    }

                    // ── Move each box ──────────────────────────────────────
                    for bIdx in boxes {
                        let r = bIdx / cols, c = bIdx % cols
                        var btRow = r, btCol = c, hitObstacle = false
                        while true {
                            let nRow = btRow + dRow; let nCol = btCol + dCol
                            if nRow < 0 || nRow >= rows || nCol < 0 || nCol >= cols { break }
                            let t = st.tile(at: nRow * cols + nCol)
                            if t == boxRaw || t == flagRaw { hitObstacle = true; break }
                            btRow = nRow; btCol = nCol
                        }
                        let newBIdx = btRow * cols + btCol
                        guard newBIdx != bIdx else { continue }

                        // Mark this original box cell as moved if it was in the initial layout
                        let newBoxesMoved = node.boxesMoved | (initialBoxMask & (1 << bIdx))

                        if !hitObstacle {
                            let nRow = btRow + dRow; let nCol = btCol + dCol
                            if nRow < 0 || nRow >= rows || nCol < 0 || nCol >= cols {
                                let newNode = MediumNode(state: st.setting(index: bIdx, to: emptyRaw),
                                                         flagIdx: fIdx,
                                                         boxesMoved: newBoxesMoved)
                                if visited[newNode] == nil {
                                    visited[newNode] = step
                                    next.append(newNode)
                                }
                                continue
                            }
                        }
                        let newNode = MediumNode(state: st.setting(index: bIdx,    to: emptyRaw)
                                                          .setting(index: newBIdx, to: boxRaw),
                                                  flagIdx: fIdx,
                                                  boxesMoved: newBoxesMoved)
                        if visited[newNode] == nil {
                            visited[newNode] = step
                            next.append(newNode)
                        }
                    }
                }
            }

            if next.isEmpty { break }
            frontier = next
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("[findOptimalMedium] No qualifying solution found within \(maxSteps) step(s). Time: \(String(format: "%.4f", elapsed))s")
        return bestResult
    }

    // MARK: - Direction helpers

    func oppositeDirection(direction: MoveDirection?) -> MoveDirection? {
        if direction == .up    { return .down  }
        if direction == .down  { return .up    }
        if direction == .right { return .left  }
        if direction == .left  { return .right }
        return nil
    }

    // MARK: - BFS

    // -------------------------------------------------------------------------
    // Compact BFS state: entire 8×8 board packed into two UInt64 words.
    // 2 bits per cell (values 0–3) × 64 cells = 128 bits total.
    // Hashing and equality are O(1) integer ops — no Array overhead.
    // -------------------------------------------------------------------------
    private struct BFSState: Hashable {
        var w0: UInt64   // cells 0–31  (row*cols+col, 2 bits each)
        var w1: UInt64   // cells 32–63

        @inline(__always)
        func tile(at index: Int) -> Int {
            let shift = (index & 31) << 1
            let word  = index < 32 ? w0 : w1
            return Int((word >> shift) & 0x3)
        }

        @inline(__always)
        func setting(index: Int, to value: Int) -> BFSState {
            let shift = UInt64((index & 31) << 1)
            let mask  = UInt64(0x3) << shift
            let bits  = UInt64(value & 0x3) << shift
            if index < 32 {
                return BFSState(w0: (w0 & ~mask) | bits, w1: w1)
            } else {
                return BFSState(w0: w0, w1: (w1 & ~mask) | bits)
            }
        }

        // Extract all box cell-indices via bitwise scan — avoids looping all 64 cells.
        // boxRaw == 1 (binary 01), so a 2-bit pair is a box iff its low bit is 1
        // and its high bit is 0.
        func boxIndices() -> [Int] {
            var result = [Int]()
            result.reserveCapacity(12)
            for (base, word) in [(0, w0), (32, w1)] {
                let lo = word & 0x5555555555555555
                let hi = (word >> 1) & 0x5555555555555555
                var boxes = lo & ~hi  // set only where 2-bit value == 01 (box)
                while boxes != 0 {
                    let bit = boxes.trailingZeroBitCount
                    result.append(base + (bit >> 1))
                    boxes &= boxes - 1
                }
            }
            return result
        }
    }

    // Pack self.grid into a BFSState bitboard.
    private func packGrid() -> BFSState {
        let cols = grid[0].count
        var w0: UInt64 = 0, w1: UInt64 = 0
        for r in grid.indices {
            for c in grid[r].indices {
                let idx   = r * cols + c
                let shift = UInt64((idx & 31) << 1)
                let bits  = UInt64(grid[r][c] & 0x3) << shift
                if idx < 32 { w0 |= bits } else { w1 |= bits }
            }
        }
        return BFSState(w0: w0, w1: w1)
    }

    // BFS node: bitboard + flag cell index (row*cols+col).
    private struct BFSNode: Hashable {
        var state:   BFSState
        var flagIdx: Int
    }

    // Forward BFS for optimal solution.
    func findOptimal(maxSteps: Int = 5) -> Int {
        let startTime = Date()

        let rows      = grid.count
        let cols      = grid[0].count
        let target    = currentLevel.targetPos
        let targetIdx = target.row * cols + target.col

        let flagRaw  = TileType.flag.rawValue
        let boxRaw   = TileType.box.rawValue
        let emptyRaw = TileType.empty.rawValue

        let deltas = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        let initial  = BFSNode(state: packGrid(), flagIdx: flagRow * cols + flagCol)
        var frontier = [initial]
        var visited  = Set<BFSNode>(minimumCapacity: 1 << 18)
        visited.insert(initial)

        for step in 1...maxSteps {
            var next = [BFSNode]()
            next.reserveCapacity(frontier.count * 4)

            for node in frontier {
                let st    = node.state
                let fIdx  = node.flagIdx
                let fRow  = fIdx / cols
                let fCol  = fIdx % cols
                let boxes = st.boxIndices()

                for (dRow, dCol) in deltas {

                    // ── Move flag ──────────────────────────────────────────
                    var tRow = fRow, tCol = fCol, hitBox = false
                    while true {
                        let nRow = tRow + dRow; let nCol = tCol + dCol
                        if nRow < 0 || nRow >= rows || nCol < 0 || nCol >= cols { break }
                        if st.tile(at: nRow * cols + nCol) == boxRaw { hitBox = true; break }
                        tRow = nRow; tCol = nCol
                    }
                    if hitBox && !(tRow == fRow && tCol == fCol) {
                        let newFIdx = tRow * cols + tCol
                        let newSt   = st.setting(index: fIdx,    to: emptyRaw)
                                        .setting(index: newFIdx, to: flagRaw)
                        if newFIdx == targetIdx {
                            let elapsed = Date().timeIntervalSince(startTime)
                            print("[findOptimal] Found solution in \(step) step(s). Total time: \(String(format: "%.4f", elapsed))s")
                            return step
                        }
                        let newNode = BFSNode(state: newSt, flagIdx: newFIdx)
                        if visited.insert(newNode).inserted { next.append(newNode) }
                    }

                    // ── Move each box ──────────────────────────────────────
                    for bIdx in boxes {
                        let r = bIdx / cols, c = bIdx % cols
                        var btRow = r, btCol = c, hitObstacle = false
                        while true {
                            let nRow = btRow + dRow; let nCol = btCol + dCol
                            if nRow < 0 || nRow >= rows || nCol < 0 || nCol >= cols { break }
                            let t = st.tile(at: nRow * cols + nCol)
                            if t == boxRaw || t == flagRaw { hitObstacle = true; break }
                            btRow = nRow; btCol = nCol
                        }
                        let newBIdx = btRow * cols + btCol
                        guard newBIdx != bIdx else { continue }

                        if !hitObstacle {
                            let nRow = btRow + dRow; let nCol = btCol + dCol
                            if nRow < 0 || nRow >= rows || nCol < 0 || nCol >= cols {
                                let newNode = BFSNode(state: st.setting(index: bIdx, to: emptyRaw),
                                                      flagIdx: fIdx)
                                if visited.insert(newNode).inserted { next.append(newNode) }
                                continue
                            }
                        }
                        let newNode = BFSNode(state: st.setting(index: bIdx,    to: emptyRaw)
                                                       .setting(index: newBIdx, to: boxRaw),
                                              flagIdx: fIdx)
                        if visited.insert(newNode).inserted { next.append(newNode) }
                    }
                }
            }

            if next.isEmpty { break }
            frontier = next
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("[findOptimal] No solution found within \(maxSteps) step(s). Total time: \(String(format: "%.4f", elapsed))s")
        return -1
    }

    // MARK: - Piece building

    private static func buildPieces(from grid: [[Int]]) -> [MovingPiece] {
        var result: [MovingPiece] = []
        for row in grid.indices {
            for col in grid[row].indices {
                if grid[row][col] == TileType.flag.rawValue {
                    result.append(MovingPiece(id: "flag", row: row, col: col, type: .flag, isSelected: false))
                } else if grid[row][col] == TileType.box.rawValue {
                    result.append(MovingPiece(id: "box-\(row)-\(col)", row: row, col: col, type: .box, isSelected: false))
                }
            }
        }
        return result
    }

    // MARK: - Game actions

    func reset() {
        self.snapshots = []
        self.steps = 0
        self.isGameOver = false
        self.isWin = false
        self.selectedItem = nil
        if isPerfectWin && currentLevel.generateEasy {
            self.isPerfectWin = false
            generateEasyLevelCaller()
        } else if isPerfectWin && currentLevel.generateMedium {
            self.isPerfectWin = false
            generateMediumLevelCaller()
        } else {
            self.isPerfectWin = false
            self.grid = currentLevel.grid
            for line in grid { print(line) }
            print(isPerfectWin)
            self.flagRow = currentLevel.startPos.row
            self.flagCol = currentLevel.startPos.col
        }
        self.pieces = GameViewModel.buildPieces(from: currentLevel.grid)
    }

    func loadSnapshot(pop: Bool, index: Int = 0) {
        var snapshot: GameSnapshot
        if pop {
            if snapshots.count > 0 { snapshot = snapshots.popLast()! } else { return }
        } else {
            if index >= 0 && index < snapshots.count { snapshot = snapshots[index] } else { return }
        }
        self.grid = snapshot.grid
        self.pieces = snapshot.pieces
        self.flagRow = snapshot.flagRow
        self.flagCol = snapshot.flagCol
        self.steps = snapshot.steps
        self.selectedItem = snapshot.selectedItem
        checkState(considerLoss: true)
        syncPieceSelection()
    }

    private func saveSnapshot() {
        snapshots.append(GameSnapshot(
            grid: grid, pieces: pieces,
            flagRow: flagRow, flagCol: flagCol,
            steps: steps, selectedItem: selectedItem
        ))
    }

    func selectItem(row: Int, col: Int) {
        guard !isGameOver && !isWin else { return }
        let type = grid[row][col]
        if type == TileType.flag.rawValue {
            selectedItem = .flag
        } else if type == TileType.box.rawValue {
            selectedItem = .box(row: row, col: col)
        }
        syncPieceSelection()
    }

    func moveSelectedItem(direction: MoveDirection, save: Bool = true) -> [Int] {
        guard !isGameOver && !isWin, let item = selectedItem else { return [-1, -1] }
        if save { saveSnapshot() }
        var pos: [Int]
        switch item {
        case .flag:
            pos = moveFlag(direction: direction)
        case .box(let row, let col):
            pos = moveBox(fromRow: row, fromCol: col, direction: direction)
        }
        syncPieceSelection()
        return pos
    }

    private func syncPieceSelection() {
        for i in pieces.indices {
            switch selectedItem {
            case .flag:
                pieces[i].isSelected = (pieces[i].type == .flag)
            case .box(let r, let c):
                pieces[i].isSelected = (pieces[i].type == .box && pieces[i].row == r && pieces[i].col == c)
            case nil:
                pieces[i].isSelected = false
            }
        }
    }

    private func moveFlag(direction: MoveDirection) -> [Int] {
        let (dRow, dCol) = getDirectionDelta(direction)
        var targetRow = flagRow, targetCol = flagCol, hitBox = false
        while true {
            let nextRow = targetRow + dRow; let nextCol = targetCol + dCol
            if isOutOfBounds(row: nextRow, col: nextCol) { break }
            if grid[nextRow][nextCol] == TileType.box.rawValue { hitBox = true; break }
            targetRow = nextRow; targetCol = nextCol
        }
        if !hitBox {
            let nextRow = targetRow + dRow; let nextCol = targetCol + dCol
            if isOutOfBounds(row: nextRow, col: nextCol) {
                if let idx = pieces.firstIndex(where: { $0.type == .flag }) {
                    pieces[idx].row = targetRow + dRow * 2
                    pieces[idx].col = targetCol + dCol * 2
                }
                if !isTesting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.isGameOver = true }
                } else {
                    self.isGameOver = true
                }
                grid[flagRow][flagCol] = TileType.empty.rawValue
                flagRow = targetRow + dRow * 2
                flagCol = targetCol + dCol * 2
                steps += 1
                return [-1, -1]
            }
        }
        if targetRow == flagRow && targetCol == flagCol { return [-1, -1] }
        grid[flagRow][flagCol] = TileType.empty.rawValue
        grid[targetRow][targetCol] = TileType.flag.rawValue
        if let idx = pieces.firstIndex(where: { $0.type == .flag }) {
            pieces[idx].row = targetRow; pieces[idx].col = targetCol
        }
        flagRow = targetRow; flagCol = targetCol
        steps += 1
        checkState()
        return [targetRow, targetCol]
    }

    private func moveBox(fromRow: Int, fromCol: Int, direction: MoveDirection) -> [Int] {
        let (dRow, dCol) = getDirectionDelta(direction)
        var targetRow = fromRow, targetCol = fromCol, hitObstacle = false
        while true {
            let nextRow = targetRow + dRow; let nextCol = targetCol + dCol
            if isOutOfBounds(row: nextRow, col: nextCol) { break }
            if grid[nextRow][nextCol] == TileType.box.rawValue ||
               grid[nextRow][nextCol] == TileType.flag.rawValue { hitObstacle = true; break }
            targetRow = nextRow; targetCol = nextCol
        }
        if !hitObstacle {
            let nextRow = targetRow + dRow; let nextCol = targetCol + dCol
            if isOutOfBounds(row: nextRow, col: nextCol) {
                if let idx = pieces.firstIndex(where: { $0.type == .box && $0.row == fromRow && $0.col == fromCol }) {
                    pieces[idx].row = targetRow + dRow * 2
                    pieces[idx].col = targetCol + dCol * 2
                    let pieceId = pieces[idx].id
                    if !isTesting {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            self.pieces.removeAll { $0.id == pieceId }
                        }
                    }
                }
                grid[fromRow][fromCol] = TileType.empty.rawValue
                selectedItem = nil
                steps += 1
                return [-1, -1]
            }
        }
        if targetRow == fromRow && targetCol == fromCol { return [-1, -1] }
        grid[fromRow][fromCol] = TileType.empty.rawValue
        grid[targetRow][targetCol] = TileType.box.rawValue
        if let idx = pieces.firstIndex(where: { $0.type == .box && $0.row == fromRow && $0.col == fromCol }) {
            pieces[idx].row = targetRow; pieces[idx].col = targetCol
        }
        steps += 1
        selectedItem = .box(row: targetRow, col: targetCol)
        return [targetRow, targetCol]
    }

    private func getDirectionDelta(_ direction: MoveDirection) -> (Int, Int) {
        switch direction {
        case .up:    return (-1,  0)
        case .down:  return ( 1,  0)
        case .left:  return ( 0, -1)
        case .right: return ( 0,  1)
        }
    }

    private func isOutOfBounds(row: Int, col: Int) -> Bool {
        return row < 0 || row >= grid.count || col < 0 || col >= grid[0].count
    }

    private func checkState(considerLoss: Bool = false) {
        if flagRow == currentLevel.targetPos.row && flagCol == currentLevel.targetPos.col {
            isWin = true
            selectedItem = nil
            isPerfectWin = steps <= currentLevel.minSteps
        } else if considerLoss {
            isGameOver = isOutOfBounds(row: flagRow, col: flagCol)
        }
    }
}
