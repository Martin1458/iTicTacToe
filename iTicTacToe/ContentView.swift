import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("iTicTacToe")
                .font(.largeTitle)
                .bold()
            Text("Open in Messages to play")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

