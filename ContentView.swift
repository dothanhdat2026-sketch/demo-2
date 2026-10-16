import SwiftUI
import UniformTypeIdentifiers
import Foundation
import UIKit

extension UTType {
    static let ipa: UTType = UTType(exportedAs: "com.thanhdat.ipa", conformingTo: .archive)
}

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
        running = false
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
            status = chats.isEmpty ? "Chưa thấy nhóm nào trong update. Hãy thêm bot vào nhóm, gửi một tin nhắn trong nhóm rồi tải lại." : "Đã tìm thấy \(chats.count) nhóm/kênh từ updates của bot."
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

    func startLoop() {
        guard !selectedIDs.isEmpty else { status = "Hãy chọn nhóm trước."; return }
        guard !message.isEmpty else { status = "Nhập nội dung trước."; return }
        guard !running else { return }
        running = true; status = "Đang gửi định kỳ."
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

@MainActor
final class WebCrackVM: ObservableObject {
    @Published var urlString = ""
    @Published var status = "Nhập link web rồi bấm PHÂN TÍCH."
    @Published var busy = false
    @Published var progress: Double = 0
    @Published var totalAssets: Int = 0
    @Published var doneAssets: Int = 0
    @Published var zipURL: URL?
    @Published var previewHTML: String = ""
    @Published var log: [String] = []

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "vi,en;q=0.9"
        ]
        return URLSession(configuration: cfg)
    }()

    func crack() async {
        guard let base = normalizedURL(urlString) else {
            status = "Link không hợp lệ."; return
        }
        busy = true; progress = 0; doneAssets = 0; totalAssets = 0
        log.removeAll(); zipURL = nil; previewHTML = ""
        defer { busy = false }

        do {
            append("GET \(base.absoluteString)")
            let (htmlData, response) = try await session.data(from: base)
            guard let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) else {
                throw NSError(domain: "WebCrack", code: 1, userInfo: [NSLocalizedDescriptionKey: "HTTP không hợp lệ"])
            }
            guard var html = String(data: htmlData, encoding: .utf8)
                    ?? String(data: htmlData, encoding: .isoLatin1) else {
                throw NSError(domain: "WebCrack", code: 2, userInfo: [NSLocalizedDescriptionKey: "Không decode được HTML"])
            }
            append("HTML gốc: \(htmlData.count) bytes")

            var assets: [AssetRef] = []
            assets += extractTag(html, tag: "script", attr: "src")
            assets += extractTag(html, tag: "link",  attr: "href")
            assets += extractTag(html, tag: "img",   attr: "src")
            assets += extractTag(html, tag: "img",   attr: "data-src")
            assets += extractTag(html, tag: "source",attr: "src")
            assets += extractTag(html, tag: "source",attr: "srcset")
            assets += extractTag(html, tag: "video", attr: "src")
            assets += extractTag(html, tag: "audio", attr: "src")

            var seen = Set<String>()
            assets = assets.filter { a in
                if seen.contains(a.remote.absoluteString) { return false }
                seen.insert(a.remote.absoluteString); return true
            }
            totalAssets = assets.count
            append("\(totalAssets) asset cần tải")

            var localMap: [String: String] = [:]
            let folder = uniqueFolder()
            let fm = FileManager.default

            let rootDir = fm.temporaryDirectory.appendingPathComponent(folder, isDirectory: true)
            try? fm.removeItem(at: rootDir)
            try fm.createDirectory(at: rootDir, withIntermediateDirectories: true)
            let assetDir = rootDir.appendingPathComponent("assets", isDirectory: true)
            try fm.createDirectory(at: assetDir, withIntermediateDirectories: true)

            await withTaskGroup(of: (AssetRef, String?, Data?).self) { group in
                for a in assets {
                    group.addTask { [session] in
                        do {
                            let (data, _) = try await session.data(from: a.remote)
                            return (a, nil, data)
                        } catch {
                            return (a, error.localizedDescription, nil)
                        }
                    }
                }
                for await (a, err, data) in group {
                    doneAssets += 1
                    progress = Double(doneAssets) / Double(max(1, totalAssets))
                    if let err = err {
                        append("LỖI \(a.remote.lastPathComponent) \(err)")
                        continue
                    }
                    guard let data = data else { continue }
                    let name = uniqueAssetName(for: a.remote, in: localMap)
                    let localPath = "assets/\(name)"
                    let dst = rootDir.appendingPathComponent(localPath)
                    try? data.write(to: dst)
                    localMap[a.remote.absoluteString] = localPath
                    append("OK \(name) \(data.count)b")
                }
            }

            html = rewrite(html, localMap: localMap)
            let indexPath = rootDir.appendingPathComponent("index.html")
            try html.write(to: indexPath, atomically: true, encoding: .utf8)

            let zip = rootDir.appendingPathComponent("\(folder).zip")
            try ZipWriter.zip(directory: rootDir, to: zip, rootName: folder)
            zipURL = zip
            previewHTML = html
            status = "XONG. \(doneAssets)/\(totalAssets) asset. Bấm TẢI FILE VỀ."
            append("Đóng gói \(zip.lastPathComponent)")
        } catch {
            status = "Lỗi: \(error.localizedDescription)"
            append("LỖI \(error.localizedDescription)")
        }
    }

    private func append(_ s: String) { log.append(s) }

    private func normalizedURL(_ s: String) -> URL? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if !t.lowercased().hasPrefix("http://") && !t.lowercased().hasPrefix("https://") {
            t = "https://" + t
        }
        return URL(string: t)
    }

    private func uniqueFolder() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd_HHmmss"
        return "webcrack_\(f.string(from: Date()))"
    }

    private func uniqueAssetName(for url: URL, in map: [String: String]) -> String {
        let raw = url.lastPathComponent.isEmpty ? "file" : url.lastPathComponent
        let base = raw.components(separatedBy: "?").first ?? raw
        var candidate = base
        var i = 1
        let existing = Set(map.values.map { ($0 as NSString).lastPathComponent })
        while existing.contains(candidate) {
            let ext = (base as NSString).pathExtension
            let stem = (base as NSString).deletingPathExtension
            candidate = ext.isEmpty ? "\(stem)_\(i)" : "\(stem)_\(i).\(ext)"
            i += 1
        }
        return candidate
    }

    private struct AssetRef { let remote: URL; let original: String }

    private func resolve(_ raw: String, base: URL) -> URL? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if t.hasPrefix("data:") || t.hasPrefix("javascript:") || t.hasPrefix("#") { return nil }
        return URL(string: t, relativeTo: base)?.absoluteURL
    }

    private func extractTag(_ html: String, tag: String, attr: String) -> [AssetRef] {
        guard let base = normalizedURL(urlString) else { return [] }
        var out: [AssetRef] = []
        let pattern = "<\(tag)\\b[^>]*?\\b\(attr)\\s*=\\s*[\"']([^\"']+)[\"']"
        if let rx = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let ns = html as NSString
            rx.enumerateMatches(in: html, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
                guard let m = m, m.numberOfRanges >= 2 else { return }
                let raw = ns.substring(with: m.range(at: 1))
                if attr == "srcset" {
                    for part in raw.split(separator: ",") {
                        let u = part.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
                        if let url = resolve(u, base: base) { out.append(AssetRef(remote: url, original: u)) }
                    }
                } else if let url = resolve(raw, base: base) {
                    out.append(AssetRef(remote: url, original: raw))
                }
            }
        }
        return out
    }

    private func rewrite(_ html: String, localMap: [String: String]) -> String {
        var result = html
        for (remote, local) in localMap {
            let variants = [
                remote,
                remote.replacingOccurrences(of: "https:", with: "http:"),
                "//" + (URL(string: remote)?.host ?? "") + (URL(string: remote)?.path ?? ""),
                URL(string: remote)?.path ?? ""
            ]
            for v in variants where !v.isEmpty {
                result = result.replacingOccurrences(of: "\"\(v)\"", with: "\"\(local)\"")
                result = result.replacingOccurrences(of: "'\(v)'", with: "'\(local)'")
            }
        }
        return result
    }
}

struct WebSourceCrackerView: View {
    @StateObject private var vm = WebCrackVM()
    @State private var showShare = false
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)
    private let violet = Color(red: 0.63, green: 0.4, blue: 1)

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.018, green: 0.025, blue: 0.07),
                Color(red: 0.075, green: 0.025, blue: 0.14),
                Color(red: 0.012, green: 0.075, blue: 0.12)
            ], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 10) {
                        Text("LINK WEB").font(.system(size: 10, weight: .black, design: .rounded)).tracking(1.2).foregroundStyle(cyan)
                        TextField("https://example.com", text: $vm.urlString)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(12)
                            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(cyan.opacity(0.25), lineWidth: 1))

                        Button { Task { await vm.crack() } } label: {
                            HStack {
                                if vm.busy { ProgressView().tint(.black) }
                                else { Image(systemName: "bolt.fill") }
                                Text(vm.busy ? "ĐANG CRACK..." : "CRACK FULL SRC").font(.system(size: 12, weight: .black))
                            }
                            .frame(maxWidth: .infinity).padding(14)
                            .background(LinearGradient(colors: [cyan, violet], startPoint: .leading, endPoint: .trailing),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.black)
                        }.disabled(vm.busy || vm.urlString.isEmpty)

                        if vm.busy || vm.progress > 0 {
                            ProgressView(value: vm.progress).tint(cyan)
                            Text("\(vm.doneAssets)/\(vm.totalAssets) asset").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(cyan.opacity(0.18), lineWidth: 1))

                    if let zip = vm.zipURL {
                        Button { showShare = true } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("TẢI FILE VỀ (\(zip.lastPathComponent))").font(.system(size: 12, weight: .black))
                            }
                            .frame(maxWidth: .infinity).padding(14)
                            .background(Color.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.5), lineWidth: 1))
                            .foregroundStyle(.green)
                        }
                        .sheet(isPresented: $showShare) {
                            ShareSheet(items: [zip])
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRẠNG THÁI").font(.system(size: 10, weight: .black)).foregroundStyle(cyan)
                        Text(vm.status).font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))

                    if !vm.log.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LOG").font(.system(size: 10, weight: .black)).foregroundStyle(violet)
                            ForEach(Array(vm.log.enumerated()), id: \.offset) { _, line in
                                Text(line).font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(18)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Web Cracker")
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(cyan.opacity(0.14)).frame(width: 48, height: 48)
                Image(systemName: "network").font(.system(size: 21, weight: .bold)).foregroundStyle(cyan)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("WEB SOURCE CRACKER").font(.system(size: 15, weight: .black, design: .rounded)).tracking(1).foregroundStyle(.white)
                Text("FETCH REWRITE ZIP EXPORT").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(cyan)
            }
            Spacer()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

enum ZipWriter {
    static func zip(directory: URL, to output: URL, rootName: String) throws {
        let fm = FileManager.default
        var entries: [(path: String, data: Data)] = []

        let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true { continue }
            let rel = fileURL.path.replacingOccurrences(of: directory.path + "/", with: "")
            let data = try Data(contentsOf: fileURL)
            entries.append(("\(rootName)/\(rel)", data))
        }

        var out = Data()
        var centralDirectory = Data()

        for (path, data) in entries {
            let nameData = path.data(using: .utf8)!
            let crc = crc32(data)
            let offset = out.count

            out.append(le32(0x04034b50))
            out.append(le16(20))
            out.append(le16(0))
            out.append(le16(0))
            out.append(le16(0))
            out.append(le16(0))
            out.append(le32(crc))
            out.append(le32(UInt32(data.count)))
            out.append(le32(UInt32(data.count)))
            out.append(le16(UInt16(nameData.count)))
            out.append(le16(0))
            out.append(nameData)
            out.append(data)

            centralDirectory.append(le32(0x02014b50))
            centralDirectory.append(le16(20))
            centralDirectory.append(le16(20))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le32(crc))
            centralDirectory.append(le32(UInt32(data.count)))
            centralDirectory.append(le32(UInt32(data.count)))
            centralDirectory.append(le16(UInt16(nameData.count)))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le16(0))
            centralDirectory.append(le32(0))
            centralDirectory.append(le32(UInt32(offset)))
            centralDirectory.append(nameData)
        }

        let cdOffset = out.count
        out.append(centralDirectory)

        out.append(le32(0x06054b50))
        out.append(le16(0))
        out.append(le16(0))
        out.append(le16(UInt16(entries.count)))
        out.append(le16(UInt16(entries.count)))
        out.append(le32(UInt32(centralDirectory.count)))
        out.append(le32(UInt32(cdOffset)))
        out.append(le16(0))

        try out.write(to: output)
    }

    private static func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    private static func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
            return c
        }
    }()

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for b in data { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }
}

enum ZipReader {
    static func unzip(_ zipURL: URL, to destination: URL) throws -> [URL] {
        let data = try Data(contentsOf: zipURL)
        let fm = FileManager.default
        try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        var extracted: [URL] = []

        var offset = 0
        let bytes = [UInt8](data)
        let count = bytes.count

        while offset + 30 <= count {
            let sig = readUInt32(bytes, offset)
            if sig != 0x04034b50 { break }
            let flags = readUInt16(bytes, offset + 6)
            let method = readUInt16(bytes, offset + 8)
            let compSize = Int(readUInt32(bytes, offset + 18))
            let uncompSize = Int(readUInt32(bytes, offset + 22))
            let nameLen = Int(readUInt16(bytes, offset + 26))
            let extraLen = Int(readUInt16(bytes, offset + 28))

            let nameStart = offset + 30
            let nameEnd = nameStart + nameLen
            guard nameEnd <= count else { break }
            let nameData = Data(bytes[nameStart..<nameEnd])
            let name = String(data: nameData, encoding: .utf8) ?? ""

            let dataStart = nameEnd + extraLen
            var fileData: Data
            var nextOffset: Int

            if flags & 0x08 != 0 {
                var descOffset = dataStart + compSize
                if descOffset + 16 <= count {
                    let maybeSig = readUInt32(bytes, descOffset)
                    if maybeSig == 0x08074b50 { descOffset += 4 }
                    let realCompSize = Int(readUInt32(bytes, descOffset + 4))
                    let dataEnd = dataStart + realCompSize
                    guard dataEnd <= count else { break }
                    fileData = Data(bytes[dataStart..<dataEnd])
                    nextOffset = descOffset + 12
                } else {
                    break
                }
            } else {
                let dataEnd = dataStart + compSize
                guard dataEnd <= count else { break }
                fileData = Data(bytes[dataStart..<dataEnd])
                nextOffset = dataEnd
            }

            if method == 8 {
                fileData = try Inflate.rawDeflate(fileData, expectedSize: uncompSize)
            }

            let target = destination.appendingPathComponent(name)
            if name.hasSuffix("/") {
                try? fm.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                try? fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileData.write(to: target)
                extracted.append(target)
            }
            offset = nextOffset
        }
        return extracted
    }

    private static func readUInt16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }
    private static func readUInt32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }
}

enum Inflate {
    enum InflateError: LocalizedError {
        case unexpectedEnd, invalidCode, invalidDistance, invalidBlock
        var errorDescription: String? {
            switch self {
            case .unexpectedEnd: return "Dữ liệu deflate kết thúc bất ngờ."
            case .invalidCode: return "Mã Huffman không hợp lệ."
            case .invalidDistance: return "Khoảng cách LZ77 không hợp lệ."
            case .invalidBlock: return "Block type không hỗ trợ."
            }
        }
    }

    struct Huffman {
        var counts: [Int]
        var symbols: [Int]

        func decode(_ readBit: () throws -> Int) throws -> Int {
            var code = 0
            var first = 0
            var index = 0
            for len in 1...15 {
                code |= try readBit()
                let count = counts[len]
                if code - first < count {
                    return symbols[index + (code - first)]
                }
                index += count
                first = (first + count) << 1
                code <<= 1
            }
            throw InflateError.invalidCode
        }
    }

    static func rawDeflate(_ input: Data, expectedSize: Int) throws -> Data {
        var output = Data(count: max(expectedSize, 65536))
        let inputBytes = [UInt8](input)
        var outCount = 0
        var bitPos = 0

        func ensureCapacity(_ needed: Int) {
            if outCount + needed > output.count {
                let newCap = max(output.count * 2, outCount + needed + 65536)
                var newData = Data(count: newCap)
                newData.withUnsafeMutableBytes { dst in
                    output.withUnsafeBytes { src in
                        dst.copyBytes(from: src)
                    }
                }
                output = newData
            }
        }

        func readBit() throws -> Int {
            if bitPos >= inputBytes.count * 8 { throw InflateError.unexpectedEnd }
            let byte = inputBytes[bitPos >> 3]
            let bit = (Int(byte) >> (bitPos & 7)) & 1
            bitPos += 1
            return bit
        }

        func readBits(_ n: Int) throws -> Int {
            var value = 0
            for i in 0..<n {
                value |= try readBit() << i
            }
            return value
        }

        func alignToByte() {
            if bitPos % 8 != 0 { bitPos += 8 - (bitPos % 8) }
        }

        func buildHuffman(lengths: [Int]) -> Huffman {
            var counts = [Int](repeating: 0, count: 16)
            for len in lengths where len > 0 { counts[len] += 1 }
            var offsets = [Int](repeating: 0, count: 16)
            for i in 1..<16 { offsets[i] = offsets[i - 1] + counts[i - 1] }
            var symbols = [Int](repeating: 0, count: max(lengths.count, 1))
            for (sym, len) in lengths.enumerated() where len > 0 {
                symbols[offsets[len]] = sym
                offsets[len] += 1
            }
            return Huffman(counts: counts, symbols: symbols)
        }

        let lengthBase = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
        let lengthExtra = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
        let distBase = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
        let distExtra = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]

        while true {
            let bfinal = try readBit()
            let btype = try readBits(2)

            if btype == 0 {
                alignToByte()
                _ = try readBits(16)
                let len = try readBits(16)
                _ = try readBits(16)
                ensureCapacity(len)
                for _ in 0..<len {
                    let b = try readBits(8)
                    output[outCount] = UInt8(b)
                    outCount += 1
                }
            } else if btype == 1 || btype == 2 {
                let litHuff: Huffman
                let distHuff: Huffman

                if btype == 1 {
                    var litLens = [Int](repeating: 0, count: 288)
                    for i in 0..<144 { litLens[i] = 8 }
                    for i in 144..<256 { litLens[i] = 9 }
                    for i in 256..<280 { litLens[i] = 7 }
                    for i in 280..<288 { litLens[i] = 8 }
                    litHuff = buildHuffman(lengths: litLens)
                    distHuff = buildHuffman(lengths: [Int](repeating: 5, count: 30))
                } else {
                    let hlit = try readBits(5) + 257
                    let hdist = try readBits(5) + 1
                    let hclen = try readBits(4) + 4
                    let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
                    var clLens = [Int](repeating: 0, count: 19)
                    for i in 0..<hclen {
                        clLens[order[i]] = try readBits(3)
                    }
                    let clHuff = buildHuffman(lengths: clLens)
                    var allLens = [Int]()
                    while allLens.count < hlit + hdist {
                        let sym = try clHuff.decode(readBit)
                        if sym < 16 {
                            allLens.append(sym)
                        } else if sym == 16 {
                            let rep = try readBits(2) + 3
                            let prev = allLens.last ?? 0
                            for _ in 0..<rep { allLens.append(prev) }
                        } else if sym == 17 {
                            let rep = try readBits(3) + 3
                            for _ in 0..<rep { allLens.append(0) }
                        } else {
                            let rep = try readBits(7) + 11
                            for _ in 0..<rep { allLens.append(0) }
                        }
                    }
                    let litLens = Array(allLens.prefix(hlit))
                    let distLens = Array(allLens.suffix(hdist))
                    litHuff = buildHuffman(lengths: litLens)
                    distHuff = buildHuffman(lengths: distLens)
                }

                while true {
                    let sym = try litHuff.decode(readBit)
                    if sym < 256 {
                        ensureCapacity(1)
                        output[outCount] = UInt8(sym)
                        outCount += 1
                    } else if sym == 256 {
                        break
                    } else {
                        let li = sym - 257
                        guard li < lengthBase.count else { throw InflateError.invalidCode }
                        let length = lengthBase[li] + (try readBits(lengthExtra[li]))
                        let dsym = try distHuff.decode(readBit)
                        guard dsym < distBase.count else { throw InflateError.invalidCode }
                        let dist = distBase[dsym] + (try readBits(distExtra[dsym]))
                        guard dist <= outCount else { throw InflateError.invalidDistance }
                        ensureCapacity(length)
                        let start = outCount - dist
                        for i in 0..<length {
                            output[outCount] = output[start + i]
                            outCount += 1
                        }
                    }
                }
            } else {
                throw InflateError.invalidBlock
            }

            if bfinal == 1 { break }
        }

        return output.prefix(outCount)
    }
}

@MainActor
final class IPACrackVM: ObservableObject {
    @Published var status = "Chọn file .ipa để bắt đầu."
    @Published var busy = false
    @Published var progress: Double = 0
    @Published var log: [String] = []
    @Published var zipURL: URL?
    @Published var fileName: String = ""
    @Published var fileSize: String = ""

    func crack(ipa: URL) async {
        busy = true; progress = 0; log.removeAll(); zipURL = nil
        defer { busy = false }

        let fm = FileManager.default
        let access = ipa.startAccessingSecurityScopedResource()
        defer { if access { ipa.stopAccessingSecurityScopedResource() } }

        do {
            fileName = ipa.lastPathComponent
            let attrs = try? fm.attributesOfItem(atPath: ipa.path)
            if let size = attrs?[.size] as? Int {
                fileSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
            append("IPA: \(fileName) (\(fileSize))")

            let work = fm.temporaryDirectory.appendingPathComponent("ipacrack_\(Int(Date().timeIntervalSince1970))", isDirectory: true)
            try? fm.removeItem(at: work)
            try fm.createDirectory(at: work, withIntermediateDirectories: true)

            let localCopy = work.appendingPathComponent(fileName)
            if fm.fileExists(atPath: localCopy.path) { try fm.removeItem(at: localCopy) }
            try fm.copyItem(at: ipa, to: localCopy)
            append("Đã copy vào sandbox")

            progress = 0.1
            append("Đang giải nén IPA...")
            let extractDir = work.appendingPathComponent("extracted", isDirectory: true)
            let files = try ZipReader.unzip(localCopy, to: extractDir)
            append("Giải nén xong: \(files.count) file")
            progress = 0.45

            let payloadDir = extractDir.appendingPathComponent("Payload")
            guard fm.fileExists(atPath: payloadDir.path) else {
                throw NSError(domain: "IPACrack", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy Payload/ trong IPA"])
            }

            let appDirs = try fm.contentsOfDirectory(at: payloadDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "app" }
            guard let appDir = appDirs.first else {
                throw NSError(domain: "IPACrack", code: 2, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy .app trong Payload/"])
            }
            append("App: \(appDir.lastPathComponent)")

            let infoPlist = appDir.appendingPathComponent("Info.plist")
            if fm.fileExists(atPath: infoPlist.path) {
                if let dict = NSDictionary(contentsOf: infoPlist) as? [String: Any] {
                    let bundleID = dict["CFBundleIdentifier"] as? String ?? "?"
                    let version = dict["CFBundleShortVersionString"] as? String ?? "?"
                    let minOS = dict["MinimumOSVersion"] as? String ?? "?"
                    append("BundleID: \(bundleID)")
                    append("Version: \(version)")
                    append("MinOS: \(minOS)")
                }
            }
            progress = 0.6

            let binaryURL = appDir.appendingPathComponent(appDir.deletingPathExtension().lastPathComponent)
            if fm.fileExists(atPath: binaryURL.path) {
                let binData = try Data(contentsOf: binaryURL)
                append("Binary: \(ByteCountFormatter.string(fromByteCount: Int64(binData.count), countStyle: .file))")
                if let archs = detectArchitectures(binData) {
                    append("Arch: \(archs.joined(separator: ", "))")
                }
                let strings = extractStrings(binData)
                append("Strings tìm được: \(strings.count)")

                let stringsURL = work.appendingPathComponent("strings.txt")
                try strings.joined(separator: "\n").write(to: stringsURL, atomically: true, encoding: .utf8)

                let headersURL = work.appendingPathComponent("binary_header.txt")
                let headerHex = binData.prefix(4096).map { String(format: "%02x", $0) }.joined(separator: " ")
                try headerHex.write(to: headersURL, atomically: true, encoding: .utf8)
            }
            progress = 0.75

            let frameworksDir = appDir.appendingPathComponent("Frameworks")
            if fm.fileExists(atPath: frameworksDir.path) {
                let frameworks = (try? fm.contentsOfDirectory(at: frameworksDir, includingPropertiesForKeys: nil)) ?? []
                append("Frameworks: \(frameworks.count)")
            }

            let assetsURL = appDir.appendingPathComponent("Assets.car")
            if fm.fileExists(atPath: assetsURL.path) {
                let attrs = try? fm.attributesOfItem(atPath: assetsURL.path)
                let size = (attrs?[.size] as? Int) ?? 0
                append("Assets.car: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))")
            }

            progress = 0.9

            let outputZip = work.appendingPathComponent("\(appDir.deletingPathExtension().lastPathComponent)_src.zip")
            append("Đang đóng gói source...")
            try ZipWriter.zip(directory: appDir, to: outputZip, rootName: appDir.lastPathComponent)
            zipURL = outputZip
            progress = 1.0
            append("HOÀN TẤT")
            status = "Crack xong. Bấm TẢI FILE VỀ để lấy source .zip"
        } catch {
            status = "Lỗi: \(error.localizedDescription)"
            append("LỖI \(error.localizedDescription)")
        }
    }

    private func append(_ s: String) { log.append(s) }

    private func detectArchitectures(_ data: Data) -> [String]? {
        guard data.count >= 12 else { return nil }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        let beMagic = magic.byteSwapped
        let fatMagics: [UInt32] = [0xCAFEBABE, 0xCAFEBABF, 0xBFBAFECA]
        if fatMagics.contains(magic) || fatMagics.contains(beMagic) {
            return ["FAT"]
        }
        var archs: [String] = []
        let cpuType = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
        switch cpuType {
        case 0x0100000C: archs.append("arm64")
        case 0x0000000C: archs.append("armv7")
        case 0x01000007: archs.append("x86_64")
        case 0x00000007: archs.append("i386")
        default: archs.append("unknown 0x\(String(cpuType, radix: 16))")
        }
        return archs
    }

    private func extractStrings(_ data: Data) -> [String] {
        var results: [String] = []
        var current = [UInt8]()
        let minLen = 6

        for byte in data {
            if byte >= 0x20 && byte < 0x7F {
                current.append(byte)
            } else {
                if current.count >= minLen {
                    if let s = String(bytes: current, encoding: .ascii) {
                        results.append(s)
                    }
                }
                current.removeAll(keepingCapacity: true)
            }
            if results.count > 20000 { break }
        }
        if current.count >= minLen, let s = String(bytes: current, encoding: .ascii) {
            results.append(s)
        }
        return results
    }
}

struct IPACrackerView: View {
    @StateObject private var vm = IPACrackVM()
    @State private var showImporter = false
    @State private var showShare = false
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)
    private let violet = Color(red: 0.63, green: 0.4, blue: 1)
    private let orange = Color(red: 1, green: 0.6, blue: 0.25)

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.018, green: 0.025, blue: 0.07),
                Color(red: 0.075, green: 0.025, blue: 0.14),
                Color(red: 0.012, green: 0.075, blue: 0.12)
            ], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CHỌN FILE IPA").font(.system(size: 10, weight: .black, design: .rounded)).tracking(1.2).foregroundStyle(cyan)

                        if vm.fileName.isEmpty {
                            Button { showImporter = true } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: "doc.badge.plus").font(.system(size: 34, weight: .bold)).foregroundStyle(orange)
                                    Text("CHỌN FILE .IPA").font(.system(size: 13, weight: .black))
                                    Text("Upload từ Files hoặc iCloud").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 26)
                                .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(orange.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                                .foregroundStyle(.white)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "shippingbox.fill").foregroundStyle(orange)
                                    Text(vm.fileName).font(.system(size: 12, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                                    Spacer()
                                    Button { vm.fileName = ""; vm.zipURL = nil; vm.log.removeAll(); vm.progress = 0; vm.status = "Chọn file .ipa để bắt đầu." } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                Text(vm.fileSize).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(14).background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
                        }

                        if vm.busy || vm.progress > 0 {
                            ProgressView(value: vm.progress).tint(orange)
                            Text("\(Int(vm.progress * 100))%").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(orange.opacity(0.18), lineWidth: 1))

                    if let zip = vm.zipURL {
                        Button { showShare = true } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("TẢI FILE VỀ (\(zip.lastPathComponent))").font(.system(size: 12, weight: .black))
                            }
                            .frame(maxWidth: .infinity).padding(14)
                            .background(Color.green.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.5), lineWidth: 1))
                            .foregroundStyle(.green)
                        }
                        .sheet(isPresented: $showShare) {
                            ShareSheet(items: [zip])
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRẠNG THÁI").font(.system(size: 10, weight: .black)).foregroundStyle(cyan)
                        Text(vm.status).font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))

                    if !vm.log.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LOG").font(.system(size: 10, weight: .black)).foregroundStyle(violet)
                            ForEach(Array(vm.log.enumerated()), id: \.offset) { _, line in
                                Text(line).font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(18)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("IPA Cracker")
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.ipa, .data, .item],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                Task { await vm.crack(ipa: url) }
            } catch {
                vm.status = "Không đọc được file: \(error.localizedDescription)"
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(orange.opacity(0.14)).frame(width: 48, height: 48)
                Image(systemName: "shippingbox.fill").font(.system(size: 21, weight: .bold)).foregroundStyle(orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("IPA SOURCE CRACKER").font(.system(size: 15, weight: .black, design: .rounded)).tracking(1).foregroundStyle(.white)
                Text("UNZIP STRINGS HEADERS EXPORT").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(orange)
            }
            Spacer()
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
                    infoRow("shippingbox.fill", "IPA Cracker", "Giải nén IPA, trích xuất strings và header binary, đóng gói lại source.")
                } else {
                    infoRow("key.fill", "Bot token", "Không chia sẻ token. Nếu token bị lộ, hãy thu hồi và tạo token mới qua BotFather.")
                    infoRow("externaldrive.fill", "Lưu cục bộ", "Thiết lập được lưu trên thiết bị. Bản hiện tại dùng UserDefaults, không phải kho Keychain.")
                    infoRow("person.3.fill", "Sử dụng có trách nhiệm", "Chỉ phân tích IPA bạn sở hữu hoặc có quyền kiểm thử.")
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

struct ContentView: View {
    @State private var glow = false
    @State private var showAbout = false
    @State private var showSecurity = false
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)
    private let violet = Color(red: 0.63, green: 0.4, blue: 1)
    private let orange = Color(red: 1, green: 0.6, blue: 0.25)

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
                            Text("05 MODULES").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(cyan.opacity(0.8))
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            NavigationLink { TelegramMessageView().toolbar(.visible, for: .navigationBar) } label: {
                                UtilityTile(icon: "paperplane.fill", title: "Gửi tin nhắn", subtitle: "Telegram Bot", accent: cyan, tag: "SỬ DỤNG NGAY")
                            }.buttonStyle(.plain)
                            NavigationLink { IPACrackerView().toolbar(.visible, for: .navigationBar) } label: {
                                UtilityTile(icon: "shippingbox.fill", title: "Crack IPA", subtitle: "Upload .ipa → src", accent: orange, tag: "CRACK")
                            }.buttonStyle(.plain)
                            NavigationLink { WebSourceCrackerView().toolbar(.visible, for: .navigationBar) } label: {
                                UtilityTile(icon: "network", title: "Crack Web Src", subtitle: "Tải full source", accent: Color(red: 1, green: 0.6, blue: 0.25), tag: "CRACK")
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