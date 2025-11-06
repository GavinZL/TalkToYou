import SwiftUI

// MARK: - Chat View
struct ChatView: View {
    @StateObject private var manager = ConversationManager()
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var inputText: String = ""
    @State private var showingSettings = false
    @State private var showingVoiceCall = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // 主内容区域
                VStack(spacing: 0) {
                    // 消息列表
                    MessageListView(messages: manager.messages)
                        .background(
                            Group {
                                if let imageName = settingsManager.settings.backgroundImageName,
                                   !imageName.isEmpty {
                                    Image(imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .opacity(settingsManager.settings.backgroundOpacity)
                                        .ignoresSafeArea()
                                } else {
                                    Color(uiColor: .systemGroupedBackground)
                                }
                            }
                        )
                    
                    // 占位空间，确保输入区域不会贴顶
                    Spacer()
                        .frame(minHeight: 100)  // 最小高度 100pt
                    
                    // 整合的输入控制区域（状态栏 + 输入框 + 功能菜单）
                    ChatInputControlView(
                        inputText: $inputText,
                        conversationState: manager.state,
                        errorMessage: manager.errorMessage,
                        isProcessing: manager.state != .idle,
                        onSend: {
                            manager.sendTextMessage(inputText)
                            inputText = ""
                        },
                        onPhoneCall: {
                            showingVoiceCall = true
                        }
                    )
                }
            }
            .navigationTitle("智能对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingVoiceCall) {
                VoiceCallView(
                    characterName: settingsManager.settings.roleConfig.roleName,
                    characterImageName: settingsManager.settings.backgroundImageName,
                    conversationState: manager.state,
                    errorMessage: manager.errorMessage,
                    onHangup: {
                        // 挂断电话
                        if manager.state == .speaking {
                            manager.stopSpeaking()
                        }
                        if manager.state == .recording {
                            manager.cancelRecording()
                        }
                    },
                    onInterrupt: {
                        // 打断当前播放
                        if manager.state == .speaking {
                            manager.stopSpeaking()
                        }
                    }
                )
                .onAppear {
                    // 进入通话界面后自动开始录音
                    if manager.state == .idle {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            manager.startRecording()
                        }
                    }
                }
            }
            .onAppear {
                if manager.currentSession == nil {
                    manager.startNewSession()
                }
            }
        }
    }
}

// MARK: - Message List View
struct MessageListView: View {
    let messages: [Message]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.textContent)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.createTime.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

// MARK: - Status Bar View
struct StatusBarView: View {
    let state: ConversationState
    let errorMessage: String?
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 状态指示器
            Circle()
                .fill(iconColor)
                .frame(width: 8, height: 8)
                .scaleEffect(shouldAnimate ? (isAnimating ? 1.2 : 1.0) : 1.0)
                .animation(
                    shouldAnimate ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : nil,
                    value: isAnimating
                )
            
            // 状态文字
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // 状态图标
            if state != .idle {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                    .opacity(shouldAnimate ? (isAnimating ? 0.6 : 1.0) : 1.0)
                    .animation(
                        shouldAnimate ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : nil,
                        value: isAnimating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: -1)
        )
        .onAppear {
            isAnimating = true
        }
    }
    
    private var shouldAnimate: Bool {
        state == .thinking || state == .recognizing
    }
    
    private var statusText: String {
        switch state {
        case .idle:
            return "就绪"
        case .recording:
            return "正在录音..."
        case .recognizing:
            return "识别中..."
        case .thinking:
            return "思考中..."
        case .speaking:
            return "播放中..."
        case .error:
            return errorMessage ?? "出错了"
        }
    }
    
    private var iconName: String {
        switch state {
        case .idle:
            return "checkmark.circle.fill"
        case .recording:
            return "mic.fill"
        case .recognizing:
            return "waveform"
        case .thinking:
            return "brain.head.profile"
        case .speaking:
            return "speaker.wave.2.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch state {
        case .idle:
            return .green
        case .recording:
            return .red
        case .recognizing, .thinking:
            return .orange
        case .speaking:
            return .blue
        case .error:
            return .red
        }
    }
}

// MARK: - Chat Input Control View (整合控件)
struct ChatInputControlView: View {
    @Binding var inputText: String
    let conversationState: ConversationState
    let errorMessage: String?
    let isProcessing: Bool
    let onSend: () -> Void
    let onPhoneCall: () -> Void
    
    @State private var showingMoreMenu = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 状态栏
                StatusBarView(
                    state: conversationState,
                    errorMessage: errorMessage
                )
                
                // 输入区域
                TextInputAreaView(
                    inputText: $inputText,
                    isProcessing: isProcessing,
                    onSend: onSend,
                    onPhoneCall: onPhoneCall,
                    onMore: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingMoreMenu.toggle()
                        }
                    }
                )
                //.offset(y: showingMoreMenu ? 0 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingMoreMenu)
                
                // 占位空间（当菜单显示时）
                if showingMoreMenu {
                    Color.clear
                        .frame(height: 280)
                        .transition(.move(edge: .bottom))
                }
            }
            
            // 功能菜单（覆盖在底部）
            if showingMoreMenu {
                MoreMenuOverlay(
                    onDismiss: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingMoreMenu = false
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Text Input Area View (文本模式)
struct TextInputAreaView: View {
    @Binding var inputText: String
    let isProcessing: Bool
    let onSend: () -> Void
    let onPhoneCall: () -> Void
    let onMore: () -> Void
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 电话按钮 - 切换到语音模式
            Button(action: onPhoneCall) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            
            // 文本输入框
            HStack(spacing: 8) {
                TextField("输入消息...", text: $inputText)
                    .focused($isInputFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .disabled(isProcessing)
                    .submitLabel(.send)
                    .onSubmit {
                        if !inputText.isEmpty && !isProcessing {
                            onSend()
                        }
                    }
                
                // 发送按钮
                Button(action: onSend) {
                    Image(systemName: inputText.isEmpty ? "paperplane" : "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || isProcessing)
                .padding(.trailing, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(uiColor: .systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // 更多按钮
            Button(action: onMore) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(uiColor: .systemBackground)
                .opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Record Button (Deprecated - 仅保留兼容性)
struct RecordButton: View {
    let state: ConversationState
    let onStart: () -> Void
    let onStop: () -> Void
    let onStopSpeaking: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Text("请使用电话模式进行语音对话")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
    }
}

// MARK: - More Menu View
struct MoreMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 菜单标题
                HStack {
                    Text("更多功能")
                        .font(.headline)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                
                // 功能按钮网格
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    // 回溯
                    MenuButton(
                        icon: "arrow.counterclockwise",
                        title: "回溯",
                        action: {
                            // TODO: 实现回溯功能
                        }
                    )
                    
                    // 发送图片
                    MenuButton(
                        icon: "photo",
                        title: "发送图片",
                        action: {
                            showingImagePicker = true
                        }
                    )
                    
                    // 心动指令
                    MenuButton(
                        icon: "heart.circle",
                        title: "心动指令",
                        action: {
                            // TODO: 实现心动指令
                        }
                    )
                    
                    // 聊天转小说
                    MenuButton(
                        icon: "book.closed",
                        title: "聊天转小说",
                        action: {
                            // TODO: 实现聊天转小说
                        }
                    )
                    
                    // 小手机内测
                    MenuButton(
                        icon: "bubble.left.and.bubble.right",
                        title: "小手机内测",
                        badge: true,
                        action: {
                            // TODO: 实现小手机内测
                        }
                    )
                }
                .padding()
                .padding(.bottom, 20)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: 350)  // 固定高度，兼容 iOS 13+
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingImagePicker) {
            BackgroundImagePicker()
        }
    }
}

// MARK: - More Menu Overlay (覆盖式菜单)
struct MoreMenuOverlay: View {
    let onDismiss: () -> Void
    @State private var showingImagePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 功能按钮网格
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 20
            ) {
                // 回溯
                MenuButton(
                    icon: "arrow.counterclockwise",
                    title: "回溯",
                    action: {
                        // TODO: 实现回溯功能
                        onDismiss()
                    }
                )
                
                // 发送图片
                MenuButton(
                    icon: "photo",
                    title: "发送图片",
                    action: {
                        showingImagePicker = true
                    }
                )
                
                // 心动指令
                MenuButton(
                    icon: "heart.circle",
                    title: "心动指令",
                    action: {
                        // TODO: 实现心动指令
                        onDismiss()
                    }
                )
                
                // 聊天转小说
                MenuButton(
                    icon: "book.closed",
                    title: "聊天转小说",
                    action: {
                        // TODO: 实现聊天转小说
                        onDismiss()
                    }
                )
                
                // 小手机内测
                MenuButton(
                    icon: "bubble.left.and.bubble.right",
                    title: "小手机内测",
                    badge: true,
                    action: {
                        // TODO: 实现小手机内测
                        onDismiss()
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        )
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showingImagePicker) {
            BackgroundImagePicker()
        }
    }
}

// MARK: - Menu Button
struct MenuButton: View {
    let icon: String
    let title: String
    var badge: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    // 图标背景
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    // 图标
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                        .frame(width: 60, height: 60)
                    
                    // 角标
                    if badge {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .offset(x: 5, y: -5)
                    }
                }
                
                // 标题
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Background Image Picker
struct BackgroundImagePicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    // 预设背景图片列表（需要先添加到 Assets）
    private let backgroundImages = [
        "", // 无背景
        "background1",
        "background2",
        "background3",
        "background4"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 透明度调节
                    VStack(alignment: .leading, spacing: 12) {
                        Text("背景透明度")
                            .font(.headline)
                        
                        HStack {
                            Text("\(Int(settingsManager.settings.backgroundOpacity * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 50)
                            
                            Slider(
                                value: Binding(
                                    get: { settingsManager.settings.backgroundOpacity },
                                    set: { newValue in
                                        settingsManager.updateBackgroundSettings(
                                            imageName: settingsManager.settings.backgroundImageName,
                                            opacity: newValue
                                        )
                                    }
                                ),
                                in: 0.0...1.0,
                                step: 0.05
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .systemBackground))
                    )
                    
                    // 背景图片选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text("选择背景")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(backgroundImages, id: \.self) { imageName in
                                BackgroundImageCell(
                                    imageName: imageName,
                                    isSelected: settingsManager.settings.backgroundImageName == imageName,
                                    onSelect: {
                                        settingsManager.updateBackgroundSettings(
                                            imageName: imageName.isEmpty ? nil : imageName,
                                            opacity: settingsManager.settings.backgroundOpacity
                                        )
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .systemBackground))
                    )
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("背景设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Background Image Cell
struct BackgroundImageCell: View {
    let imageName: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                // 背景预览
                Group {
                    if imageName.isEmpty {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Text("无背景")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            )
                    } else {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                        )
                        .offset(x: -8, y: 8)
                }
            }
        }
    }
}

#Preview {
    ChatView()
}
