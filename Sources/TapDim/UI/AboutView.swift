import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .cornerRadius(20)
            }

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
        .frame(width: 320, height: 380)
    }
}
