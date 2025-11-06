import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey: String = ""
    @State private var apiEndpoint: String = ""
    @State private var modelVersion: String = ""
    @State private var roleName: String = ""
    @State private var rolePrompt: String = ""
    @State private var voiceId: String = ""
    @State private var speechRate: Float = 0.5
    @State private var speechPitch: Float = 1.0
    @State private var speechVolume: Float = 1.0
    @State private var ttsLanguage: String = "Auto"
    @State private var ttsVoice: String = "Cherry"
    @State private var contextTurns: Int = 10
    @State private var temperature: Float = 0.8
    @State private var maxTokens: Int = 2000
    @State private var backgroundImageName: String = ""
    @State private var backgroundOpacity: Double = 0.3
    
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
                
                // 角色设定
                Section("角色设定") {
                    TextField("角色名称", text: $roleName)
                    TextEditor(text: $rolePrompt)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // 语音设置
                Section("语音设置") {
                    // TTS语言选择
                    Picker("播放语言", selection: $ttsLanguage) {
                        Text("自动检测").tag("Auto")
                        Text("中文").tag("Chinese")
                        Text("英语").tag("English")
                        Text("德语").tag("German")
                        Text("意大利语").tag("Italian")
                        Text("葡萄牙语").tag("Portuguese")
                        Text("西班牙语").tag("Spanish")
                        Text("日语").tag("Japanese")
                        Text("韩语").tag("Korean")
                        Text("法语").tag("French")
                        Text("俄语").tag("Russian")
                    }
                    
                    // TTS音色选择
                    Picker("音色", selection: $ttsVoice) {
                        Text("芗悦 Cherry").tag("Cherry")
                        Text("晨煦 Ethan").tag("Ethan")
                        Text("不吃鱼 Nofish").tag("Nofish")
                        Text("詹妮弗 Jennifer").tag("Jennifer")
                        Text("甜茶 Ryan").tag("Ryan")
                        Text("卡捷琳娜 Katerina").tag("Katerina")
                        Text("墨讲师 Elias").tag("Elias")
                        Text("上海-阿珍 Jada").tag("Jada")
                        Text("北京-晓东 Dylan").tag("Dylan")
                        Text("四川-晴儿 Sunny").tag("Sunny")
                        Text("南京-老李 Li").tag("Li")
                        Text("陕西-秦川 Marcus").tag("Marcus")
                        Text("闽南-阿杰 Roy").tag("Roy")
                        Text("天津-李彼得 Peter").tag("Peter")
                        Text("粤语-阺强 Rocky").tag("Rocky")
                        Text("粤语-阺清 Kiki").tag("Kiki")
                        Text("四川-程川 Eric").tag("Eric")
                    }
                    
                    Picker("语音类型", selection: $voiceId) {
                        Text("中文").tag("zh-CN")
                        Text("英文").tag("en-US")
                    }
                    
                    VStack(alignment: .leading) {
                        Text("语速: \(String(format: "%.2f", speechRate))")
                        Slider(value: $speechRate, in: 0.4...0.6, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("音调: \(String(format: "%.2f", speechPitch))")
                        Slider(value: $speechPitch, in: 0.8...1.2, step: 0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("音量: \(String(format: "%.2f", speechVolume))")
                        Slider(value: $speechVolume, in: 0.5...1.0, step: 0.1)
                    }
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
                
                // 背景设置
                Section("背景设置") {
                    TextField("背景图片名称", text: $backgroundImageName)
                        .autocapitalization(.none)
                    
                    VStack(alignment: .leading) {
                        Text("背景透明度: \(String(format: "%.2f", backgroundOpacity))")
                        Slider(value: $backgroundOpacity, in: 0.0...1.0, step: 0.05)
                    }
                    
                    Text("请将图片添加到Assets.xcassets中，然后输入图片名称")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
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
        roleName = settings.roleConfig.roleName
        rolePrompt = settings.roleConfig.rolePrompt
        voiceId = settings.voiceId
        speechRate = settings.speechRate
        speechPitch = settings.speechPitch
        speechVolume = settings.speechVolume
        ttsLanguage = settings.ttsLanguage
        ttsVoice = settings.ttsVoice
        contextTurns = settings.contextTurns
        temperature = settings.temperature
        maxTokens = settings.maxTokens
        backgroundImageName = settings.backgroundImageName ?? ""
        backgroundOpacity = settings.backgroundOpacity
    }
    
    private func saveSettings() {
        settingsManager.updateAPIConfig(
            apiKey: apiKey,
            endpoint: apiEndpoint,
            modelVersion: modelVersion
        )
        
        settingsManager.updateRoleConfig(
            RoleConfig(roleName: roleName, rolePrompt: rolePrompt)
        )
        
        settingsManager.updateVoiceSettings(
            voiceId: voiceId,
            rate: speechRate,
            pitch: speechPitch,
            volume: speechVolume
        )
        
        settingsManager.updateTTSSettings(
            language: ttsLanguage,
            voice: ttsVoice
        )
        
        settingsManager.updateConversationSettings(
            contextTurns: contextTurns,
            temperature: temperature,
            maxTokens: maxTokens
        )
        
        settingsManager.updateBackgroundSettings(
            imageName: backgroundImageName.isEmpty ? nil : backgroundImageName,
            opacity: backgroundOpacity
        )
        
        showingSaveAlert = true
        
        hideKeyboard()
    }
}

#Preview {
    SettingsView()
}
