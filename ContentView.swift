import SwiftUI

struct ThanhDatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var animate = false
    @State private var glow = false
    @State private var selectedTab = 0

    private let cyan = Color(red: 0.15, green: 0.90, blue: 1.0)
    private let violet = Color(red: 0.56, green: 0.32, blue: 1.0)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 26) {
                            header
                            hero
                            stats
                            skills
                            projects
                            footer
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 18)
                        .padding(.bottom, 28)
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity)
                    }

                    bottomBar
                }
                .frame(width: geometry.size.width,
                       height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .preferredColorScheme(.dark)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animate = true
                }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.09)

            Circle()
                .fill(cyan.opacity(glow ? 0.20 : 0.07))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: animate ? 140 : -100,
                        y: animate ? -280 : -150)

            Circle()
                .fill(violet.opacity(glow ? 0.23 : 0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: animate ? -130 : 100,
                        y: animate ? 230 : 350)

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.25),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(cyan.opacity(0.18))
                        .frame(width: 38, height: 38)

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(cyan)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("THANH DAT")
                        .font(.system(size: 13, weight: .black))
                        .tracking(2)

                    Text("DEVELOPER PORTFOLIO")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.48))
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                    .shadow(color: .green, radius: 5)

                Text("ONLINE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.10)))
        }
        .foregroundStyle(.white)
        .padding(.top, 58)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(cyan.opacity(0.16), lineWidth: 1)
                    .frame(width: 180, height: 180)
                    .scaleEffect(animate ? 1.10 : 0.92)

                Circle()
                    .stroke(violet.opacity(0.38), lineWidth: 1)
                    .frame(width: 145, height: 145)
                    .scaleEffect(animate ? 0.92 : 1.08)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                cyan.opacity(0.25),
                                violet.opacity(0.28),
                                .white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 112, height: 112)
                    .overlay(
                        Circle().stroke(.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: cyan.opacity(glow ? 0.55 : 0.15), radius: 28)

                Image(systemName: "terminal.fill")
                    .font(.system(size: 43, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [cyan, violet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(y: animate ? -5 : 5)
            }
            .frame(height: 185)

            VStack(spacing: 9) {
                Text("HELLO, WORLD!")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(cyan)

                Text("Đỗ Thành Đạt")
                    .font(.system(size: 34, weight: .black))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text("iOS DEVELOPER  •  UI CREATOR")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(violet)

                Text("Biến ý tưởng thành trải nghiệm số.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.top, 4)
            }

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(cyan)

                Text("BUILD  •  CREATE  •  INNOVATE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 13)
            .background(.white.opacity(0.055))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(cyan.opacity(0.22), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: 11) {
            statCard(value: "12+", label: "PROJECTS", icon: "square.stack.3d.up.fill", color: cyan)
            statCard(value: "iOS", label: "PLATFORM", icon: "iphone", color: violet)
            statCard(value: "∞", label: "IDEAS", icon: "lightbulb.fill", color: .pink)
        }
    }

    private func statCard(
        value: String,
        label: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 19)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Skills

    private var skills: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("MY SKILLS", subtitle: "CÔNG NGHỆ & KỸ NĂNG")

            skillRow(name: "Swift / SwiftUI", value: 0.90, color: cyan)
            skillRow(name: "iOS Development", value: 0.82, color: violet)
            skillRow(name: "UI / UX Design", value: 0.76, color: .pink)
        }
        .padding(20)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.09), lineWidth: 1)
        )
    }

    private func skillRow(
        name: String,
        value: CGFloat,
        color: Color
    ) -> some View {
        VStack(spacing: 9) {
            HStack {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.65), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * (animate ? value : 0))
                        .shadow(color: color.opacity(0.55), radius: 7)
                }
            }
            .frame(height: 6)
            .animation(.easeOut(duration: 1.3), value: animate)
        }
    }

    // MARK: - Projects

    private var projects: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("FEATURED PROJECTS", subtitle: "NHỮNG GÌ TÔI ĐANG XÂY DỰNG")

            projectCard(
                icon: "iphone.gen3",
                title: "iOS Applications",
                description: "Ứng dụng iPhone với giao diện hiện đại.",
                color: cyan,
                tag: "SWIFTUI"
            )

            projectCard(
                icon: "paintpalette.fill",
                title: "Creative Interface",
                description: "Thiết kế trải nghiệm số và hiệu ứng chuyển động.",
                color: violet,
                tag: "DESIGN"
            )

            projectCard(
                icon: "terminal.fill",
                title: "Developer Tools",
                description: "Công cụ hỗ trợ quy trình phát triển ứng dụng.",
                color: .pink,
                tag: "TOOLS"
            )
        }
    }

    private func projectCard(
        icon: String,
        title: String,
        description: String,
        color: Color,
        tag: String
    ) -> some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.12))
                    .frame(width: 54, height: 54)

                Image(systemName: icon)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 21))
        .overlay(
            RoundedRectangle(cornerRadius: 21)
                .stroke(color.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(cyan)

            Text("CRAFTED WITH PASSION")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.75))

            Text("© 2026 THANH DAT DEVELOPER")
                .font(.system(size: 9))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Section title

    private func sectionTitle(
        _ title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .black))
                .tracking(1.1)
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 9, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bottom navigation

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Home", icon: "house.fill", index: 0)
            tabButton(title: "Projects", icon: "square.grid.2x2.fill", index: 1)
            tabButton(title: "Skills", icon: "chart.bar.fill", index: 2)
            tabButton(title: "Contact", icon: "paperplane.fill", index: 3)
        }
        .padding(.top, 13)
        .padding(.bottom, 30)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.white.opacity(0.10))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(
        title: String,
        icon: String,
        index: Int
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .scaleEffect(selectedTab == index ? 1.12 : 1.0)

                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(selectedTab == index ? cyan : .white.opacity(0.42))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
