import Foundation

// MARK: - Message Role
enum MessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - Content Type
enum ContentType: String, Codable {
    case text
    case audio
}

// MARK: - Message Model
struct Message: Identifiable, Codable {
    let id: UUID
    let sessionId: UUID
    let role: MessageRole
    let contentType: ContentType
    let textContent: String
    var audioPath: String?
    let createTime: Date
    var duration: TimeInterval?
    
    init(
        id: UUID = UUID(),
        sessionId: UUID,
        role: MessageRole,
        contentType: ContentType = .text,
        textContent: String,
        audioPath: String? = nil,
        createTime: Date = Date(),
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.contentType = contentType
        self.textContent = textContent
        self.audioPath = audioPath
        self.createTime = createTime
        self.duration = duration
    }
}

// MARK: - Session Model
struct Session: Identifiable, Codable {
    let id: UUID
    var title: String
    let createTime: Date
    var updateTime: Date
    var messageCount: Int
    var roleConfig: RoleConfig?
    
    init(
        id: UUID = UUID(),
        title: String = "新对话",
        createTime: Date = Date(),
        updateTime: Date = Date(),
        messageCount: Int = 0,
        roleConfig: RoleConfig? = nil
    ) {
        self.id = id
        self.title = title
        self.createTime = createTime
        self.updateTime = updateTime
        self.messageCount = messageCount
        self.roleConfig = roleConfig
    }
}

// MARK: - Role Configuration
struct RoleConfig: Codable {
    var roleName: String
    var rolePrompt: String
    var personality: String
    
    // 语音设置（从 AppSettings 迁移到角色配置中）
    var voiceId: String
    var speechRate: Float
    var speechPitch: Float
    var speechVolume: Float
    var ttsLanguage: String
    var ttsVoice: String
    
    init(
        roleName: String = "智能助手",
        rolePrompt: String = "你是一个友好的AI助手",
        personality: String = "友好、专业",
        voiceId: String = "zh-CN",
        speechRate: Float = 1.0,
        speechPitch: Float = 1.0,
        speechVolume: Float = 1.0,
        ttsLanguage: String = "Auto",
        ttsVoice: String = "Cherry"
    ) {
        self.roleName = roleName
        self.rolePrompt = rolePrompt
        self.personality = personality
        self.voiceId = voiceId
        self.speechRate = speechRate
        self.speechPitch = speechPitch
        self.speechVolume = speechVolume
        self.ttsLanguage = ttsLanguage
        self.ttsVoice = ttsVoice
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    // API配置
    var apiKey: String
    var apiEndpoint: String
    var modelVersion: String
    
    // 角色设定
    var roleConfig: RoleConfig
    
    // 背景设置
    var backgroundImageName: String?  // 背景图片名称
    var backgroundOpacity: Double     // 背景透明度
    
    // 对话设置
    var contextTurns: Int
    var temperature: Float
    var maxTokens: Int
    
    init(
        apiKey: String = "",
        apiEndpoint: String = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation",
        modelVersion: String = "qwen3-max",
        roleConfig: RoleConfig = RoleConfig(),
        backgroundImageName: String? = nil,
        backgroundOpacity: Double = 0.3,
        contextTurns: Int = 10,
        temperature: Float = 0.8,
        maxTokens: Int = 2000
    ) {
        self.apiKey = apiKey
        self.apiEndpoint = apiEndpoint
        self.modelVersion = modelVersion
        self.roleConfig = roleConfig
        self.backgroundImageName = backgroundImageName
        self.backgroundOpacity = backgroundOpacity
        self.contextTurns = contextTurns
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}
