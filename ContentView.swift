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
    @State private var glow = false
    @State private var showContent = false
    @State private var selectedTab = 0
    @State private var pulse = false

    private let cyan = Color(red: 0.22, green: 0.91, blue: 1.0)
    private let violet = Color(red: 0.62, green: 0.38, blue: 1.0)

    var body: some View {
        ZStack {
            // Background fills the entire device screen, including safe areas.
            background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        hero
                        stats
                        skills
                        featuredProject
                        contactCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 26)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 18)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glow = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.035, blue: 0.09),
                    Color(red: 0.055, green: 0.035, blue: 0.14),
                    Color(red: 0.015, green: 0.065, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(cyan.opacity(glow ? 0.22 : 0.09))
                .frame(width: 270, height: 270)
                .blur(radius: 90)
                .offset(x: glow ? 140 : 100, y: -250)

            Circle()
                .fill(violet.opacity(glow ? 0.23 : 0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: glow ? -130 : -80, y: 120)

            VStack(spacing: 28) {
                ForEach(0..<18, id: \.self) { index in
                    Rectangle()
                        .fill(.white.opacity(0.025))
                        .frame(height: 1)
                        .offset(y: CGFloat(index) * 0)
                }
            }
        }
        .overlay {
            LinearGradient(
                colors: [.clear, .black.opacity(0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(cyan.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(cyan)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("THANH DAT")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.white)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                        .scaleEffect(pulse ? 1.25 : 0.8)
                    Text("DEVELOPER PORTFOLIO")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            Spacer()

            Image(systemName: "sparkle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(cyan)
                .padding(11)
                .background(.white.opacity(0.06), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.10), lineWidth: 1))
        }
        .padding(.top, 54)
        .padding(.bottom, 10)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("HELLO, WORLD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.8)
                    .foregroundStyle(cyan)
                Spacer()
                Text("01 / PROFILE")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }

            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(colors: [cyan, violet, .clear, cyan], center: .center),
                            lineWidth: 2
                        )
                        .frame(width: 94, height: 94)
                        .rotationEffect(.degrees(glow ? 360 : 0))

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.10, green: 0.23, blue: 0.39), Color(red: 0.16, green: 0.08, blue: 0.30)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 82, height: 82)

                    Image(systemName: "person.crop.square.fill")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, cyan], startPoint: .top, endPoint: .bottom)
                        )
                }
                .shadow(color: cyan.opacity(0.22), radius: 18)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Đỗ Thành Đạt")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)

                    Text("iOS Developer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(cyan)

                    Text("Building ideas into apps.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.57))
                }
                Spacer(minLength: 0)
            }

            Text("Mình yêu thích công nghệ, thiết kế giao diện và tạo ra trải nghiệm iOS hiện đại.")
                .font(.system(size: 13))
                .lineSpacing(5)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Label("SwiftUI", systemImage: "swift")
                Text("•").foregroundStyle(.white.opacity(0.3))
                Label("Creative code", systemImage: "bolt.fill")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))
        }
        .padding(21)
        .background {
            RoundedRectangle(cornerRadius: 27)
                .fill(.ultraThinMaterial.opacity(0.7))
                .overlay {
                    RoundedRectangle(cornerRadius: 27)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.07), .white.opacity(0.015)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 27)
                        .stroke(
                            LinearGradient(colors: [cyan.opacity(0.48), violet.opacity(0.18), .white.opacity(0.06)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: cyan.opacity(glow ? 0.12 : 0.04), radius: 25)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            statCard(number: "12+", title: "PROJECTS", icon: "square.stack.3d.up.fill", color: cyan)
            statCard(number: "iOS", title: "PLATFORM", icon: "iphone", color: violet)
            statCard(number: "∞", title: "IDEAS", icon: "lightbulb.fill", color: Color.mint)
        }
    }

    private func statCard(number: String, title: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            Text(number)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.43))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var skills: some View {
        VStack(alignment: .leading, spacing: 17) {
            sectionHeader("CORE SKILLS", subtitle: "02 / TOOLKIT")

            skillRow(name: "SwiftUI & Interface Design", value: 0.88, color: cyan)
            skillRow(name: "iOS Development", value: 0.80, color: violet)
            skillRow(name: "Creative Problem Solving", value: 0.92, color: Color.mint)
        }
        .padding(20)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 23))
        .overlay(RoundedRectangle(cornerRadius: 23).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func skillRow(name: String, value: CGFloat, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.83))
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.65), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * (showContent ? value : 0))
                        .shadow(color: color.opacity(0.35), radius: 6)
                }
            }
            .frame(height: 5)
            .animation(.spring(response: 1.2, dampingFraction: 0.82).delay(0.25), value: showContent)
        }
    }

    private var featuredProject: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeader("FEATURED WORK", subtitle: "03 / PROJECT")

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [cyan.opacity(0.25), violet.opacity(0.23)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 68, height: 72)
                    Image(systemName: "app.dashed")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("NextGen iOS")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Ứng dụng • Giao diện hiện đại")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                    HStack(spacing: 6) {
                        techPill("SWIFTUI")
                        techPill("MOBILE")
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(cyan)
            }
            .padding(15)
            .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.07), lineWidth: 1))
        }
    }

    private func techPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(cyan)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(cyan.opacity(0.10), in: Capsule())
    }

    private var contactCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 18))
                .foregroundStyle(cyan)
                .frame(width: 43, height: 43)
                .background(cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text("LET’S CONNECT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(cyan)
                Text("Cùng tạo nên điều tuyệt vời.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(16)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(cyan.opacity(0.18), lineWidth: 1))
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white)
            Spacer()
            Text(subtitle)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.38))
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabItem(index: 0, icon: "square.grid.2x2.fill", title: "Home")
            tabItem(index: 1, icon: "folder.fill", title: "Projects")
            tabItem(index: 2, icon: "chart.bar.fill", title: "Skills")
            tabItem(index: 3, icon: "paperplane.fill", title: "Contact")
        }
        .padding(.top, 12)
        .padding(.bottom, 30)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabItem(index: Int, icon: String, title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .scaleEffect(selectedTab == index ? 1.12 : 1.0)
                Text(title)
                    .font(.system(size: 9, weight: selectedTab == index ? .bold : .medium))
            }
            .foregroundStyle(selectedTab == index ? cyan : .white.opacity(0.42))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
