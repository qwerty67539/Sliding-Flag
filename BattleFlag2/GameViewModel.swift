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
        if (level.generate) {
            generateLevelCaller()
        }
    }
    
    func generateLevelCaller() {
        var activated = false
        while (true) {
            if (generateLevel()) {
                print("Activated: ", activated)
                break
            }
            activated = true
        }
    }
    
    func generateLevel() -> Bool{
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
        for line in grid {
            print(line)
        }
        print(pointer, "\n")
        while currentStep < steps{
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
                    }
                    else {
                        grid[pointer[0]][pointer[1]] = 0
                    }
                    repeats += 1
                    for line in grid {
                        print(line)
                    }
                    print(pointer, ", ", repeats, ", ", previousDirection ?? "nil", "\n")
                }
                if (repeats < 0 || grid[pointer[0] + getDirectionDelta(direction).0][pointer[1] + getDirectionDelta(direction).1] == 2 ) {
                    loops += 1
                    if loops > 10 {
                        return false
                    }
                    var newDirection = direction
                    repeat {
                        newDirection = MoveDirection.allCases[Int.random(in: 0...3)]
                    } while newDirection == previousDirection || newDirection == oppositeDirection(direction: previousDirection)
                    print(direction, ", ", newDirection)
                    direction = newDirection
                }
            } while repeats < 0
            
            if grid[pointer[0] + getDirectionDelta(direction).0][pointer[1] + getDirectionDelta(direction).1] == 0 || grid[pointer[0] + getDirectionDelta(direction).0][pointer[1] + getDirectionDelta(direction).1] == 2 {
                pointer = pointerReset
                grid = gridReset
                loops += 1
                if (loops < 10) {
                    continue
                }
                else {
                    steps = currentStep
                    break
                }
            }
            else {
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
            for line in grid {
                print(line)
            }
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
                if grid[row][col] == -1 {
                    grid[row][col] = 0
                }
            }
        }
        currentLevel = Level(id: currentLevel.id, name: currentLevel.name, grid: grid, startPos: (row: path[0][0], col: path[0][1]), targetPos: (row: pointer[0], col: pointer[1]), minSteps: steps, checkOptimal: false, generate: true)
        pieces = GameViewModel.buildPieces(from: grid)
        if (findOptimal(maxSteps: 2) > 0) {
            return false
        }
        return true
    }
    
    func oppositeDirection(direction: MoveDirection?) -> MoveDirection? {
        if direction == .up {
            return .down
        }
        else if direction == .down {
            return .up
        }
        else if direction == .right {
            return .left
        }
        else if direction == .left {
            return .right
        }
        else {
            return nil
        }
    }
    
    // Lightweight BFS state — no SwiftUI overhead, no MovingPiece arrays.
    // The grid is the only source of truth; flagRow/Col are stored alongside it.
    private struct BFSState: Hashable {
        var grid: [[Int]]
        var flagRow: Int
        var flagCol: Int

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.grid == rhs.grid && lhs.flagRow == rhs.flagRow && lhs.flagCol == rhs.flagCol
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(grid)
            hasher.combine(flagRow)
            hasher.combine(flagCol)
        }
    }

    // Apply one move on a BFSState value. Returns nil when the move is invalid
    // (no displacement, falls out of bounds, or kills the flag).
    private func bfsApplyMove(state: BFSState,
                               pieceRow: Int, pieceCol: Int,
                               direction: MoveDirection,
                               targetPos: (row: Int, col: Int)) -> (state: BFSState, won: Bool)? {
        var g = state.grid
        var fRow = state.flagRow
        var fCol = state.flagCol
        let rows = g.count
        let cols = g[0].count
        let (dRow, dCol) = getDirectionDelta(direction)

        let tileType = g[pieceRow][pieceCol]
        guard tileType == TileType.flag.rawValue || tileType == TileType.box.rawValue else { return nil }

        let isFlag = (tileType == TileType.flag.rawValue)

        var tRow = pieceRow
        var tCol = pieceCol

        if isFlag {
            // Slide until hitting a box or a wall
            var hitBox = false
            while true {
                let nRow = tRow + dRow; let nCol = tCol + dCol
                if nRow < 0 || nRow >= rows || nCol < 0 || nCol >= cols { break }
                if g[nRow][nCol] == TileType.box.rawValue { hitBox = true; break }
                tRow = nRow; tCol = nCol
            }
            if !hitBox {
                // Would slide off the board — flag dies, invalid
                return nil
            }
            if tRow == pieceRow && tCol == pieceCol { return nil } // no movement
            g[pieceRow][pieceCol] = TileType.empty.rawValue
            g[tRow][tCol] = TileType.flag.rawValue
            fRow = tRow; fCol = tCol
        } else {
            // Box move
            var hitObstacle = false
            while true {
                let nRow = tRow + dRow; let nCol = tCol + dCol
                if nRow < 0 || nRow >= rows || nCol < 0 || nCol >= cols { break }
                if g[nRow][nCol] == TileType.box.rawValue || g[nRow][nCol] == TileType.flag.rawValue {
                    hitObstacle = true; break
                }
                tRow = nRow; tCol = nCol
            }
            if !hitObstacle {
                let nRow = tRow + dRow; let nCol = tCol + dCol
                if nRow < 0 || nRow >= rows || nCol < 0 || nCol >= cols {
                    // Box falls off — still a valid state (box removed), but never a win
                    if tRow == pieceRow && tCol == pieceCol { return nil }
                    g[pieceRow][pieceCol] = TileType.empty.rawValue
                    let newState = BFSState(grid: g, flagRow: fRow, flagCol: fCol)
                    return (newState, false)
                }
            }
            if tRow == pieceRow && tCol == pieceCol { return nil }
            g[pieceRow][pieceCol] = TileType.empty.rawValue
            g[tRow][tCol] = TileType.box.rawValue
        }

        let won = (fRow == targetPos.row && fCol == targetPos.col)
        let newState = BFSState(grid: g, flagRow: fRow, flagCol: fCol)
        return (newState, won)
    }

    // BFS for optimal solution — fully self-contained, never touches @Published state.
    func findOptimal(maxSteps: Int = 5) -> Int {
        let target = currentLevel.targetPos
        let rows = grid.count
        let cols = grid[0].count

        let initial = BFSState(grid: grid, flagRow: flagRow, flagCol: flagCol)
        var frontier: [BFSState] = [initial]
        var visited: Set<BFSState> = [initial]

        for step in 1...maxSteps {
            var next: [BFSState] = []

            for state in frontier {
                for r in 0..<rows {
                    for c in 0..<cols {
                        let tile = state.grid[r][c]
                        guard tile == TileType.flag.rawValue || tile == TileType.box.rawValue else { continue }
                        for direction in MoveDirection.allCases {
                            guard let (newState, won) = bfsApplyMove(
                                state: state, pieceRow: r, pieceCol: c,
                                direction: direction, targetPos: target
                            ) else { continue }

                            if won { return step }

                            if !visited.contains(newState) {
                                visited.insert(newState)
                                next.append(newState)
                            }
                        }
                    }
                }
            }

            if next.isEmpty { break }
            frontier = next
        }

        return -1
    }

    // Build the initial MovingPiece list from a grid snapshot
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

    func reset() {
        self.snapshots = []
        self.steps = 0
        self.isGameOver = false
        self.isWin = false
        self.selectedItem = nil
        if isPerfectWin && currentLevel.generate {
            self.isPerfectWin = false
            generateLevelCaller()
        }
        else {
            self.isPerfectWin = false
            self.grid = currentLevel.grid
        
            for line in grid {
                print(line)
            }
            print(isPerfectWin)
            self.flagRow = currentLevel.startPos.row
            self.flagCol = currentLevel.startPos.col
        }
        self.pieces = GameViewModel.buildPieces(from: currentLevel.grid)
    }

    func loadSnapshot(pop: Bool, index: Int = 0) {
        var snapshot: GameSnapshot
        if pop {
            if snapshots.count > 0 {
                snapshot = snapshots.popLast()!
            }
            else {return}
        }
        else {
            if (index >= 0 && index < snapshots.count) {
                snapshot = snapshots[index]
            }
            else {return}
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
            grid: grid,
            pieces: pieces,
            flagRow: flagRow,
            flagCol: flagCol,
            steps: steps,
            selectedItem: selectedItem
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

    func moveSelectedItem(direction: MoveDirection, save: Bool = true) -> [Int]{
        guard !isGameOver && !isWin, let item = selectedItem else { return [-1,-1]}
        
        if save {
            saveSnapshot()
        }
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

    // Keep piece.isSelected in sync with selectedItem
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

    private func moveFlag(direction: MoveDirection) -> [Int]{
        let (dRow, dCol) = getDirectionDelta(direction)
        var targetRow = flagRow
        var targetCol = flagCol
        var hitBox = false

        while true {
            let nextRow = targetRow + dRow
            let nextCol = targetCol + dCol
            if isOutOfBounds(row: nextRow, col: nextCol) { break }
            if grid[nextRow][nextCol] == TileType.box.rawValue {
                hitBox = true
                break
            }
            targetRow = nextRow
            targetCol = nextCol
        }
        if !hitBox {
            let nextRow = targetRow + dRow
            let nextCol = targetCol + dCol
            if isOutOfBounds(row: nextRow, col: nextCol) {
                // Animate flag sliding off before marking game over
                if let idx = pieces.firstIndex(where: { $0.type == .flag }) {
                    pieces[idx].row = targetRow + dRow * 2  // push visually off-screen
                    pieces[idx].col = targetCol + dCol * 2
                }
                if !isTesting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.isGameOver = true
                    }
                }
                else {
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
            pieces[idx].row = targetRow
            pieces[idx].col = targetCol
        }

        flagRow = targetRow
        flagCol = targetCol
        steps += 1
        checkState()
        return [targetRow, targetCol]
    }

    private func moveBox(fromRow: Int, fromCol: Int, direction: MoveDirection) -> [Int]{
        let (dRow, dCol) = getDirectionDelta(direction)
        var targetRow = fromRow
        var targetCol = fromCol
        var hitObstacle = false

        while true {
            let nextRow = targetRow + dRow
            let nextCol = targetCol + dCol
            if isOutOfBounds(row: nextRow, col: nextCol) { break }
            if grid[nextRow][nextCol] == TileType.box.rawValue || grid[nextRow][nextCol] == TileType.flag.rawValue {
                hitObstacle = true
                break
            }
            targetRow = nextRow
            targetCol = nextCol
        }

        if !hitObstacle {
            let nextRow = targetRow + dRow
            let nextCol = targetCol + dCol
            if isOutOfBounds(row: nextRow, col: nextCol) {
                // Animate box sliding off, then remove it
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

        if targetRow == fromRow && targetCol == fromCol { return [-1, -1]}

        grid[fromRow][fromCol] = TileType.empty.rawValue
        grid[targetRow][targetCol] = TileType.box.rawValue

        if let idx = pieces.firstIndex(where: { $0.type == .box && $0.row == fromRow && $0.col == fromCol }) {
            pieces[idx].row = targetRow
            pieces[idx].col = targetCol
        }

        steps += 1
        selectedItem = .box(row: targetRow, col: targetCol)
        return [targetRow, targetCol]
    }

    private func getDirectionDelta(_ direction: MoveDirection) -> (Int, Int) {
        switch direction {
        case .up: return (-1, 0)
        case .down: return (1, 0)
        case .left: return (0, -1)
        case .right: return (0, 1)
        }
    }

    private func isOutOfBounds(row: Int, col: Int) -> Bool {
        return row < 0 || row >= grid.count || col < 0 || col >= grid[0].count
    }

    // Check for win condition and determine if it is the optimal solution
    private func checkState(considerLoss: Bool = false) {
        if flagRow == currentLevel.targetPos.row && flagCol == currentLevel.targetPos.col {
            isWin = true
            selectedItem = nil
            isPerfectWin = steps <= currentLevel.minSteps
        }
        else if considerLoss{
            isGameOver = isOutOfBounds(row: flagRow, col: flagCol)
        }
    }
}
