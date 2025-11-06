import Foundation
import Security

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings: AppSettings
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "appSettings"
    private let apiKeyService = "com.talktoyou.apikey"
    
    private init() {
        self.settings = AppSettings()
        loadSettings()
    }
    
    // MARK: - Load Settings
    func loadSettings() {
        // 从UserDefaults加载设置
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        }
        
        // 从Keychain加载API密钥
        if let apiKey = loadAPIKeyFromKeychain() {
            self.settings.apiKey = apiKey
        }
    }
    
    // MARK: - Save Settings
    func saveSettings() {
        // 保存到UserDefaults
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
        
        // 保存API密钥到Keychain
        saveAPIKeyToKeychain(settings.apiKey)
        
        // 发布更新通知
        objectWillChange.send()
    }
    
    // MARK: - Update Methods
    func updateAPIConfig(apiKey: String, endpoint: String, modelVersion: String) {
        settings.apiKey = apiKey
        settings.apiEndpoint = endpoint
        settings.modelVersion = modelVersion
        saveSettings()
    }
    
    func updateRoleConfig(_ roleConfig: RoleConfig) {
        settings.roleConfig = roleConfig
        saveSettings()
    }
    
    func updateVoiceSettings(voiceId: String, rate: Float, pitch: Float, volume: Float) {
        settings.voiceId = voiceId
        settings.speechRate = rate
        settings.speechPitch = pitch
        settings.speechVolume = volume
        saveSettings()
    }
    
    func updateTTSSettings(language: String, voice: String) {
        settings.ttsLanguage = language
        settings.ttsVoice = voice
        saveSettings()
    }
    
    func updateConversationSettings(contextTurns: Int, temperature: Float, maxTokens: Int) {
        settings.contextTurns = contextTurns
        settings.temperature = temperature
        settings.maxTokens = maxTokens
        saveSettings()
    }
    
    func updateBackgroundSettings(imageName: String?, opacity: Double) {
        settings.backgroundImageName = imageName
        settings.backgroundOpacity = opacity
        saveSettings()
    }
    
    // MARK: - Keychain Operations
    private func saveAPIKeyToKeychain(_ apiKey: String) {
        guard !apiKey.isEmpty else { return }
        
        let data = Data(apiKey.utf8)
        
        // 删除旧的
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // 添加新的
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: "apiKey",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save API key to Keychain: \(status)")
        }
    }
    
    private func loadAPIKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: "apiKey",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    // MARK: - Validation
    func validateAPIKey() -> Bool {
        return !settings.apiKey.isEmpty
    }
    
    func validateSettings() -> (isValid: Bool, error: String?) {
        if settings.apiKey.isEmpty {
            return (false, "请配置API密钥")
        }
        
        if settings.apiEndpoint.isEmpty {
            return (false, "请配置API地址")
        }
        
        if settings.speechRate < 0.4 || settings.speechRate > 0.6 {
            return (false, "语速设置超出范围(0.4-0.6)")
        }
        
        if settings.speechPitch < 0.8 || settings.speechPitch > 1.2 {
            return (false, "音调设置超出范围(0.8-1.2)")
        }
        
        if settings.contextTurns < 5 || settings.contextTurns > 20 {
            return (false, "上下文轮数超出范围(5-20)")
        }
        
        if settings.temperature < 0.7 || settings.temperature > 1.0 {
            return (false, "生成温度超出范围(0.7-1.0)")
        }
        
        return (true, nil)
    }
}
