import SwiftUI

// MARK: - 按角色归类的历史对话视图
struct HistoryView: View {
    @State private var sessions: [Session] = []
    @State private var roleGroups: [String: [Session]] = [:]
    @ObservedObject private var rolesManager = RolePresetsManager.shared
    
    private let persistence = PersistenceController.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if roleGroups.isEmpty {
                    // 空状态
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("暂无历史对话")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("开始新对话后将在这里显示")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // 角色列表
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(sortedRoleNames(), id: \.self) { roleName in
                                if let sessions = roleGroups[roleName] {
                                    NavigationLink(destination: RoleHistoryView(
                                        roleName: roleName,
                                        sessions: sessions,
                                        roleIcon: getRoleIcon(roleName),
                                        roleColor: getRoleColor(roleName)
                                    )) {
                                        RoleHistoryCard(
                                            roleName: roleName,
                                            sessionCount: sessions.count,
                                            lastUpdateTime: sessions.first?.updateTime ?? Date(),
                                            icon: getRoleIcon(roleName),
                                            color: getRoleColor(roleName)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("历史对话")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadSessions()
            }
            .refreshable {
                loadSessions()
            }
        }
    }
    
    // MARK: - Methods
    private func loadSessions() {
        sessions = persistence.fetchSessions()
        groupSessionsByRole()
    }
    
    private func groupSessionsByRole() {
        var groups: [String: [Session]] = [:]
        
        for session in sessions {
            let roleName = session.roleConfig?.roleName ?? "智能助手"
            if groups[roleName] == nil {
                groups[roleName] = []
            }
            groups[roleName]?.append(session)
        }
        
        // 按更新时间排序每个角色的会话
        for (key, value) in groups {
            groups[key] = value.sorted { $0.updateTime > $1.updateTime }
        }
        
        roleGroups = groups
    }
    
    private func sortedRoleNames() -> [String] {
        return roleGroups.keys.sorted { key1, key2 in
            let time1 = roleGroups[key1]?.first?.updateTime ?? Date.distantPast
            let time2 = roleGroups[key2]?.first?.updateTime ?? Date.distantPast
            return time1 > time2
        }
    }
    
    private func getRoleIcon(_ roleName: String) -> String {
        let allRoles = rolesManager.getAllRoles()
        return allRoles.first { $0.name == roleName }?.icon ?? "person.circle.fill"
    }
    
    private func getRoleColor(_ roleName: String) -> String {
        let allRoles = rolesManager.getAllRoles()
        return allRoles.first { $0.name == roleName }?.color ?? "blue"
    }
}

// MARK: - 角色历史卡片
struct RoleHistoryCard: View {
    let roleName: String
    let sessionCount: Int
    let lastUpdateTime: Date
    let icon: String
    let color: String
    
    var body: some View {
        HStack(spacing: 16) {
            // 角色图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                colorForName(color),
                                colorForName(color).opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            
            // 角色信息
            VStack(alignment: .leading, spacing: 6) {
                Text(roleName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Label("\(sessionCount) 次对话", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(lastUpdateTime.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorForName(color).opacity(0.2), lineWidth: 1)
        )
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

// MARK: - 角色对话历史视图
struct RoleHistoryView: View {
    let roleName: String
    @State var sessions: [Session]
    let roleIcon: String
    let roleColor: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSession: Session?
    @State private var showingDeleteAlert = false
    @State private var sessionToDelete: Session?
    @State private var showingDeleteAllAlert = false
    
    private let persistence = PersistenceController.shared
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sessions) { session in
                        SessionHistoryCard(
                            session: session,
                            roleColor: roleColor,
                            onTap: {
                                print("[RoleHistoryView] 点击会话: \(session.title), ID: \(session.id)")
                                selectedSession = session
                            },
                            onDelete: {
                                sessionToDelete = session
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle(roleName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive, action: {
                        showingDeleteAllAlert = true
                    }) {
                        Label("删除所有会话", systemImage: "trash.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                }
                .disabled(sessions.isEmpty)
            }
        }
        .fullScreenCover(item: $selectedSession) { session in
            RoleHistoryChatView(session: session)
                .onAppear {
                    print("[RoleHistoryView] 创建 RoleHistoryChatView, session: \(session.title)")
                }
        }
        .alert("删除对话", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
            }
        } message: {
            Text("确定要删除这个对话吗?此操作不可恢复。")
        }
        .alert("删除所有会话", isPresented: $showingDeleteAllAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteAllSessions()
            }
        } message: {
            Text("确定要删除该角色的所有会话吗？此操作不可恢复。")
        }
    }
    
    private func deleteSession(_ session: Session) {
        persistence.deleteSession(session)
        sessions.removeAll { $0.id == session.id }
    }
    
    private func deleteAllSessions() {
        print("[RoleHistoryView] 开始删除角色 \(roleName) 的所有会话，总数: \(sessions.count)")
        
        // 删除所有会话
        for session in sessions {
            persistence.deleteSession(session)
        }
        
        // 清空本地状态
        sessions = []
        
        print("[RoleHistoryView] 角色 \(roleName) 的所有会话已删除")
        
        // 可选：自动返回上一页
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: - 对话历史卡片
struct SessionHistoryCard: View {
    let session: Session
    let roleColor: String
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var messages: [Message] = []
    private let persistence = PersistenceController.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和操作
            HStack {
                Text(session.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 删除按钮
                Button(action: {
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
                
            // 最后一条消息预览
            if !messages.isEmpty, let lastMessage = messages.last {
                Text(lastMessage.textContent)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // 元信息
            HStack {
                Label("\(session.messageCount) 条消息", systemImage: "message")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(session.updateTime.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForName(roleColor).opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            print("[SessionHistoryCard] 卡片被点击: \(session.title)")
            onTap()
        }
        .onAppear {
            loadMessages()
        }
    }
    
    private func loadMessages() {
        messages = persistence.fetchMessages(for: session.id)
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

// MARK: - 历史对话聊天视图（可继续对话）
struct RoleHistoryChatView: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = ConversationManager()
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var inputText: String = ""
    @State private var showingVoiceCall = false
    @State private var showingMoreMenu = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 消息列表
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(manager.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: manager.messages.count) { _ in
                            if let lastMessage = manager.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .background(
                        BackgroundImageHelper.loadBackgroundImage(
                            imageName: settingsManager.settings.backgroundImageName,
                            opacity: settingsManager.settings.backgroundOpacity
                        )
                    )
                    
                    // 整合的输入控制区域
                    ChatInputControlView(
                        inputText: $inputText,
                        conversationState: manager.state,
                        errorMessage: manager.errorMessage,
                        isProcessing: manager.state != .idle,
                        showingMoreMenu: $showingMoreMenu,
                        onSend: {
                            manager.sendTextMessage(inputText)
                            inputText = ""
                        },
                        onPhoneCall: {
                            showingVoiceCall = true
                        }
                    )
                }
                
                // 全屏透明遮罩层
                if showingMoreMenu {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingMoreMenu = false
                            }
                        }
                        .zIndex(1)
                    
                    // 底部菜单
                    VStack {
                        Spacer()
                        MoreMenuOverlay(
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showingMoreMenu = false
                                }
                            }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        print("[HistoryChat] 点击返回按钮")
                        // 清理所有资源和状态
                        cleanupAndDismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("返回")
                                .font(.body)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // 可以添加更多操作按钮，例如：
                    Menu {
                        Button(role: .destructive, action: {
                            // 清除当前会话消息
                            print("[HistoryChat] 清除消息")
                        }) {
                            Label("清除消息", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                    }
                }
            }
            .fullScreenCover(isPresented: $showingVoiceCall) {
                VoiceCallView(
                    characterName: session.roleConfig?.roleName ?? "智能助手",
                    characterImageName: settingsManager.settings.backgroundImageName,
                    conversationState: manager.state,
                    errorMessage: manager.errorMessage,
                    onHangup: {
                        if manager.state == .speaking {
                            manager.stopSpeaking()
                        }
                        if manager.state == .recording {
                            manager.cancelRecording()
                        }
                    },
                    onInterrupt: {
                        if manager.state == .speaking {
                            manager.stopSpeaking()
                        }
                    }
                )
                .onAppear {
                    if manager.state == .idle {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            manager.startRecording()
                        }
                    }
                }
            }
            .onAppear {
                print("[HistoryChat] 视图出现，会话ID: \(session.id)")
                print("[HistoryChat] 会话标题: \(session.title)")
                // 加载会话数据
                manager.loadSession(session)
                print("[HistoryChat] 已加载消息数量: \(manager.messages.count)")
            }
            .onDisappear {
                print("[HistoryChat] 视图消失，清理资源")
                cleanup()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Helper Methods
    
    /// 清理所有状态并返回
    private func cleanupAndDismiss() {
        print("[HistoryChat] 开始清理状态...")
        
        // 1. 停止所有进行中的操作
        if manager.state == .speaking {
            print("[HistoryChat] 停止语音播放")
            manager.stopSpeaking()
        }
        
        if manager.state == .recording {
            print("[HistoryChat] 取消录音")
            manager.cancelRecording()
        }
        
        // 2. 关闭所有弹窗
        if showingVoiceCall {
            print("[HistoryChat] 关闭语音通话界面")
            showingVoiceCall = false
        }
        
        if showingMoreMenu {
            print("[HistoryChat] 关闭更多菜单")
            showingMoreMenu = false
        }
        
        // 3. 清空输入文本
        if !inputText.isEmpty {
            print("[HistoryChat] 清空输入文本")
            inputText = ""
        }
        
        // 4. 执行管理器清理
        cleanup()
        
        // 5. 延迟一点再返回，确保清理完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("[HistoryChat] 返回上一页")
            dismiss()
        }
    }
    
    /// 清理 ConversationManager 资源
    private func cleanup() {
        print("[HistoryChat] 清理 ConversationManager 资源")
        manager.cleanup()
    }
}

#Preview {
    HistoryView()
}
