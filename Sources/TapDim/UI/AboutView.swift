import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)

            Text("Blackout")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0")
                .foregroundStyle(.secondary)

            Text("Lights out with one tap.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            Text("Made by Santiago Alonso")

            Link("santiagoalonso.com", destination: URL(string: "https://santiagoalonso.com")!)
                .foregroundStyle(.blue)
        }
        .padding(32)
        .frame(width: 320, height: 340)
    }
}
