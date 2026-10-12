import SwiftUI
import UniformTypeIdentifiers
import Foundation

struct TelegramChat: Identifiable, Hashable, Codable {
    let id: Int64
    let title: String?
    let type: String?
    var displayName: String { title ?? "Chat \(id)" }
}
private struct TelegramUpdateResponse: Decodable {
    let ok: Bool
    let result: [TelegramUpdate]
}
private struct TelegramUpdate: Decodable {
    let update_id: Int
    let message: TelegramMessage?
    let channel_post: TelegramMessage?
}
private struct TelegramMessage: Decodable {
    let chat: TelegramChat
}
private struct TelegramSendResponse: Decodable { let ok: Bool; let description: String? }

private struct SavedTelegramState: Codable {
    var token: String
    var chats: [TelegramChat]
    var selectedIDs: Set<Int64>
    var message: String
    var delay: Double
    var sentCount: Int
    var status: String
    var wasRunning: Bool
}

@MainActor
final class TelegramVM: ObservableObject {
    private static let stateKey = "THANHDAT_TelegramVM_State_v1"
    @Published var token = "" { didSet { saveState() } }
    @Published var chats: [TelegramChat] = [] { didSet { saveState() } }
    @Published var selectedIDs: Set<Int64> = [] { didSet { saveState() } }
    @Published var message = "" { didSet { saveState() } }
    @Published var delay = 30.0 { didSet { saveState() } }
    @Published var status = "Nhập bot token rồi tải danh sách nhóm." { didSet { saveState() } }
    @Published var busy = false
    @Published var running = false
    @Published var sentCount = 0 { didSet { saveState() } }
    private var loopTask: Task<Void, Never>?

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.stateKey),
              let saved = try? JSONDecoder().decode(SavedTelegramState.self, from: data) else { return }
        token = saved.token
        chats = saved.chats
        selectedIDs = saved.selectedIDs
        message = saved.message
        delay = saved.delay
        sentCount = saved.sentCount
        running = false // Tasks cannot survive app termination; never pretend the loop is still active.
        status = saved.wasRunning
            ? "Đã khôi phục thiết lập. Phiên trước đã chạy; hãy bấm BẮT ĐẦU ĐỊNH KỲ để tiếp tục."
            : saved.status
    }

    private func saveState() {
        let saved = SavedTelegramState(
            token: token, chats: chats, selectedIDs: selectedIDs,
            message: message, delay: delay, sentCount: sentCount,
            status: status, wasRunning: running
        )
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: Self.stateKey)
    }

    func loadChats() async {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { status = "Bạn chưa nhập bot token."; return }
        busy = true; defer { busy = false }
        do {
            let data = try await request("getUpdates")
            let decoded = try JSONDecoder().decode(TelegramUpdateResponse.self, from: data)
            guard decoded.ok else { status = "Telegram không trả về dữ liệu hợp lệ."; return }
            var found: [Int64: TelegramChat] = [:]
            for update in decoded.result {
                if let chat = update.message?.chat ?? update.channel_post?.chat,
                   chat.type == "group" || chat.type == "supergroup" || chat.type == "channel" {
                    found[chat.id] = chat
                }
            }
            chats = found.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            status = chats.isEmpty ? "Chưa thấy nhóm nào trong update. Hãy thêm bot vào nhóm, gửi một tin nhắn trong nhóm rồi tải lại. Bot API không thể tự liệt kê mọi nhóm chỉ từ token." : "Đã tìm thấy \(chats.count) nhóm/kênh từ updates của bot."
        } catch { status = "Không tải được nhóm: \(error.localizedDescription)" }
    }

    func sendOnce() async {
        guard !selectedIDs.isEmpty else { status = "Hãy chọn ít nhất một nhóm."; return }
        guard !message.isEmpty else { status = "Nội dung tin nhắn đang trống."; return }
        busy = true; defer { busy = false }
        do {
            for id in selectedIDs.sorted() { try await send(to: id) }
            status = "Đã gửi tin nhắn đến \(selectedIDs.count) nhóm đã chọn."; sentCount += selectedIDs.count
        } catch { status = "Gửi thất bại: \(error.localizedDescription)" }
    }

    // Repeating mode is restricted to groups you manage or that have opted in.
    // A 30-second minimum helps prevent accidental high-rate messaging.
    func startLoop() {
        guard !selectedIDs.isEmpty else { status = "Hãy chọn nhóm trước."; return }
        guard !message.isEmpty else { status = "Nhập nội dung trước."; return }
        guard !running else { return }
        running = true; status = "Đang gửi định kỳ. Chỉ dùng trong nhóm bạn quản lý/đã đồng ý."
        let wait = max(30, delay)
        loopTask = Task {
            while !Task.isCancelled {
                do {
                    for id in selectedIDs.sorted() {
                        try Task.checkCancellation()
                        try await send(to: id); sentCount += 1
                    }
                } catch {
                    if !Task.isCancelled { status = "Tạm dừng do lỗi: \(error.localizedDescription)" }
                    break
                }
                do { try await Task.sleep(for: .seconds(wait)) } catch { break }
            }
            running = false
        }
    }
    func stopLoop() { loopTask?.cancel(); loopTask = nil; running = false; status = "Đã dừng gửi định kỳ." }

    private func send(to chatID: Int64) async throws {
        let url = URL(string: "https://api.telegram.org/bot\(token)/sendMessage")!
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["chat_id": chatID, "text": message])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let decoded = try? JSONDecoder().decode(TelegramSendResponse.self, from: data)
            throw NSError(domain: "Telegram", code: 1, userInfo: [NSLocalizedDescriptionKey: decoded?.description ?? "HTTP request failed"])
        }
        let decoded = try JSONDecoder().decode(TelegramSendResponse.self, from: data)
        guard decoded.ok else { throw NSError(domain: "Telegram", code: 2, userInfo: [NSLocalizedDescriptionKey: decoded.description ?? "Telegram API error"]) }
    }
    private func request(_ method: String) async throws -> Data {
        let url = URL(string: "https://api.telegram.org/bot\(token)/\(method)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}

struct TelegramMessageView: View {
    @StateObject private var vm = TelegramVM()
    @State private var glow = false
    @State private var robotX: CGFloat = -95
    @State private var showImporter = false
    @State private var showToken = false
    @State private var alertText: String?
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)
    private let violet = Color(red: 0.63, green: 0.4, blue: 1)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.025, green: 0.035, blue: 0.09), Color(red: 0.07, green: 0.025, blue: 0.15), Color(red: 0.015, green: 0.07, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Circle().fill(cyan.opacity(glow ? 0.17 : 0.07)).frame(width: 260).blur(radius: 85).offset(x: 120, y: -300)
            Circle().fill(violet.opacity(glow ? 0.18 : 0.06)).frame(width: 280).blur(radius: 90).offset(x: -130, y: 250)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    robotCard
                    tokenCard
                    groupsCard
                    messageCard
                    delayCard
                    actionButtons
                    statusCard
                    Text("Chỉ gửi đến nhóm bạn quản lý hoặc đã đồng ý nhận tin. Không chia sẻ bot token; nếu lộ token, hãy thu hồi bằng BotFather.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.48)).multilineTextAlignment(.center).padding(.horizontal, 8)
                }.padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: vm.busy)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: vm.running)
        .animation(.easeInOut(duration: 0.25), value: vm.status)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { glow = true }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { robotX = 95 }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.plainText, .text], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                vm.message = try String(contentsOf: url, encoding: .utf8)
            } catch { alertText = "Không đọc được file TXT: \(error.localizedDescription)" }
        }
        .alert("Thông báo", isPresented: Binding(get: { alertText != nil }, set: { if !$0 { alertText = nil } })) { Button("OK", role: .cancel) { alertText = nil } } message: { Text(alertText ?? "") }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack { RoundedRectangle(cornerRadius: 14).fill(cyan.opacity(0.14)).frame(width: 48, height: 48); Image(systemName: "paperplane.fill").font(.system(size: 21, weight: .bold)).foregroundStyle(cyan) }
            VStack(alignment: .leading, spacing: 4) {
                Text("THANH DAT").font(.system(size: 18, weight: .black, design: .rounded)).tracking(1.5).foregroundStyle(.white)
                Text("TELEGRAM MESSAGE CONTROL").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.8).foregroundStyle(cyan)
            }
            Spacer()
            Circle().fill(vm.running ? Color.green : Color.white.opacity(0.22)).frame(width: 8, height: 8)
        }.padding(.top, 45).animation(.spring(response: 0.45, dampingFraction: 0.78), value: vm.running)
    }
    private var robotCard: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack {
                    Capsule().fill(.white.opacity(0.04)).frame(height: 2).offset(y: 25)
                    Image(systemName: "sparkles").foregroundStyle(violet.opacity(0.7)).offset(x: -geo.size.width * 0.32, y: -12)
                    Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(cyan.opacity(0.8)).offset(x: geo.size.width * 0.28, y: -20)
                    robot.offset(x: robotX)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(height: 78).clipped()
            Text(vm.running ? "ROBOT ĐANG HOẠT ĐỘNG" : "TELEGRAM BOT READY").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(vm.running ? .green : .white.opacity(0.58))
        }.padding(.vertical, 12).background(panel).overlay(RoundedRectangle(cornerRadius: 22).stroke(cyan.opacity(glow ? 0.45 : 0.16), lineWidth: 1)).scaleEffect(glow ? 1.0 : 0.985).animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: glow)
    }
    private var robot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [cyan, violet], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 58, height: 45).shadow(color: cyan.opacity(0.35), radius: 14)
            VStack(spacing: 8) {
                HStack(spacing: 12) { Capsule().fill(Color.black.opacity(0.8)).frame(width: 8, height: 11); Capsule().fill(Color.black.opacity(0.8)).frame(width: 8, height: 11) }
                Capsule().fill(Color.black.opacity(0.55)).frame(width: 20, height: 3)
            }.offset(y: 2)
            Capsule().fill(cyan).frame(width: 3, height: 10).offset(y: -28)
            Circle().fill(.white).frame(width: 6, height: 6).offset(y: -34)
            Capsule().fill(cyan).frame(width: 12, height: 5).offset(x: -27, y: 5)
            Capsule().fill(violet).frame(width: 12, height: 5).offset(x: 27, y: 5)
        }
    }
    private var tokenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("BOT TOKEN", icon: "key.fill", number: "01")
            HStack {
                Group { if showToken { TextField("Dán token từ BotFather", text: $vm.token) } else { SecureField("Dán token từ BotFather", text: $vm.token) } }
                    .font(.system(size: 12, design: .monospaced)).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button { showToken.toggle() } label: { Image(systemName: showToken ? "eye.slash" : "eye").foregroundStyle(cyan) }
            }.padding(14).background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.09), lineWidth: 1))
            Button { Task { await vm.loadChats() } } label: { HStack { if vm.busy { ProgressView().tint(.black) } else { Image(systemName: "arrow.clockwise") }; Text("TẢI DANH SÁCH NHÓM") }.font(.system(size: 11, weight: .black, design: .rounded)).frame(maxWidth: .infinity).padding(13).background(LinearGradient(colors: [cyan, Color(red: 0.42, green: 0.72, blue: 1)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 13)).foregroundStyle(.black) }.disabled(vm.busy)
        }.padding(16).background(panel).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(cyan.opacity(glow ? 0.22 : 0.08), lineWidth: 1)).animation(.spring(response: 0.4, dampingFraction: 0.8), value: showToken)
    }
    private var groupsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("CHỌN NHÓM / KÊNH", icon: "person.3.fill", number: "02")
            HStack { Text("Đã chọn"); Spacer(); Text("\(vm.selectedIDs.count) / \(vm.chats.count)").foregroundStyle(cyan).monospacedDigit() }.font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.65))
            if vm.chats.isEmpty { Text("Danh sách sẽ hiện sau khi tải updates của bot.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45)).padding(.vertical, 8).transition(.opacity.combined(with: .move(edge: .top))) }
            else {
                ForEach(vm.chats) { chat in
                    Button { if vm.selectedIDs.contains(chat.id) { vm.selectedIDs.remove(chat.id) } else { vm.selectedIDs.insert(chat.id) } } label: {
                        HStack(spacing: 10) {
                            Image(systemName: vm.selectedIDs.contains(chat.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(vm.selectedIDs.contains(chat.id) ? cyan : .white.opacity(0.3)).font(.system(size: 19))
                            VStack(alignment: .leading, spacing: 3) { Text(chat.displayName).foregroundStyle(.white).font(.system(size: 13, weight: .semibold)); Text("ID: \(chat.id)").foregroundStyle(.white.opacity(0.4)).font(.system(size: 10, design: .monospaced)) }
                            Spacer(); Text(chat.type == "channel" ? "KÊNH" : "NHÓM").font(.system(size: 8, weight: .bold)).foregroundStyle(violet).padding(.horizontal, 7).padding(.vertical, 5).background(violet.opacity(0.12), in: Capsule())
                        }.padding(10).background(.white.opacity(vm.selectedIDs.contains(chat.id) ? 0.07 : 0.025), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                }
            }
        }.padding(16).background(panel).animation(.spring(response: 0.42, dampingFraction: 0.78), value: vm.chats.count).animation(.spring(response: 0.32, dampingFraction: 0.72), value: vm.selectedIDs)
    }
    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("NỘI DUNG TIN NHẮN", icon: "text.alignleft", number: "03")
            Text("Giữ nguyên khoảng trắng và xuống dòng trong nội dung.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            TextEditor(text: $vm.message).scrollContentBackground(.hidden).font(.system(size: 13, design: .monospaced)).foregroundStyle(.white).frame(minHeight: 145).padding(8).background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.08), lineWidth: 1))
            HStack { Label("\(vm.message.count) ký tự", systemImage: "character.cursor.ibeam"); Spacer(); Button { showImporter = true } label: { Label("Chọn file TXT", systemImage: "doc.text") .font(.system(size: 11, weight: .bold)).foregroundStyle(cyan) } }.font(.system(size: 10)).foregroundStyle(.white.opacity(0.48))
        }.padding(16).background(panel).animation(.easeInOut(duration: 0.2), value: vm.message.count)
    }
    private var delayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("KHOẢNG CÁCH GỬI", icon: "timer", number: "04")
            HStack(alignment: .firstTextBaseline) { Text("Delay").font(.system(size: 13, weight: .semibold)); Spacer(); Text("\(Int(max(30, vm.delay))) giây").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(cyan).monospacedDigit() }
            Slider(value: $vm.delay, in: 30...600, step: 10).tint(cyan)
            HStack { Text("30 giây"); Spacer(); Text("10 phút") }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
        }.padding(16).background(panel).animation(.spring(response: 0.25, dampingFraction: 0.75), value: vm.delay)
    }
    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button { Task { await vm.sendOnce() } } label: { Label("GỬI MỘT LẦN", systemImage: "paperplane.fill").font(.system(size: 12, weight: .black)).frame(maxWidth: .infinity).padding(15).background(LinearGradient(colors: [cyan, Color(red: 0.45, green: 0.68, blue: 1)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 15)).foregroundStyle(.black) }.disabled(vm.busy || vm.running)
            HStack(spacing: 10) {
                Button { vm.startLoop() } label: { Label("BẮT ĐẦU ĐỊNH KỲ", systemImage: "play.fill").font(.system(size: 10, weight: .black)).frame(maxWidth: .infinity).padding(14).background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.green.opacity(0.35), lineWidth: 1)).foregroundStyle(.green) }.disabled(vm.running || vm.busy)
                Button { vm.stopLoop() } label: { Label("DỪNG", systemImage: "stop.fill").font(.system(size: 10, weight: .black)).frame(maxWidth: .infinity).padding(14).background(Color.red.opacity(0.13), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.red.opacity(0.35), lineWidth: 1)).foregroundStyle(.red) }.disabled(!vm.running)
            }
        }
    }
    private var statusCard: some View {
        HStack(alignment: .top, spacing: 10) { Image(systemName: "waveform.path").foregroundStyle(cyan).padding(.top, 2); VStack(alignment: .leading, spacing: 5) { Text("SYSTEM STATUS").font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1.5).foregroundStyle(cyan); Text(vm.status).font(.system(size: 12)).foregroundStyle(.white.opacity(0.75)); Text("Tổng lượt gửi: \(vm.sentCount)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.45)) } ; Spacer(minLength: 0) }.padding(14).background(panel)
    }
    private var panel: some View { RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial.opacity(0.65)).overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [cyan.opacity(0.22), violet.opacity(0.15), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)) }
    private func sectionTitle(_ title: String, icon: String, number: String) -> some View {
        HStack(spacing: 8) { Image(systemName: icon).foregroundStyle(cyan); Text(title).font(.system(size: 11, weight: .black, design: .rounded)).tracking(1).foregroundStyle(.white); Spacer(); Text(number).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(violet) }
    }
}


// Main utility hub. Each utility opens as a separate screen; the navigation back button
// returns to this dashboard without discarding the saved Telegram settings.
struct ContentView: View {
    @State private var glow = false
    @State private var showAbout = false
    @State private var showSecurity = false
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)
    private let violet = Color(red: 0.63, green: 0.4, blue: 1)

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.018, green: 0.025, blue: 0.07), Color(red: 0.075, green: 0.025, blue: 0.14), Color(red: 0.012, green: 0.075, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                Circle().fill(cyan.opacity(glow ? 0.19 : 0.07)).frame(width: 270).blur(radius: 90).offset(x: 140, y: -320).allowsHitTesting(false)
                Circle().fill(violet.opacity(glow ? 0.17 : 0.06)).frame(width: 290).blur(radius: 95).offset(x: -140, y: 280).allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        dashboardHeader
                        robotBanner
                        HStack(alignment: .firstTextBaseline) {
                            Text("TRUNG TÂM TIỆN ÍCH").font(.system(size: 12, weight: .black, design: .rounded)).tracking(1.6).foregroundStyle(.white)
                            Spacer()
                            Text("04 MODULES").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(cyan.opacity(0.8))
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            NavigationLink { TelegramMessageView().toolbar(.visible, for: .navigationBar) } label: {
                                UtilityTile(icon: "paperplane.fill", title: "Gửi tin nhắn", subtitle: "Telegram Bot", accent: cyan, tag: "SỬ DỤNG NGAY")
                            }.buttonStyle(.plain)
                            NavigationLink { ChatAIView().toolbar(.visible, for: .navigationBar) } label: {
                                UtilityTile(icon: "sparkles", title: "Chat AI", subtitle: "OpenAI API", accent: violet, tag: "TRÒ CHUYỆN")
                            }.buttonStyle(.plain)
                            Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { showAbout = true } } label: {
                                UtilityTile(icon: "cpu.fill", title: "Trạng thái", subtitle: "Thông tin ứng dụng", accent: violet, tag: "THÔNG TIN")
                            }.buttonStyle(.plain)
                            Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { showSecurity = true } } label: {
                                UtilityTile(icon: "shield.lefthalf.filled", title: "Bảo mật", subtitle: "Token & dữ liệu", accent: Color(red: 0.4, green: 1, blue: 0.65), tag: "LƯU Ý")
                            }.buttonStyle(.plain)
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles").foregroundStyle(cyan)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("THIẾT KẾ CHO TỐC ĐỘ").font(.system(size: 10, weight: .black, design: .rounded)).tracking(1).foregroundStyle(.white)
                                Text("Chọn một tiện ích để mở màn hình riêng. Quay lại để chọn chức năng khác.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                            }
                        }.padding(14).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))
                        Text("THANH DAT  •  UTILITY HUB").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.6).foregroundStyle(.white.opacity(0.28)).frame(maxWidth: .infinity).padding(.top, 2)
                    }.padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAbout) { InfoUtilityView(kind: .about).presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
            .sheet(isPresented: $showSecurity) { InfoUtilityView(kind: .security).presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var dashboardHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [cyan.opacity(0.24), violet.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 54, height: 54)
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 23, weight: .bold)).foregroundStyle(cyan).shadow(color: cyan.opacity(0.5), radius: 10)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("THANH DAT").font(.system(size: 22, weight: .black, design: .rounded)).tracking(1.7).foregroundStyle(.white)
                Text("SMART UTILITY CENTER").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.8).foregroundStyle(cyan)
            }
            Spacer()
            Circle().fill(cyan).frame(width: 7, height: 7).shadow(color: cyan, radius: 7).opacity(glow ? 1 : 0.35)
        }.padding(.top, 36)
    }

    private var robotBanner: some View {
        HStack(spacing: 14) {
            AnimatedHubRobot(glow: glow).frame(width: 92, height: 94)
            VStack(alignment: .leading, spacing: 7) {
                Text("HELLO, OPERATOR").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(cyan)
                Text("Mọi công cụ\ntrong một nơi.").font(.system(size: 21, weight: .black, design: .rounded)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                Text("CHỌN MODULE ĐỂ BẮT ĐẦU").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.8).foregroundStyle(.white.opacity(0.48))
            }
            Spacer(minLength: 0)
        }.padding(15).background(RoundedRectangle(cornerRadius: 23).fill(.ultraThinMaterial.opacity(0.7))).overlay(RoundedRectangle(cornerRadius: 23).stroke(LinearGradient(colors: [cyan.opacity(glow ? 0.5 : 0.2), violet.opacity(0.25), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)).shadow(color: cyan.opacity(glow ? 0.09 : 0.02), radius: 22)
    }
}

private struct UtilityTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let tag: String
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 13).fill(accent.opacity(0.14)).frame(width: 43, height: 43)
                    Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(accent).shadow(color: accent.opacity(0.35), radius: 8)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold)).foregroundStyle(accent.opacity(0.8)).padding(8).background(.white.opacity(0.04), in: Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
            }
            Text(tag).font(.system(size: 8, weight: .black, design: .monospaced)).tracking(0.6).foregroundStyle(accent).padding(.horizontal, 8).padding(.vertical, 6).background(accent.opacity(0.09), in: Capsule())
        }.frame(maxWidth: .infinity, minHeight: 150, alignment: .leading).padding(14).background(RoundedRectangle(cornerRadius: 19).fill(.ultraThinMaterial.opacity(0.72))).overlay(RoundedRectangle(cornerRadius: 19).stroke(accent.opacity(hovering ? 0.58 : 0.19), lineWidth: 1)).scaleEffect(hovering ? 1.015 : 1).shadow(color: accent.opacity(hovering ? 0.12 : 0.025), radius: hovering ? 16 : 6).animation(.spring(response: 0.32, dampingFraction: 0.72), value: hovering).onAppear { withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { hovering = true } }
    }
}


private struct AIChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

private struct OpenAIResponsesResult: Decodable {
    struct OutputItem: Decodable {
        struct ContentItem: Decodable {
            let type: String?
            let text: String?
        }
        let content: [ContentItem]?
    }
    let output: [OutputItem]?
    let error: APIError?
    struct APIError: Decodable { let message: String? }
}

private struct ChatAIView: View {
    @State private var apiKey = "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"
    @State private var prompt = ""
    @State private var messages: [AIChatMessage] = [
        AIChatMessage(text: "Xin chào! Mình là Chat AI trong THANH DAT. API đã được cấu hình sẵn; hãy đặt câu hỏi nhé.", isUser: false)
    ]
    @State private var isSending = false
    @State private var status = "API đã được cấu hình sẵn trong source. Không chia sẻ file này vì source chứa thông tin xác thực."
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)
    private let violet = Color(red: 0.63, green: 0.4, blue: 1)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.018, green: 0.025, blue: 0.07), Color(red: 0.075, green: 0.025, blue: 0.14), Color(red: 0.012, green: 0.075, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack(spacing: 11) {
                    Image(systemName: "sparkles").font(.system(size: 20, weight: .bold)).foregroundStyle(cyan)
                        .frame(width: 44, height: 44).background(cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CHAT AI").font(.system(size: 16, weight: .black, design: .rounded)).tracking(1).foregroundStyle(.white)
                        Text("OPENAI API • THANH DAT").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(cyan)
                    }
                    Spacer()
                }.padding(.horizontal, 16).padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("OPENAI API KEY • ĐÃ CẤU HÌNH").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(cyan)
                    SecureField("OpenAI API key đã cấu hình", text: $apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(cyan.opacity(0.25), lineWidth: 1))
                    Text("Không dùng mật khẩu ChatGPT. API tính phí riêng theo mức sử dụng.").font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                }.padding(13).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 14)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                HStack {
                                    if msg.isUser { Spacer(minLength: 42) }
                                    Text(msg.text)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                        .padding(12)
                                        .background(msg.isUser ? violet.opacity(0.22) : cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                                        .overlay(RoundedRectangle(cornerRadius: 15).stroke((msg.isUser ? violet : cyan).opacity(0.25), lineWidth: 1))
                                    if !msg.isUser { Spacer(minLength: 30) }
                                }.id(msg.id)
                            }
                            if isSending {
                                HStack { ProgressView().tint(cyan); Text("AI đang trả lời…").font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)); Spacer() }
                            }
                        }.padding(.horizontal, 14).padding(.vertical, 8)
                    }.onChange(of: messages.count) { _, _ in
                        if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }

                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField("Nhập câu hỏi cho AI…", text: $prompt, axis: .vertical)
                            .lineLimit(1...5).padding(12).foregroundStyle(.white)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
                        Button(action: sendMessage) {
                            Image(systemName: isSending ? "hourglass" : "arrow.up")
                                .font(.system(size: 16, weight: .black)).foregroundStyle(.black)
                                .frame(width: 46, height: 46)
                                .background(LinearGradient(colors: [cyan, violet], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
                        }.disabled(isSending || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity((isSending || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiKey.isEmpty) ? 0.45 : 1)
                    }
                    Text(status).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.horizontal, 14).padding(.bottom, 10)
            }
        }.preferredColorScheme(.dark)
    }

    private func sendMessage() {
        let question = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !key.isEmpty, !isSending else { return }
        messages.append(AIChatMessage(text: question, isUser: true))
        prompt = ""
        isSending = true
        status = "Đang kết nối OpenAI…"
        Task { await requestAnswer(question: question, apiKey: key) }
    }

    @MainActor
    private func requestAnswer(question: String, apiKey: String) async {
        defer { isSending = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
            request.httpMethod = "POST"
            request.timeoutInterval = 60
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "model": "gpt-4.1-mini",
                "instructions": "Bạn là trợ lý AI hữu ích. Trả lời bằng tiếng Việt nếu người dùng viết tiếng Việt.",
                "input": question
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ChatAIError.invalidResponse }
            let decoded = try JSONDecoder().decode(OpenAIResponsesResult.self, from: data)
            guard (200...299).contains(http.statusCode) else {
                throw ChatAIError.server(decoded.error?.message ?? "HTTP \(http.statusCode)")
            }
            let answer = (decoded.output ?? []).flatMap { $0.content ?? [] }
                .filter { $0.type == "output_text" || $0.text != nil }
                .compactMap { $0.text }.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !answer.isEmpty else { throw ChatAIError.empty }
            messages.append(AIChatMessage(text: answer, isUser: false))
            status = "Đã nhận phản hồi từ OpenAI."
        } catch {
            messages.append(AIChatMessage(text: "Không thể nhận câu trả lời: \(error.localizedDescription)", isUser: false))
            status = "Kiểm tra mạng, API key và hạn mức API."
        }
    }

    private enum ChatAIError: LocalizedError {
        case invalidResponse, empty, server(String)
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Phản hồi máy chủ không hợp lệ."
            case .empty: return "Phản hồi không có nội dung văn bản."
            case .server(let message): return message
            }
        }
    }
}

private struct AnimatedHubRobot: View {
    let glow: Bool
    @State private var drift = false
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)
    private let violet = Color(red: 0.63, green: 0.4, blue: 1)

    var body: some View {
        ZStack {
            Circle().fill(cyan.opacity(0.08)).frame(width: 84, height: 84).blur(radius: 12)
            Circle().stroke(cyan.opacity(0.16), lineWidth: 1).frame(width: 78, height: 78)
            Image(systemName: "sparkle").font(.system(size: 11, weight: .bold)).foregroundStyle(violet).offset(x: -35, y: -26)
            Image(systemName: "star.fill").font(.system(size: 7)).foregroundStyle(cyan).offset(x: 34, y: 20)
            ZStack {
                RoundedRectangle(cornerRadius: 17).fill(LinearGradient(colors: [cyan, violet], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 57, height: 48).shadow(color: cyan.opacity(glow ? 0.45 : 0.15), radius: 12)
                VStack(spacing: 7) {
                    HStack(spacing: 12) { Capsule().fill(.black.opacity(0.8)).frame(width: 7, height: 10); Capsule().fill(.black.opacity(0.8)).frame(width: 7, height: 10) }
                    Capsule().fill(.black.opacity(0.55)).frame(width: 18, height: 3)
                }.offset(y: 2)
                Capsule().fill(cyan).frame(width: 3, height: 8).offset(y: -29)
                Circle().fill(.white).frame(width: 5, height: 5).offset(y: -34)
            }.offset(x: drift ? 5 : -5, y: drift ? -4 : 3).rotationEffect(.degrees(drift ? 3 : -3))
        }.onAppear { withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { drift = true } }
    }
}

private struct InfoUtilityView: View {
    enum Kind { case about, security }
    let kind: Kind
    @Environment(\.dismiss) private var dismiss
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.03, blue: 0.08), Color(red: 0.07, green: 0.025, blue: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Image(systemName: kind == .about ? "cpu.fill" : "shield.lefthalf.filled").font(.system(size: 21, weight: .bold)).foregroundStyle(cyan).frame(width: 48, height: 48).background(cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind == .about ? "TRẠNG THÁI ỨNG DỤNG" : "BẢO MẬT DỮ LIỆU").font(.system(size: 13, weight: .black, design: .rounded)).tracking(0.8).foregroundStyle(.white)
                        Text("THANH DAT • UTILITY HUB").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(cyan)
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7)).padding(10).background(.white.opacity(0.08), in: Circle()) }
                }
                if kind == .about {
                    infoRow("square.grid.2x2.fill", "Trung tâm tiện ích", "Chọn chức năng từ trang chính; dùng nút quay lại để chuyển sang tiện ích khác.")
                    infoRow("paperplane.fill", "Telegram Bot", "Màn hình gửi tin nhắn giữ lại cấu hình đã lưu trên thiết bị.")
                    infoRow("arrow.clockwise", "Khôi phục phiên", "Tác vụ Swift không tự tiếp tục sau khi iOS kết thúc app; hãy kiểm tra trạng thái trước khi chạy lại.")
                } else {
                    infoRow("key.fill", "Bot token", "Không chia sẻ token. Nếu token bị lộ, hãy thu hồi và tạo token mới qua BotFather.")
                    infoRow("externaldrive.fill", "Lưu cục bộ", "Thiết lập được lưu trên thiết bị. Bản hiện tại dùng UserDefaults, không phải kho Keychain.")
                    infoRow("person.3.fill", "Sử dụng có trách nhiệm", "Chỉ gửi đến nhóm bạn quản lý hoặc những người đã đồng ý nhận tin; tôn trọng giới hạn Telegram.")
                }
                Spacer(minLength: 0)
            }.padding(22).padding(.top, 10)
        }.preferredColorScheme(.dark)
    }

    private func infoRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(cyan).frame(width: 23).padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.57)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(13).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 1))
    }
}
