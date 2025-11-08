import SwiftUI

// MARK: - 角色选择主视图
struct RoleSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var rolesManager = RolePresetsManager.shared
    @State private var editorRole: RolePreset?
    @State private var showingNewRoleEditor = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // 主内容
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 自定义角色区域
                        if !rolesManager.customRoles.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("自定义角色")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ],
                                    spacing: 16
                                ) {
                                    ForEach(rolesManager.customRoles) { role in
                                        RoleCard(
                                            role: role,
                                            isSelected: isRoleSelected(role),
                                            onSelect: {
                                                selectRole(role)
                                            },
                                            onEdit: {
                                                editRole(role)
                                            },
                                            onDelete: {
                                                rolesManager.deleteCustomRole(role)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // 预制角色区域
                        VStack(alignment: .leading, spacing: 12) {
                            Text("预设角色")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ],
                                spacing: 16
                            ) {
                                ForEach(rolesManager.presets) { role in
                                    RoleCard(
                                        role: role,
                                        isSelected: isRoleSelected(role),
                                        onSelect: {
                                            selectRole(role)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 底部留白（为浮动按钮腾出空间）
                        Color.clear
                            .frame(height: 100)
                    }
                    .padding(.top, 20)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                // 浮动的添加按钮
                VStack {
                    Spacer()
                    
                    Button(action: {
                        createNewRole()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            Text("自定义角色")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                        )
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("选择角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editorRole) { role in
                CustomRoleEditorView(role: role)
            }
            .sheet(isPresented: $showingNewRoleEditor) {
                CustomRoleEditorView(role: nil)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func isRoleSelected(_ role: RolePreset) -> Bool {
        return settingsManager.settings.roleConfig.roleName == role.name
    }
    
    private func selectRole(_ role: RolePreset) {
        // 使用 toRoleConfig() 方法转换，包含语音设置
        let roleConfig = role.toRoleConfig()
        settingsManager.updateRoleConfig(roleConfig)
        
        // 选择后自动关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
    
    // 新增：编辑角色的辅助方法
    private func editRole(_ role: RolePreset) {
        print("[DEBUG] editRole called with role: \(role.name)")
        editorRole = role
        print("[DEBUG] editorRole set to: \(editorRole?.name ?? "nil")")
    }
    
    // 新增：创建新角色的辅助方法
    private func createNewRole() {
        showingNewRoleEditor = true
    }
}

// MARK: - 角色卡片
struct RoleCard: View {
    let role: RolePreset
    let isSelected: Bool
    let onSelect: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @State private var showingDeleteConfirmation = false
    @State private var showingVoiceSettings = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // 图标区域
                ZStack {
                    // 图标背景
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    colorForName(role.color),
                                    colorForName(role.color).opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    // 图标
                    Image(systemName: role.icon)
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                    
                    // 选中标记（左上角）
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 18, height: 18)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .offset(x: -5, y: -5)
                    }
                }
                
                // 角色名称
                Text(role.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // 角色描述
                Text(role.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(
                        color: isSelected ? colorForName(role.color).opacity(0.3) : Color.black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? colorForName(role.color) : Color.clear,
                        lineWidth: 2
                    )
            )
            // 右上角菜单按钮
            .overlay(
                Menu {
                    if role.isCustom {
                        // 自定义角色：编辑 + 删除
                        Button(action: {
                            onEdit?()
                        }) {
                            Label("编辑角色", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("删除角色", systemImage: "trash")
                        }
                    } else {
                        // 预设角色：仅语音设置
                        Button(action: {
                            showingVoiceSettings = true
                        }) {
                            Label("语音设置", systemImage: "speaker.wave.2")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 16, height: 16)
                        )
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                , alignment: .topTrailing
            )
        }
        .confirmationDialog(
            "确定删除角色 \"\(role.name)\" 吗？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                onDelete?()
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showingVoiceSettings) {
            RoleVoiceSettingsView(role: role)
        }
    }
    
    // MARK: - Helper Methods
    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "gray", "grey": return .gray
        case "red": return .red
        case "brown": return .brown
        case "pink": return .pink
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "cyan": return .cyan
        case "teal": return .teal
        default: return .blue
        }
    }
}

// MARK: - 自定义角色编辑器
struct CustomRoleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var rolesManager = RolePresetsManager.shared
    
    let role: RolePreset?
    
    @State private var name: String
    @State private var prompt: String
    @State private var personality: String
    @State private var description: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    
    // 语音设置状态
    @State private var voiceId: String
    @State private var speechRate: Float
    @State private var speechPitch: Float
    @State private var speechVolume: Float
    @State private var ttsLanguage: String
    @State private var ttsVoice: String
    
    // 自定义初始化器
    init(role: RolePreset?) {
        print("[DEBUG] CustomRoleEditorView init with role: \(role?.name ?? "nil")")
        self.role = role
        
        // 初始化 @State 变量
        if let role = role {
            // 编辑模式：加载现有数据
            print("[DEBUG] Loading existing role data: \(role.name)")
            _name = State(initialValue: role.name)
            _prompt = State(initialValue: role.prompt)
            _personality = State(initialValue: role.personality)
            _description = State(initialValue: role.description)
            _selectedIcon = State(initialValue: role.icon)
            _selectedColor = State(initialValue: role.color)
            _voiceId = State(initialValue: role.voiceId)
            _speechRate = State(initialValue: role.speechRate)
            _speechPitch = State(initialValue: role.speechPitch)
            _speechVolume = State(initialValue: role.speechVolume)
            _ttsLanguage = State(initialValue: role.ttsLanguage)
            _ttsVoice = State(initialValue: role.ttsVoice)
        } else {
            // 新建模式：使用默认值
            print("[DEBUG] Creating new role with default values")
            _name = State(initialValue: "")
            _prompt = State(initialValue: "")
            _personality = State(initialValue: "")
            _description = State(initialValue: "")
            _selectedIcon = State(initialValue: "person.circle.fill")
            _selectedColor = State(initialValue: "blue")
            _voiceId = State(initialValue: "zh-CN")
            _speechRate = State(initialValue: 1.0)
            _speechPitch = State(initialValue: 1.0)
            _speechVolume = State(initialValue: 1.0)
            _ttsLanguage = State(initialValue: "Auto")
            _ttsVoice = State(initialValue: "Cherry")
        }
    }
    
    // 可选图标列表
    private let iconOptions = [
        "person.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "book.circle.fill",
        "graduationcap.fill",
        "lightbulb.fill",
        "flame.fill",
        "leaf.fill",
        "music.note",
        "camera.fill",
        "paintbrush.fill",
        "wrench.fill"
    ]
    
    // 可选颜色列表
    private let colorOptions = [
        ("blue", Color.blue),
        ("green", Color.green),
        ("red", Color.red),
        ("orange", Color.orange),
        ("purple", Color.purple),
        ("pink", Color.pink),
        ("teal", Color.teal),
        ("indigo", Color.indigo)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // 基本信息
                Section("基本信息") {
                    TextField("角色名称", text: $name)
                    
                    TextField("简短描述", text: $description)
                }
                
                // 性格特点
                Section("性格特点") {
                    TextField("例如：友好、专业、耐心", text: $personality)
                }
                
                // 角色提示词
                Section(header: Text("角色提示词"), footer: Text("这是AI扮演该角色时的核心指导，请详细描述角色的特点、专长和行为方式")) {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 120)
                }
                
                // 外观设置
                Section("外观设置") {
                    // 图标选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择图标")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 12
                        ) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.2))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // 颜色选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择颜色")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ],
                            spacing: 12
                        ) {
                            ForEach(colorOptions, id: \.0) { colorName, color in
                                Button(action: {
                                    selectedColor = colorName
                                }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                                .opacity(selectedColor == colorName ? 1 : 0)
                                        )
                                        .shadow(
                                            color: selectedColor == colorName ? color.opacity(0.5) : .clear,
                                            radius: 4
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 8)
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
                        Text("甘茶 Ryan").tag("Ryan")
                        Text("卡捷琳娜 Katerina").tag("Katerina")
                        Text("墨讲师 Elias").tag("Elias")
                        Text("上海-阿珍 Jada").tag("Jada")
                        Text("北京-晓东 Dylan").tag("Dylan")
                        Text("四川-晴儿 Sunny").tag("Sunny")
                        Text("南京-老李 Li").tag("Li")
                        Text("陕西-秦川 Marcus").tag("Marcus")
                        Text("闽南-阿杰 Roy").tag("Roy")
                        Text("天津-李彼得 Peter").tag("Peter")
                        Text("粤语-阳强 Rocky").tag("Rocky")
                        Text("粤语-阳清 Kiki").tag("Kiki")
                        Text("四川-程川 Eric").tag("Eric")
                    }
                    
                    Picker("语音类型", selection: $voiceId) {
                        Text("中文").tag("zh-CN")
                        Text("英文").tag("en-US")
                    }
                }
                
                // 语音参数
                Section("语音参数") {
                    VStack(alignment: .leading) {
                        Text("语速: \(String(format: "%.2f", speechRate))")
                        Slider(value: $speechRate, in: 0...2.0, step: 0.1)
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
            }
            .navigationTitle(role == nil ? "创建角色" : "编辑角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRole()
                    }
                    .disabled(name.isEmpty || prompt.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func saveRole() {
        let newRole = RolePreset(
            id: role?.id ?? UUID(),
            name: name,
            prompt: prompt,
            personality: personality,
            icon: selectedIcon,
            color: selectedColor,
            description: description,
            isCustom: role?.isCustom ?? true,  // 保留原有的 isCustom 状态，新建默认为 true
            // 使用界面中配置的语音设置
            voiceId: voiceId,
            speechRate: speechRate,
            speechPitch: speechPitch,
            speechVolume: speechVolume,
            ttsLanguage: ttsLanguage,
            ttsVoice: ttsVoice
        )
        
        if role == nil {
            // 新建角色
            rolesManager.addCustomRole(newRole)
        } else {
            // 更新角色（区分自定义和预设）
            if newRole.isCustom {
                rolesManager.updateCustomRole(newRole)
            } else {
                rolesManager.updatePreset(newRole)
            }
        }
        
        dismiss()
    }
}

// MARK: - 角色语音设置视图
struct RoleVoiceSettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var rolesManager = RolePresetsManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    let role: RolePreset
    
    @State private var voiceId: String = "zh-CN"
    @State private var speechRate: Float = 1.0
    @State private var speechPitch: Float = 1.0
    @State private var speechVolume: Float = 1.0
    @State private var ttsLanguage: String = "Auto"
    @State private var ttsVoice: String = "Cherry"
    
    var body: some View {
        NavigationView {
            Form {
                // 角色信息
                Section("角色") {
                    HStack {
                        Image(systemName: role.icon)
                            .font(.system(size: 24))
                            .foregroundColor(colorForName(role.color))
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(role.name)
                                .font(.headline)
                            Text(role.personality)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
                        Text("甘茶 Ryan").tag("Ryan")
                        Text("卡捷琳娜 Katerina").tag("Katerina")
                        Text("墨讲师 Elias").tag("Elias")
                        Text("上海-阿珍 Jada").tag("Jada")
                        Text("北京-晓东 Dylan").tag("Dylan")
                        Text("四川-晴儿 Sunny").tag("Sunny")
                        Text("南京-老李 Li").tag("Li")
                        Text("陕西-秦川 Marcus").tag("Marcus")
                        Text("闽南-阿杰 Roy").tag("Roy")
                        Text("天津-李彼得 Peter").tag("Peter")
                        Text("粤语-阳强 Rocky").tag("Rocky")
                        Text("粤语-阳清 Kiki").tag("Kiki")
                        Text("四川-程川 Eric").tag("Eric")
                    }
                    
                    Picker("语音类型", selection: $voiceId) {
                        Text("中文").tag("zh-CN")
                        Text("英文").tag("en-US")
                    }
                }
                
                // 语音参数
                Section("语音参数") {
                    VStack(alignment: .leading) {
                        Text("语速: \(String(format: "%.2f", speechRate))")
                        Slider(value: $speechRate, in: 0...2.0, step: 0.1)
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
            }
            .navigationTitle("语音设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                    }
                }
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    // MARK: - Helper Methods
    private func loadSettings() {
        voiceId = role.voiceId
        speechRate = role.speechRate
        speechPitch = role.speechPitch
        speechVolume = role.speechVolume
        ttsLanguage = role.ttsLanguage
        ttsVoice = role.ttsVoice
    }
    
    private func saveSettings() {
        // 更新预设角色或自定义角色的语音设置
        var updatedRole = role
        updatedRole.voiceId = voiceId
        updatedRole.speechRate = speechRate
        updatedRole.speechPitch = speechPitch
        updatedRole.speechVolume = speechVolume
        updatedRole.ttsLanguage = ttsLanguage
        updatedRole.ttsVoice = ttsVoice
        
        if role.isCustom {
            // 更新自定义角色
            rolesManager.updateCustomRole(updatedRole)
        } else {
            // 预设角色，使用 updatePreset 方法
            rolesManager.updatePreset(updatedRole)
        }
        
        // 如果是当前选中的角色，同步更新到设置
        if settingsManager.settings.roleConfig.roleName == role.name {
            settingsManager.updateRoleConfig(updatedRole.toRoleConfig())
        }
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "gray", "grey": return .gray
        case "red": return .red
        case "brown": return .brown
        case "pink": return .pink
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "cyan": return .cyan
        case "teal": return .teal
        default: return .blue
        }
    }
}

// MARK: - Preview
#Preview {
    RoleSelectionView()
}
