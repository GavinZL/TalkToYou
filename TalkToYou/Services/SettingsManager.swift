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
        if let data = userDefaults.data(forKey: settingsKey) {
            // 尝试加载新格式
            if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
                self.settings = decoded
            } else {
                // 如果新格式失败，尝试迁移旧数据
                print("⚠️ [设置] 检测到旧版本数据，开始迁移...")
                migrateOldSettings(from: data)
            }
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
        settings.roleConfig.voiceId = voiceId
        settings.roleConfig.speechRate = rate
        settings.roleConfig.speechPitch = pitch
        settings.roleConfig.speechVolume = volume
        saveSettings()
    }
    
    func updateTTSSettings(language: String, voice: String) {
        settings.roleConfig.ttsLanguage = language
        settings.roleConfig.ttsVoice = voice
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
    
    // MARK: - Data Migration
    private func migrateOldSettings(from data: Data) {
        // 定义旧版本的数据结构
        struct OldAppSettings: Codable {
            var apiKey: String
            var apiEndpoint: String
            var modelVersion: String
            var roleConfig: OldRoleConfig
            var voiceId: String
            var speechRate: Float
            var speechPitch: Float
            var speechVolume: Float
            var ttsLanguage: String
            var ttsVoice: String
            var backgroundImageName: String?
            var backgroundOpacity: Double
            var contextTurns: Int
            var temperature: Float
            var maxTokens: Int
        }
        
        struct OldRoleConfig: Codable {
            var roleName: String
            var rolePrompt: String
            var personality: String
        }
        
        // 尝试解析旧数据
        if let oldSettings = try? JSONDecoder().decode(OldAppSettings.self, from: data) {
            print("✅ [迁移] 成功解析旧数据")
            
            // 迁移到新结构：将语音设置移动到 RoleConfig 中
            let newRoleConfig = RoleConfig(
                roleName: oldSettings.roleConfig.roleName,
                rolePrompt: oldSettings.roleConfig.rolePrompt,
                personality: oldSettings.roleConfig.personality,
                voiceId: oldSettings.voiceId,
                speechRate: oldSettings.speechRate,
                speechPitch: oldSettings.speechPitch,
                speechVolume: oldSettings.speechVolume,
                ttsLanguage: oldSettings.ttsLanguage,
                ttsVoice: oldSettings.ttsVoice
            )
            
            self.settings = AppSettings(
                apiKey: oldSettings.apiKey,
                apiEndpoint: oldSettings.apiEndpoint,
                modelVersion: oldSettings.modelVersion,
                roleConfig: newRoleConfig,
                backgroundImageName: oldSettings.backgroundImageName,
                backgroundOpacity: oldSettings.backgroundOpacity,
                contextTurns: oldSettings.contextTurns,
                temperature: oldSettings.temperature,
                maxTokens: oldSettings.maxTokens
            )
            
            // 保存迁移后的数据
            saveSettings()
            print("✅ [迁移] 数据迁移完成，语音设置已移动到角色配置中")
        } else {
            print("❌ [迁移] 无法解析旧数据，使用默认设置")
        }
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
        
        if settings.roleConfig.speechRate < 0 || settings.roleConfig.speechRate > 2.0 {
            return (false, "语速设置超出范围(0-2.0)")
        }
        
        if settings.roleConfig.speechPitch < 0.8 || settings.roleConfig.speechPitch > 1.2 {
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
