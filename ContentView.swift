import SwiftUI

@main
struct ThanhDatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.045, blue: 0.10)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.cyan)

                    Text("THÀNH ĐẠT")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)

                    Text("IOS DEVELOPER")
                        .font(.headline)
                        .tracking(5)
                        .foregroundStyle(.cyan)

                    Text("Xin chào! Chào mừng bạn đến với hồ sơ lập trình của Đỗ Thành Đạt.")
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 16) {
                        Label("Swift / SwiftUI", systemImage: "swift")
                        Label("iOS Application", systemImage: "iphone")
                        Label("UI Design", systemImage: "paintpalette")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    Text("BUILD • CREATE • INNOVATE")
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundStyle(.purple)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }
}
