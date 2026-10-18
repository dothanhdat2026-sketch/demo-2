import SwiftUI
import Foundation

struct PasterItem: Identifiable, Codable {
    var id = UUID()
    var text: String
}

class PasterViewModel: ObservableObject {
    @Published var items: [PasterItem] = []
    
    let appGroupID = "group.com.thanhdat.developer"
    let saveKey = "saved_paster_items"
    
    init() {
        load()
    }
    
    func load() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: saveKey),
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
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let encoded = try? JSONEncoder().encode(items) else { return }
        defaults.set(encoded, forKey: saveKey)
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
    
    private let cyan = Color(red: 0.25, green: 0.9, blue: 1)
    private let panel = Color(red: 0.075, green: 0.09, blue: 0.14)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.02, green: 0.025, blue: 0.05).ignoresSafeArea()
                
                List {
                    ForEach(vm.items) { item in
                        Text(item.text)
                            .foregroundStyle(.white)
                            .font(.system(size: 15))
                            .listRowBackground(panel)
                    }
                    .onDelete(perform: vm.delete)
                }
                .scrollContentBackground(.hidden)
                .padding(.top, 10)
            }
            .navigationTitle("Keyboard Paster")
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
                ToolbarItem(placement: .principal) {
                    Text("PASTER HUB")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(cyan)
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
        }
        .preferredColorScheme(.dark)
    }
}