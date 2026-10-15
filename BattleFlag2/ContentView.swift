import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let rules: [(number: Int, text: String)] = [
        (1, "Each turn, you may slide the Battle Flag or a box one step in any of the four directions: up, down, left, or right."),
        (2, "If a sliding piece encounters another box in its path, it stops in the last cell before that box."),
        (3, "If nothing blocks it, the sliding piece exits the board and can no longer be used."),
        (4, "If the Battle Flag slides off the board, you lose the game."),
        (5, "The player who moves the Battle Flag to the target position in the fewest steps wins.")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Play")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 4)

                    ForEach(rules, id: \.number) { rule in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(rule.number).")
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                                .frame(width: 20, alignment: .leading)
                            Text(rule.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ContentView: View {
    @State private var showHelp = false

    var body: some View {
        NavigationView {
            List(levels, id: \.id) { level in
                NavigationLink(destination: GameView(level: level)) {
                    Text(level.name)
                        .font(.headline)
                        .padding()
                }
            }
            .navigationTitle("Battle Flag")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showHelp) {
                HelpView()
            }
        }
    }
}
