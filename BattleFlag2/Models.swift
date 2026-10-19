import SwiftUI

// Tile types for game elements
enum TileType: Int {
    case empty = 0
    case box = 1
    case flag = 2
    case target = 3
}

// Movement directions
enum MoveDirection: CaseIterable{
    case up, left, down, right
}

// Level data structure
struct Level {
    let id: Int
    let name: String
    let grid: [[Int]] // Initial board state
    let startPos: (row: Int, col: Int)
    let targetPos: (row: Int, col: Int)
    var minSteps: Int
    let checkOptimal: Bool
    let generate: Bool
}

// Preset level data (approximately reconstructed from the original images)
// Note: coordinates (row, col) are 0-indexed, with (0,0) at the top-left
let levels: [Level] = [
    // Level 1
    Level(
        id: 1,
        name: "Level 1",
        grid: [
            [0, 1, 0, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 1, 0, 0, 1],
            [1, 0, 0, 0, 3, 0, 0, 0],
            [0, 0, 0, 2, 0, 0, 0, 0],
            [0, 1, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 1, 0, 1, 0, 1]
        ],
        startPos: (5, 3),
        targetPos: (4, 4),
        minSteps: 5,
        checkOptimal: true,
        generate: false
    ),
    // Level 2
    Level(
        id: 2,
        name: "Level 2",
        grid: [
            [0, 1, 0, 0, 0, 0, 1, 0],
            [0, 0, 0, 0, 0, 1, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 2, 0, 0, 0, 0],
            [0, 0, 0, 0, 3, 0, 0, 0],
            [0, 0, 0, 0, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 1, 0, 0, 0, 0, 1]
        ],
        startPos: (3, 3),
        targetPos: (4, 4),
        minSteps: 9,
        checkOptimal: true,
        generate: false
    ),
    // Level 3
    Level(
        id: 3,
        name: "Level 3",
        grid: [
            [0, 0, 0, 0, 0, 0, 0, 1],
            [1, 0, 1, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 1, 0, 0],
            [0, 0, 0, 0, 3, 0, 0, 0],
            [0, 0, 0, 2, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 1],
            [1, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 1, 0, 0, 0, 1, 0]
        ],
        startPos: (4, 3),
        targetPos: (3, 4),
        minSteps: 9,
        checkOptimal: true,
        generate: false
    ),
    // Level 4
    Level(
        id: 4,
        name: "Level 4",
        grid: [
            [0, 0, 0, 0, 0, 0, 0, 1],
            [0, 2, 0, 0, 0, 1, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 1, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 3, 0, 0, 1],
            [0, 0, 0, 0, 0, 1, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 1, 0, 0, 1, 0, 0]
        ],
        startPos: (1, 1),
        targetPos: (4, 4),
        minSteps: 7,
        checkOptimal: true,
        generate: false
    ),
    //Test level
    Level(
        id: 5,
        name: "BFS Test 1",
        grid: [
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 2, 0, 0, 3, 1, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0]
        ],
        startPos: (1, 1),
        targetPos: (1, 4),
        minSteps: 1,
        checkOptimal: true,
        generate: false
    ),
    Level(
        id: 6,
        name: "BFS Test 2",
        grid: [
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 2, 0, 0, 0, 1, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 3, 0, 0, 0],
            [0, 0, 0, 0, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0]
        ],
        startPos: (1, 1),
        targetPos: (4, 4),
        minSteps: 2,
        checkOptimal: true,
        generate: false
    ),
    Level(
        id: 7,
        name: "BFS Test 3",
        grid: [
            [0, 0, 0, 0, 0, 1, 0, 0],
            [0, 2, 0, 0, 0, 0, 0, 1],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 3, 0, 0, 0],
            [0, 0, 0, 1, 0, 0, 0, 1],
            [0, 1, 0, 0, 0, 1, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0]
        ],
        startPos: (1, 1),
        targetPos: (4, 4),
        minSteps: 2,
        checkOptimal: true,
        generate: false
    ),
    Level(
        id: 8,
        name: "Generate random level",
        grid: [
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0]
        ],
        startPos: (-1, -1),
        targetPos: (-1, -1),
        minSteps: -1,
        checkOptimal: false,
        generate: true
    )
]
