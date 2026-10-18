import SwiftUI
import Foundation
import UIKit

struct PasterItem: Identifiable, Codable {
    var id = UUID()
    var text: String
}

class PasterViewModel: ObservableObject {
    @Published var items: [PasterItem] = []
    let saveKey = "saved_paster_items_v1"
    
    init() {
        load()
    }
    
    func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([PasterItem].self, from: data) else {
            self.items = [
                PasterItem(text: "Xin chào, mình là Đạt!"),
                PasterItem(text: "Đã chuyển khoản, check giúp mình nhé."),
                PasterItem(text: "Hẹn gặp lại bạn sau.")
            ]
            return
        }
        self.items = decoded
    }
    
    func save() {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(encoded, forKey: saveKey)
    }
    
    func add(text: String) {
        items.append(PasterItem(text: text))
        save()
    }
    
    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }
}

struct ContentView: View {
    @StateObject private var vm = PasterViewModel()
    @State private var showAddSheet = false
    @State private var newText = ""
    @State private var toastMessage: String? = nil
    
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)
    private let violet = Color(red: 0.63, green: 0.4, blue: 1)
    private let panel = Color(red: 0.075, green: 0.09, blue: 0.14)
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.025, blue: 0.05), Color(red: 0.05, green: 0.02, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                
                VStack {
                    List {
                        ForEach(vm.items) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(item.text)
                                    .foregroundStyle(.white)
                                    .font(.system(size: 15))
                                
                                HStack(spacing: 10) {
                                    Button {
                                        UIPasteboard.general.string = item.text
                                        showToast("Đã copy! Sang Zalo ấn giữ -> Paste")
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(cyan.opacity(0.15), in: Capsule())
                                            .foregroundStyle(cyan)
                                    }
                                    
                                    Button {
                                        UIPasteboard.general.string = item.text
                                        openApp(urlStr: "zalo://")
                                    } label: {
                                        Label("Mở Zalo", systemImage: "paperplane.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(violet.opacity(0.15), in: Capsule())
                                            .foregroundStyle(violet)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 8)
                        }
                        .onDelete(perform: vm.delete)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("PASTER HUB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newText = ""
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(cyan)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Nhập nội dung cần lưu")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.gray)
                        
                        TextEditor(text: $newText)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(panel, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                            .frame(height: 150)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(red: 0.02, green: 0.025, blue: 0.05).ignoresSafeArea())
                    .navigationTitle("Thêm nội dung")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Huỷ") { showAddSheet = false }
                                .foregroundStyle(.red)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Lưu") {
                                if !newText.isEmpty {
                                    vm.add(text: newText)
                                }
                                showAddSheet = false
                            }
                            .font(.bold)
                            .foregroundStyle(cyan)
                        }
                    }
                }
                .presentationDetents([.medium])
                .preferredColorScheme(.dark)
            }
            .overlay(alignment: .bottom) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(cyan, in: Capsule())
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }
    
    func openApp(urlStr: String) {
        guard let url = URL(string: urlStr) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            showToast("Chưa cài app Zalo trên máy!")
        }
    }
}