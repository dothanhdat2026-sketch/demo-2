import SwiftUI
import UniformTypeIdentifiers

struct TelegramChat: Identifiable, Hashable, Decodable {
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

@MainActor
final class TelegramVM: ObservableObject {
    @Published var token = ""
    @Published var chats: [TelegramChat] = []
    @Published var selectedIDs: Set<Int64> = []
    @Published var message = ""
    @Published var delay = 30.0
    @Published var status = "Nhập bot token rồi tải danh sách nhóm."
    @Published var busy = false
    @Published var running = false
    @Published var sentCount = 0
    private var loopTask: Task<Void, Never>?

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

struct ContentView: View {
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
