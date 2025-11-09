import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey: String = ""
    @State private var apiEndpoint: String = ""
    @State private var modelVersion: String = ""
    @State private var contextTurns: Int = 10
    @State private var temperature: Float = 0.8
    @State private var maxTokens: Int = 2000
    
    @State private var showingSaveAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // API配置
                Section("API配置") {
                    SecureField("API密钥", text: $apiKey)
                    TextField("API地址", text: $apiEndpoint)
                    TextField("模型版本", text: $modelVersion)
                }
                
                // 对话设置
                Section("对话设置") {
                    Stepper("上下文轮数: \(contextTurns)", value: $contextTurns, in: 5...20)
                    
                    VStack(alignment: .leading) {
                        Text("生成温度: \(String(format: "%.2f", temperature))")
                        Slider(value: $temperature, in: 0.7...1.0, step: 0.05)
                    }
                    
                    Stepper("最大Tokens: \(maxTokens)", value: $maxTokens, in: 500...4000, step: 500)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSettings()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
            .alert("保存成功", isPresented: $showingSaveAlert) {
                Button("确定") {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Methods
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func loadSettings() {
        let settings = settingsManager.settings
        apiKey = settings.apiKey
        apiEndpoint = settings.apiEndpoint
        modelVersion = settings.modelVersion
        contextTurns = settings.contextTurns
        temperature = settings.temperature
        maxTokens = settings.maxTokens
    }
    
    private func saveSettings() {
        settingsManager.updateAPIConfig(
            apiKey: apiKey,
            endpoint: apiEndpoint,
            modelVersion: modelVersion
        )
        
        settingsManager.updateConversationSettings(
            contextTurns: contextTurns,
            temperature: temperature,
            maxTokens: maxTokens
        )
        
        showingSaveAlert = true
        
        hideKeyboard()
    }
}

#Preview {
    SettingsView()
}
