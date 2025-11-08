import Foundation

// MARK: - 预制角色模型
struct RolePreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var prompt: String
    var personality: String
    var icon: String  // SF Symbol 图标名称
    var color: String // 颜色代码
    var description: String
    var isCustom: Bool
    
    // 语音设置
    var voiceId: String
    var speechRate: Float
    var speechPitch: Float
    var speechVolume: Float
    var ttsLanguage: String
    var ttsVoice: String
    
    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        personality: String,
        icon: String = "person.circle.fill",
        color: String = "blue",
        description: String = "",
        isCustom: Bool = false,
        voiceId: String = "zh-CN",
        speechRate: Float = 1.0,
        speechPitch: Float = 1.0,
        speechVolume: Float = 1.0,
        ttsLanguage: String = "Auto",
        ttsVoice: String = "Cherry"
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.personality = personality
        self.icon = icon
        self.color = color
        self.description = description
        self.isCustom = isCustom
        self.voiceId = voiceId
        self.speechRate = speechRate
        self.speechPitch = speechPitch
        self.speechVolume = speechVolume
        self.ttsLanguage = ttsLanguage
        self.ttsVoice = ttsVoice
    }
    
    // 转换为 RoleConfig
    func toRoleConfig() -> RoleConfig {
        return RoleConfig(
            roleName: name,
            rolePrompt: prompt,
            personality: personality,
            voiceId: voiceId,
            speechRate: speechRate,
            speechPitch: speechPitch,
            speechVolume: speechVolume,
            ttsLanguage: ttsLanguage,
            ttsVoice: ttsVoice
        )
    }
}

// MARK: - 角色预设集合
class RolePresetsManager: ObservableObject {
    static let shared = RolePresetsManager()
    
    @Published var presets: [RolePreset] = []
    @Published var customRoles: [RolePreset] = []
    
    private let userDefaults = UserDefaults.standard
    private let customRolesKey = "customRoles"
    private let presetsKey = "rolePresets"  // 用于保存修改后的预设角色
    
    private init() {
        loadDefaultPresets()
        loadCustomPresets()  // 加载用户修改的预设
        loadCustomRoles()
    }
    
    // MARK: - 加载预制角色
    private func loadDefaultPresets() {
        presets = [
            RolePreset(
                name: "智能助手",
                prompt: "你是一个友好、专业的AI助手，能够帮助用户解答各种问题。",
                personality: "友好、专业、耐心",
                icon: "brain.head.profile",
                color: "blue",
                description: "全能助手，随时为您服务",
                ttsVoice: "Cherry"
            ),
            
            RolePreset(
                name: "知心姐姐",
                prompt: "你是一位温柔体贴的知心姐姐，善于倾听和理解他人的情感，能够给予温暖的建议和鼓励。",
                personality: "温柔、体贴、善解人意",
                icon: "heart.circle.fill",
                color: "pink",
                description: "倾听您的心声，给予温暖",
                ttsVoice: "Cherry"
            ),
            
            RolePreset(
                name: "学习导师",
                prompt: "你是一位经验丰富的学习导师，擅长用简单易懂的方式讲解复杂概念，帮助学生更好地理解和掌握知识。",
                personality: "专业、耐心、启发性",
                icon: "graduationcap.fill",
                color: "green",
                description: "专业指导，助您成长",
                ttsVoice: "Ethan"
            ),
            
            RolePreset(
                name: "幽默大师",
                prompt: "你是一位风趣幽默的对话大师，善于用幽默的方式与人交流，让对话充满欢声笑语。",
                personality: "幽默、风趣、活泼",
                icon: "face.smiling.fill",
                color: "orange",
                description: "带来欢乐，让生活更有趣",
                ttsVoice: "Ryan"
            ),
            
            RolePreset(
                name: "技术专家",
                prompt: "你是一位资深的技术专家，对编程、软件开发和IT技术有深入的理解，能够提供专业的技术指导。",
                personality: "严谨、专业、逻辑清晰",
                icon: "wrench.fill",
                color: "indigo",
                description: "解决技术难题的专家",
                ttsVoice: "Elias"
            ),
            
            RolePreset(
                name: "创意顾问",
                prompt: "你是一位富有创意的顾问，善于激发灵感，提供独特的创意建议和解决方案。",
                personality: "创新、灵活、富有想象力",
                icon: "lightbulb.fill",
                color: "yellow",
                description: "激发灵感，创造无限可能",
                ttsVoice: "Jennifer"
            ),
            
            RolePreset(
                name: "健康顾问",
                prompt: "你是一位专业的健康顾问，了解健康养生知识，能够提供科学的健康建议和生活方式指导。",
                personality: "专业、关怀、科学",
                icon: "heart.text.square.fill",
                color: "red",
                description: "关注健康，享受生活",
                ttsVoice: "Jada"
            ),
            
            RolePreset(
                name: "旅游达人",
                prompt: "你是一位热爱旅行的达人，去过世界各地，能够分享旅游经验、推荐景点和提供旅行建议。",
                personality: "热情、见多识广、乐于分享",
                icon: "airplane.circle.fill",
                color: "teal",
                description: "探索世界，分享旅程",
                ttsVoice: "Sunny"
            ),
            
            RolePreset(
                name: "美食家",
                prompt: "你是一位资深的美食家，对各地美食有深入的了解，能够推荐美食、分享烹饪技巧和饮食文化。",
                personality: "热情、品味独特、善于分享",
                icon: "fork.knife.circle.fill",
                color: "brown",
                description: "品味美食，享受生活",
                ttsVoice: "Li"
            ),
            
            RolePreset(
                name: "数学老师",
                prompt: "你是一位经验丰富的数学老师，擅长用浅显易懂的方式讲解数学概念。你会先了解学生的水平，然后循序渐进地引导学生思考，而不是直接给出答案。你鼓励学生独立思考，培养数学思维。",
                personality: "耐心、严谨、善于引导",
                icon: "function",
                color: "blue",
                description: "耐心讲解数学知识，培养逻辑思维",
                ttsVoice: "Dylan"
            ),
            
            RolePreset(
                name: "心理咨询师",
                prompt: "你是一位专业的心理咨询师，善于倾听和共情。你会创造一个安全、无评判的空间，让来访者自由表达内心感受。你使用专业的心理学知识帮助人们认识自己，处理情绪问题，建立积极的心理状态。",
                personality: "专业、共情、支持",
                icon: "brain.head.profile",
                color: "purple",
                description: "专业心理咨询，倾听内心声音",
                ttsVoice: "Cherry"
            ),
            
            RolePreset(
                name: "英语老师",
                prompt: "你是一位英语老师，擅长帮助学生提高英语水平。你会纠正语法错误，丰富词汇量，提供地道的表达方式。你鼓励学生多用英语交流，在实践中提高语言能力。你的教学风格轻松愉快，让学习变得有趣。",
                personality: "专业、友好、鼓励",
                icon: "character.book.closed.fill",
                color: "green",
                description: "提升英语能力，纠正语法词汇",
                ttsVoice: "Jennifer"
            )
        ]
    }
    
    // 加载用户修改的预设角色
    private func loadCustomPresets() {
        if let data = userDefaults.data(forKey: presetsKey),
           let savedPresets = try? JSONDecoder().decode([RolePreset].self, from: data) {
            // 合并，用户修改的覆盖默认的
            for savedPreset in savedPresets {
                if let index = presets.firstIndex(where: { $0.id == savedPreset.id }) {
                    presets[index] = savedPreset
                }
            }
        }
    }
    
    // 保存预设角色的修改
    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            userDefaults.set(data, forKey: presetsKey)
        }
    }
    
    // MARK: - 加载自定义角色
    private func loadCustomRoles() {
        if let data = userDefaults.data(forKey: customRolesKey),
           let decoded = try? JSONDecoder().decode([RolePreset].self, from: data) {
            customRoles = decoded
        }
    }
    
    // MARK: - 保存自定义角色
    private func saveCustomRoles() {
        if let encoded = try? JSONEncoder().encode(customRoles) {
            userDefaults.set(encoded, forKey: customRolesKey)
        }
    }
    
    // MARK: - 预设角色管理
    func updatePreset(_ role: RolePreset) {
        if let index = presets.firstIndex(where: { $0.id == role.id }) {
            presets[index] = role
            savePresets()
        }
    }
    
    // MARK: - 自定义角色管理
    func addCustomRole(_ role: RolePreset) {
        var customRole = role
        customRole.isCustom = true
        customRoles.append(customRole)
        saveCustomRoles()
    }
    
    // MARK: - 更新自定义角色
    func updateCustomRole(_ role: RolePreset) {
        if let index = customRoles.firstIndex(where: { $0.id == role.id }) {
            customRoles[index] = role
            saveCustomRoles()
        }
    }
    
    // MARK: - 删除自定义角色
    func deleteCustomRole(_ role: RolePreset) {
        customRoles.removeAll { $0.id == role.id }
        saveCustomRoles()
    }
    
    // MARK: - 获取所有角色（预制+自定义）
    func getAllRoles() -> [RolePreset] {
        return presets + customRoles
    }
}
