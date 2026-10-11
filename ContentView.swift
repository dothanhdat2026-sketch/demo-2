
import SwiftUI
import UserNotifications
import UIKit

// MARK: - Main Content View

struct ContentView: View {
    @State private var isUnlocked = false
    @State private var password = ""
    @State private var showPasswordError = false

    var body: some View {
        Group {
            if isUnlocked {
                MainTabView()
            } else {
                LoginView(
                    password: $password,
                    showPasswordError: $showPasswordError,
                    onLogin: {
                        if password == "dothanhdat" {
                            isUnlocked = true
                            showPasswordError = false
                        } else {
                            showPasswordError = true
                        }
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Login

struct LoginView: View {
    @Binding var password: String
    @Binding var showPasswordError: Bool
    var onLogin: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.13),
                    Color(red: 0.10, green: 0.04, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.cyan)
                    .padding(25)
                    .background(.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                Text("Thanh Dat Developer")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("DEVELOPER TOOLS")
                    .font(.caption.weight(.semibold))
                    .tracking(4)
                    .foregroundStyle(.cyan)

                SecureField("Nhập mật khẩu / Enter password", text: $password)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.cyan.opacity(0.5), lineWidth: 1)
                    }

                if showPasswordError {
                    Text("Mật khẩu không đúng / Incorrect password")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(action: onLogin) {
                    HStack {
                        Text("Mở ứng dụng / Unlock")
                        Image(systemName: "arrow.right")
                    }
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Text("Thanh Dat Developer • iOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
        }
    }
}

// MARK: - Main Tabs

struct MainTabView: View {
    @AppStorage("appLanguage") private var appLanguage = "vi"

    var body: some View {
        TabView {
            UtilitiesView()
                .tabItem {
                    Label(
                        appLanguage == "vi" ? "Tiện ích" : "Utilities",
                        systemImage: "square.grid.2x2"
                    )
                }

            SettingsView()
                .tabItem {
                    Label(
                        appLanguage == "vi" ? "Cài đặt" : "Settings",
                        systemImage: "gearshape"
                    )
                }
        }
        .tint(.cyan)
    }
}

// MARK: - Utilities

struct UtilitiesView: View {
    @AppStorage("appLanguage") private var appLanguage = "vi"

    @State private var notificationTitle = ""
    @State private var notificationBody = ""
    @State private var delaySeconds = 1
    @State private var statusMessage = ""
    @State private var showStatus = false

    private var isVietnamese: Bool {
        appLanguage == "vi"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isVietnamese ? "Xin chào 👋" : "Welcome 👋")
                            .font(.title2.weight(.bold))

                        Text(
                            isVietnamese
                            ? "Chào mừng đến với Thanh Dat Developer."
                            : "Welcome to Thanh Dat Developer."
                        )
                        .foregroundStyle(.secondary)

                        Text("DEVELOPER TOOLKIT")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(.cyan)
                            .padding(.top, 4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.18),
                                Color.blue.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                isVietnamese
                                ? "Tạo thông báo"
                                : "Notification Creator"
                            )
                            .font(.headline)

                            Text(
                                isVietnamese
                                ? "Lên lịch thông báo trên thiết bị"
                                : "Schedule a local device notification"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text(isVietnamese ? "Tiêu đề" : "Title")
                            .font(.subheadline.weight(.semibold))

                        TextField(
                            isVietnamese
                            ? "Nhập tiêu đề thông báo"
                            : "Enter notification title",
                            text: $notificationTitle
                        )
                        .padding(13)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text(isVietnamese ? "Nội dung" : "Message")
                            .font(.subheadline.weight(.semibold))

                        TextEditor(text: $notificationBody)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text(isVietnamese ? "Thời gian gửi" : "Delivery time")
                            .font(.subheadline.weight(.semibold))

                        Picker(
                            isVietnamese ? "Thời gian" : "Delay",
                            selection: $delaySeconds
                        ) {
                            Text(isVietnamese ? "Sau 1 giây" : "After 1 second")
                                .tag(1)

                            Text(isVietnamese ? "Sau 5 giây" : "After 5 seconds")
                                .tag(5)

                            Text(isVietnamese ? "Sau 1 phút" : "After 1 minute")
                                .tag(60)
                        }
                        .pickerStyle(.segmented)

                        Button {
                            scheduleNotification()
                        } label: {
                            Label(
                                isVietnamese
                                ? "Tạo thông báo"
                                : "Schedule Notification",
                                systemImage: "bell.badge"
                            )
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.cyan)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if showStatus {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(18)
                    .background(.white.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            isVietnamese
                            ? "Khu vực tiện ích"
                            : "Utilities Hub",
                            systemImage: "puzzlepiece.extension"
                        )
                        .font(.headline)

                        Text(
                            isVietnamese
                            ? "Bạn có thể thêm các chức năng mới vào khu vực này trong những bản cập nhật tiếp theo."
                            : "Add more features to this area in future updates."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding()
            }
            .background(Color(red: 0.035, green: 0.045, blue: 0.09))
            .navigationTitle(
                isVietnamese ? "Tiện ích" : "Utilities"
            )
        }
    }

    private func scheduleNotification() {
        let title = notificationTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let message = notificationBody.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !title.isEmpty, !message.isEmpty else {
            statusMessage = isVietnamese
                ? "Vui lòng nhập cả tiêu đề và nội dung."
                : "Please enter both a title and a message."
            showStatus = true
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                DispatchQueue.main.async {
                    statusMessage = error.localizedDescription
                    showStatus = true
                }
                return
            }

            guard granted else {
                DispatchQueue.main.async {
                    statusMessage = isVietnamese
                        ? "Bạn chưa cấp quyền thông báo. Hãy bật quyền trong Cài đặt iPhone."
                        : "Notification permission denied. Enable it in iPhone Settings."
                    showStatus = true
                }
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(delaySeconds),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        statusMessage = error.localizedDescription
                    } else {
                        statusMessage = isVietnamese
                            ? "Đã lên lịch thông báo. Hãy kiểm tra quyền thông báo trên thiết bị."
                            : "Notification scheduled. Check notification permissions on your device."
                        notificationTitle = ""
                        notificationBody = ""
                    }
                    showStatus = true
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage = "vi"

    private var isVietnamese: Bool {
        appLanguage == "vi"
    }

    var body: some View {
        NavigationStack {
            List {
                Section(
                    isVietnamese ? "Giao diện" : "Appearance"
                ) {
                    Picker(
                        isVietnamese ? "Ngôn ngữ" : "Language",
                        selection: $appLanguage
                    ) {
                        Text("Tiếng Việt").tag("vi")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.menu)
                }

                Section(
                    isVietnamese ? "Thông tin thiết bị" : "Device Information"
                ) {
                    infoRow(
                        title: isVietnamese ? "Thiết bị" : "Device",
                        value: UIDevice.current.model,
                        symbol: "iphone"
                    )

                    infoRow(
                        title: isVietnamese ? "Hệ điều hành" : "Operating System",
                        value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                        symbol: "gear"
                    )
                }

                Section(
                    isVietnamese ? "Bản quyền" : "Copyright"
                ) {
                    infoRow(
                        title: "Application",
                        value: "Thanh Dat Developer",
                        symbol: "app"
                    )

                    infoRow(
                        title: isVietnamese ? "Tác giả" : "Developer",
                        value: "Đỗ Thành Đạt",
                        symbol: "person.crop.circle"
                    )

                    infoRow(
                        title: isVietnamese ? "Bản quyền" : "Copyright",
                        value: "© 2026 Đỗ Thành Đạt",
                        symbol: "c.circle"
                    )

                    infoRow(
                        title: isVietnamese ? "Phiên bản" : "Version",
                        value: "1.0.0",
                        symbol: "number"
                    )
                }

                Section {
                    HStack {
                        Spacer()

                        VStack(spacing: 8) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.title)
                                .foregroundStyle(.cyan)

                            Text("Thanh Dat Developer")
                                .font(.headline)

                            Text("Made for developers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.035, green: 0.045, blue: 0.09))
            .navigationTitle(
                isVietnamese ? "Cài đặt" : "Settings"
            )
        }
    }

    private func infoRow(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.cyan)
                .frame(width: 24)

            Text(title)

            Spacer(minLength: 12)

            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
