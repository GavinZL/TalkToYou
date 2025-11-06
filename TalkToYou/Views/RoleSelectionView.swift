import SwiftUI

// MARK: - 角色选择主视图
struct RoleSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var rolesManager = RolePresetsManager.shared
    @State private var showingCustomRoleEditor = false
    @State private var selectedRole: RolePreset?
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // 主内容
                ScrollView {
                    VStack(spacing: 24) {
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
                                                selectedRole = role
                                                showingCustomRoleEditor = true
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
                        selectedRole = nil
                        showingCustomRoleEditor = true
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
            .sheet(isPresented: $showingCustomRoleEditor) {
                CustomRoleEditorView(role: selectedRole)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func isRoleSelected(_ role: RolePreset) -> Bool {
        return settingsManager.settings.roleConfig.roleName == role.name
    }
    
    private func selectRole(_ role: RolePreset) {
        let roleConfig = RoleConfig(
            roleName: role.name,
            rolePrompt: role.prompt,
            personality: role.personality
        )
        settingsManager.updateRoleConfig(roleConfig)
        
        // 选择后自动关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
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
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // 图标区域
                ZStack(alignment: .topTrailing) {
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
                    
                    // 选中标记
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 18, height: 18)
                            )
                            .offset(x: 5, y: -5)
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
        }
        .contextMenu {
            if role.isCustom {
                Button(action: {
                    onEdit?()
                }) {
                    Label("编辑", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("删除", systemImage: "trash")
                }
            }
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
    
    @State private var name: String = ""
    @State private var prompt: String = ""
    @State private var personality: String = ""
    @State private var description: String = ""
    @State private var selectedIcon: String = "person.circle.fill"
    @State private var selectedColor: String = "blue"
    
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
                            }
                        }
                    }
                    .padding(.vertical, 8)
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
        .onAppear {
            loadRoleData()
        }
    }
    
    // MARK: - Helper Methods
    private func loadRoleData() {
        if let role = role {
            name = role.name
            prompt = role.prompt
            personality = role.personality
            description = role.description
            selectedIcon = role.icon
            selectedColor = role.color
        }
    }
    
    private func saveRole() {
        let newRole = RolePreset(
            id: role?.id ?? UUID(),
            name: name,
            prompt: prompt,
            personality: personality,
            icon: selectedIcon,
            color: selectedColor,
            description: description,
            isCustom: true
        )
        
        if role == nil {
            // 新建角色
            rolesManager.addCustomRole(newRole)
        } else {
            // 更新角色
            rolesManager.updateCustomRole(newRole)
        }
        
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    RoleSelectionView()
}
