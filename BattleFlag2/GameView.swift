import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode

    let cellSize: CGFloat = 45
    // Gap between cells matches the VStack/HStack spacing of 1
    let cellSpacing: CGFloat = 1
    // Inner padding of the board container
    let boardPadding: CGFloat = 4

    init(level: Level) {
        _viewModel = StateObject(wrappedValue: GameViewModel(level: level))
    }

    // Total board width / height in points
    private var boardWidth: CGFloat {
        CGFloat(viewModel.grid[0].count) * cellSize
            + CGFloat(viewModel.grid[0].count - 1) * cellSpacing
            + boardPadding * 2
    }
    private var boardHeight: CGFloat {
        CGFloat(viewModel.grid.count) * cellSize
            + CGFloat(viewModel.grid.count - 1) * cellSpacing
            + boardPadding * 2
    }

    // Convert (row, col) to the centre-point offset from the board's top-left corner
    private func pieceOffset(row: Int, col: Int) -> CGSize {
        let x = boardPadding + CGFloat(col) * (cellSize + cellSpacing) + cellSize / 2
        let y = boardPadding + CGFloat(row) * (cellSize + cellSpacing) + cellSize / 2
        return CGSize(width: x, height: y)
    }

    var body: some View {
        VStack {
            HStack {
                Button("Back") {
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
                Text("Steps: \(viewModel.steps), Optimal: \(viewModel.currentLevel.minSteps)")
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.loadSnapshot(pop: true)
                    }
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title2)
                }
                .disabled(!viewModel.canUndo)
            }
            .padding()

            Spacer()

            ZStack(alignment: .topLeading) {
                // ── Background grid (cells only, no pieces) ──────────────────
                VStack(spacing: cellSpacing) {
                    ForEach(0..<viewModel.grid.count, id: \.self) { row in
                        HStack(spacing: cellSpacing) {
                            ForEach(0..<viewModel.grid[0].count, id: \.self) { col in
                                BackgroundCellView(
                                    isTarget: row == viewModel.currentLevel.targetPos.row
                                           && col == viewModel.currentLevel.targetPos.col
                                )
                                .frame(width: cellSize, height: cellSize)
                                // Tap on an empty cell deselects
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.selectItem(row: row, col: col)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(boardPadding)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
                .clipped()   // clip pieces that slide off the edge

                // ── Animated piece overlays ───────────────────────────────────
                ForEach(viewModel.pieces) { piece in
                    let offset = pieceOffset(row: piece.row, col: piece.col)
                    PieceView(piece: piece, cellSize: cellSize)
                        // Position relative to board top-left
                        .offset(x: offset.width - cellSize / 2,
                                y: offset.height - cellSize / 2)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectItem(row: piece.row, col: piece.col)
                            }
                        }
                        // Animate every position change for this piece
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: piece.row)
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: piece.col)
                }

                // ── Game-over / win overlay ───────────────────────────────────
                if (viewModel.isGameOver || viewModel.isWin) && !viewModel.isTesting {
                    Color.black.opacity(0.6)
                        .cornerRadius(8)
                    VStack {
                        if viewModel.isWin {
                            if viewModel.isPerfectWin {
                                // Optimal solution
                                Text("Victory ✅")
                                    .font(.largeTitle)
                                    .foregroundColor(.green)
                                Text("You found the optimal solution!")
                                    .font(.title2)
                                    .foregroundColor(.yellow)
                                    .padding(.top, 5)
                            } else {
                                // Non-optimal solution
                                Text("Victory ✅")
                                    .font(.largeTitle)
                                    .foregroundColor(.green)
                                Text("But there's a shorter solution")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                    .padding(.top, 5)
                            }
                            Text("Solved in \(viewModel.steps) steps (minimum: \(viewModel.currentLevel.minSteps))")
                                .foregroundColor(.white)
                                .padding(.top, 10)
                        } else {
                            Text("Game Over")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("The Battle Flag slid off the board")
                                .foregroundColor(.white)
                        }

                        Button("Restart") { viewModel.reset() }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: boardWidth, height: boardHeight)

            Spacer()

            if viewModel.selectedItem != nil {
                VStack(spacing: 5) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            _ = viewModel.moveSelectedItem(direction: .up)
                        }
                    }) {
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.title)
                    }
                    HStack(spacing: 30) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                _ = viewModel.moveSelectedItem(direction: .left)
                            }
                        }) {
                            Image(systemName: "arrowtriangle.left.fill")
                                .font(.title)
                        }
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                _ = viewModel.moveSelectedItem(direction: .down)
                            }
                        }) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.title)
                        }
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                _ = viewModel.moveSelectedItem(direction: .right)
                            }
                        }) {
                            Image(systemName: "arrowtriangle.right.fill")
                                .font(.title)
                        }
                    }
                }
                .padding()
                .background(content: {SwiftUI.Color.blue.opacity(0.1)})
                .cornerRadius(10)
                .transition(.scale)
            } else {
                Text("Tap the Battle Flag or a box to select it, then use the arrows below to move")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            }

            Spacer().frame(height: 20)
        }
        .navigationBarHidden(true)
    }
}

// ── Background cell (no piece content) ──────────────────────────────────────

struct BackgroundCellView: View {
    let isTarget: Bool

    var body: some View {
        Rectangle()
            .fill(isTarget ? Color.red.opacity(0.5) : Color.white)
            .border(Color.gray.opacity(0.5), width: 0.5)
    }
}

// ── Animated piece view ──────────────────────────────────────────────────────

struct PieceView: View {
    let piece: MovingPiece
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            if piece.type == .box {
                RoundedRectangle(cornerRadius: 4)
                    .fill(piece.isSelected ? Color.orange : Color.gray)
                    .frame(width: cellSize - 10, height: cellSize - 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white, lineWidth: piece.isSelected ? 3 : 2)
                    )
                    .shadow(radius: piece.isSelected ? 5 : 0)
            } else if piece.type == .flag {
                Image(systemName: "flag.fill")
                    .foregroundColor(piece.isSelected ? .orange : .blue)
                    .font(.system(size: 24))
                    .shadow(radius: piece.isSelected ? 5 : 0)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }
}
