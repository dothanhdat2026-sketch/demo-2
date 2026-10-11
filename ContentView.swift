import SwiftUI

// MARK: - In-code password
// This is a basic local screen gate. A password embedded in an IPA can be extracted.
private let appPassword = "dothanhdat"

private enum LicenseCheckResult {
    case valid
    case invalid
}

private func checkLicense(_ enteredPassword: String) -> LicenseCheckResult {
    let cleaned = enteredPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned == appPassword ? .valid : .invalid
}

// MARK: - Animated license gate

struct ContentView: View {
    @AppStorage("developerLicenseValidated") private var licenseValidated = false
    @State private var licenseKey = ""
    @State private var isChecking = false
    @State private var showPortfolio = false
    @State private var animateGlow = false
    @State private var rotateRing = false
    @State private var floatIcon = false
    @State private var message = ""
    @State private var messageIsError = true
    @FocusState private var keyFieldFocused: Bool

    private let cyan = Color(red: 0.22, green: 0.91, blue: 1.0)
    private let violet = Color(red: 0.62, green: 0.38, blue: 1.0)

    var body: some View {
        ZStack {
            if licenseValidated || showPortfolio {
                DeveloperPortfolioView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                licenseScreen
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.65, dampingFraction: 0.86), value: licenseValidated)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                animateGlow = true
            }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                rotateRing = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                floatIcon = true
            }
        }
    }

    private var licenseScreen: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 27) {
                    topBrand
                    animatedEmblem
                        .padding(.top, 12)
                    titleBlock
                    keyEntryCard
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .padding(.bottom, 30)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .onTapGesture {
            keyFieldFocused = false
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.025, blue: 0.07),
                    Color(red: 0.045, green: 0.025, blue: 0.12),
                    Color(red: 0.012, green: 0.06, blue: 0.105)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(cyan.opacity(animateGlow ? 0.20 : 0.07))
                .frame(width: 290, height: 290)
                .blur(radius: 95)
                .offset(x: animateGlow ? 150 : 95, y: -240)

            Circle()
                .fill(violet.opacity(animateGlow ? 0.23 : 0.08))
                .frame(width: 310, height: 310)
                .blur(radius: 100)
                .offset(x: animateGlow ? -140 : -85, y: 250)

            // Subtle developer-style grid.
            Canvas { context, size in
                var path = Path()
                stride(from: 0.0, through: size.width, by: 30.0).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: 0.0, through: size.height, by: 30.0).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.white.opacity(0.025)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
    }

    private var topBrand: some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(cyan)
                .frame(width: 42, height: 42)
                .background(cyan.opacity(0.11), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(cyan.opacity(0.28), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text("THANH DAT")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(.white)
                Text("DEVELOPER ACCESS")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("SECURE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.05), in: Capsule())
        }
    }

    private var animatedEmblem: some View {
        ZStack {
            Circle()
                .stroke(cyan.opacity(0.09), lineWidth: 1)
                .frame(width: 204, height: 204)
                .scaleEffect(animateGlow ? 1.08 : 0.92)

            Circle()
                .trim(from: 0.06, to: 0.78)
                .stroke(
                    AngularGradient(colors: [cyan, violet, .clear, cyan], center: .center),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 178, height: 178)
                .rotationEffect(.degrees(rotateRing ? 360 : 0))

            Circle()
                .trim(from: 0.20, to: 0.64)
                .stroke(violet.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(rotateRing ? -240 : 0))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [cyan.opacity(0.22), violet.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 82
                    )
                )
                .frame(width: 145, height: 145)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 53, weight: .light))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, cyan)
                .shadow(color: cyan.opacity(animateGlow ? 0.65 : 0.25), radius: animateGlow ? 24 : 10)
                .offset(y: floatIcon ? -5 : 5)

            Circle()
                .fill(cyan)
                .frame(width: 7, height: 7)
                .shadow(color: cyan, radius: 8)
                .offset(x: 87, y: -27)

            Circle()
                .fill(violet)
                .frame(width: 5, height: 5)
                .shadow(color: violet, radius: 7)
                .offset(x: -75, y: 47)
        }
        .frame(height: 210)
        .accessibilityLabel("Animated license security emblem")
    }

    private var titleBlock: some View {
        VStack(spacing: 11) {
            Text("ACCESS GATE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(3.5)
                .foregroundStyle(cyan)

            Text("Unlock your\ncreative space.")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .foregroundStyle(.white)

            Text("Nhập mật khẩu để truy cập hồ sơ developer.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.58))
                .padding(.top, 2)
        }
    }

    private var keyEntryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "key.horizontal.fill")
                    .foregroundStyle(cyan)
                Text("PASSWORD AUTHENTICATION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Image(systemName: "wave.3.right")
                    .foregroundStyle(violet)
            }

            HStack(spacing: 11) {
                Image(systemName: "key.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(cyan)
                    .frame(width: 20)

                SecureField("ENTER-PASSWORD", text: $licenseKey)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($keyFieldFocused)
                    .onSubmit(validateKey)
                    .tint(cyan)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Mật khẩu")

                if !licenseKey.isEmpty {
                    Button {
                        licenseKey = ""
                        message = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 16)
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(keyFieldFocused ? cyan.opacity(0.8) : .white.opacity(0.11), lineWidth: 1)
                    .shadow(color: keyFieldFocused ? cyan.opacity(0.18) : .clear, radius: 10)
            }
            .animation(.easeOut(duration: 0.2), value: keyFieldFocused)

            Button(action: validateKey) {
                HStack(spacing: 10) {
                    if isChecking {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 13, weight: .bold))
                    }

                    Text(isChecking ? "VERIFYING PASSWORD..." : "VERIFY & CONTINUE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.2)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.black.opacity(0.9))
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [cyan, Color(red: 0.35, green: 0.73, blue: 1.0), Color(red: 0.67, green: 0.48, blue: 1.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 15)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.white.opacity(animateGlow ? 0.48 : 0.12), lineWidth: 1)
                }
                .shadow(color: cyan.opacity(animateGlow ? 0.25 : 0.08), radius: animateGlow ? 18 : 8, y: 5)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(isChecking || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

            if !message.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: messageIsError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(messageIsError ? Color.orange : cyan)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((messageIsError ? Color.orange : cyan).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 7) {
                Image(systemName: "info.circle")
                Text("Mật khẩu được xác minh trong ứng dụng")
            }
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.42))
        }
        .padding(19)
        .background {
            RoundedRectangle(cornerRadius: 23)
                .fill(.ultraThinMaterial.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 23)
                        .fill(LinearGradient(
                            colors: [.white.opacity(0.065), .white.opacity(0.015)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 23)
                        .stroke(
                            LinearGradient(colors: [cyan.opacity(0.32), violet.opacity(0.22), .white.opacity(0.06)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: violet.opacity(0.08), radius: 28, y: 10)
    }

    private var footer: some View {
        VStack(spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(cyan)
                Text("AUTHORIZED USERS ONLY")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.2)

            Text("© 2026 Đỗ Thành Đạt • Developer Access")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.top, 2)
    }

    private func validateKey() {
        keyFieldFocused = false
        guard !isChecking else { return }

        let cleanedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedKey.isEmpty else {
            setMessage("Vui lòng nhập mật khẩu.", isError: true)
            return
        }

        isChecking = true
        message = ""

        // Brief delay gives the animated verification state time to appear.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            let result = checkLicense(cleanedKey)
            isChecking = false

            switch result {
            case .valid:
                messageIsError = false
                message = "Xác minh thành công. Đang mở giao diện..."
                withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                    licenseValidated = true
                    showPortfolio = true
                }
            case .invalid:
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    setMessage("Mật khẩu không chính xác. Vui lòng thử lại.", isError: true)
                }
            }
        }
    }

    private func setMessage(_ text: String, isError: Bool) {
        withAnimation(.easeInOut(duration: 0.22)) {
            message = text
            messageIsError = isError
        }
    }
}

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}


struct DeveloperPortfolioView: View {
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
