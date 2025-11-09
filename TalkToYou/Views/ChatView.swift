import SwiftUI
import PhotosUI

// MARK: - Chat View
struct ChatView: View {
    @StateObject private var manager = ConversationManager()
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var inputText: String = ""
    @State private var showingSettings = false
    @State private var showingVoiceCall = false
    @State private var showingRoleSelection = false
    @State private var showingMoreMenu = false  // 提升到 ChatView 层级
    
    var body: some View {
        NavigationView {
            ZStack {
                // 主内容区域
                VStack(spacing: 0) {
                    // 消息列表
                    MessageListView(messages: manager.messages)
                        .background(
                            Group {
                                if let imageName = settingsManager.settings.backgroundImageName,
                                   !imageName.isEmpty {
                                    // 尝试从文档目录加载（自定义图片）
                                    if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                                       let image = UIImage(contentsOfFile: documentsPath.appendingPathComponent(imageName).path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .opacity(settingsManager.settings.backgroundOpacity)
                                            .ignoresSafeArea()
                                    }
                                    // 尝试从 Bundle 加载（预设图片）
                                    else if let imagesURL = Bundle.main.url(forResource: "Images", withExtension: nil),
                                            let imageURL = URL(string: imageName, relativeTo: imagesURL),
                                            let image = UIImage(contentsOfFile: imageURL.path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .opacity(settingsManager.settings.backgroundOpacity)
                                            .ignoresSafeArea()
                                    } else {
                                        Color(uiColor: .systemGroupedBackground)
                                    }
                                } else {
                                    Color(uiColor: .systemGroupedBackground)
                                }
                            }
                        )
                    
                    // 整合的输入控制区域（状态栏 + 输入框 + 功能菜单）
                    ChatInputControlView(
                        inputText: $inputText,
                        conversationState: manager.state,
                        errorMessage: manager.errorMessage,
                        isProcessing: manager.state != .idle,
                        showingMoreMenu: $showingMoreMenu,  // 传递 binding
                        onSend: {
                            manager.sendTextMessage(inputText)
                            inputText = ""
                        },
                        onPhoneCall: {
                            showingVoiceCall = true
                        }
                    )
                }
                
                // 全屏透明遮罩层（在 ChatView 层级）
                if showingMoreMenu {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: UIConstants.Animation.springResponse, dampingFraction: UIConstants.Animation.springDamping)) {
                                showingMoreMenu = false
                            }
                        }
                        .zIndex(1)
                    
                    // 底部菜单
                    VStack {
                        Spacer()
                        MoreMenuOverlay(
                            onDismiss: {
                                withAnimation(.spring(response: UIConstants.Animation.springResponse, dampingFraction: UIConstants.Animation.springDamping)) {
                                    showingMoreMenu = false
                                }
                            }
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .navigationTitle("智能对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingRoleSelection = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text(settingsManager.settings.roleConfig.roleName)
                                .font(.subheadline)
                        }
                    }
                }
                
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
            .sheet(isPresented: $showingRoleSelection) {
                RoleSelectionView()
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
    @Binding var showingMoreMenu: Bool  // 改为 Binding
    let onSend: () -> Void
    let onPhoneCall: () -> Void
    
    var body: some View {
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
                    withAnimation(.spring(response: UIConstants.Animation.springResponse, dampingFraction: UIConstants.Animation.springDamping)) {
                        showingMoreMenu.toggle()
                    }
                }
            )
            
            // 占位空间（当菜单显示时）
            if showingMoreMenu {
                Color.clear
                    .frame(height: UIConstants.Layout.moreMenuHeight)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: UIConstants.Animation.springResponse, dampingFraction: UIConstants.Animation.springDamping), value: showingMoreMenu)
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
        .padding(.horizontal, UIConstants.Spacing.standard)
        .padding(.vertical, UIConstants.Spacing.itemSpacing)
        .background(
            Color(uiColor: .systemBackground)
                .opacity(UIConstants.Opacity.highTransparent)
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


// MARK: - More Menu Overlay (覆盖式菜单)
struct MoreMenuOverlay: View {
    let onDismiss: () -> Void
    @State private var showingImagePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 功能按钮网格
            HStack {
                // 背景设置按钮（左上角）
                MenuButton(
                    icon: "photo",
                    title: "背景",
                    action: {
                        showingImagePicker = true
                    }
                )
                
                Spacer()
            }
            .padding(.horizontal, UIConstants.Spacing.large)
            .padding(.top, UIConstants.Spacing.gridSpacing)
            .padding(.bottom, UIConstants.Spacing.gridSpacing)

            Spacer()
        }
        .frame(height: UIConstants.Layout.moreMenuHeight)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: UIConstants.Layout.largeCornerRadius)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(UIConstants.Opacity.shadow), radius: 10, y: -5)
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
                    RoundedRectangle(cornerRadius: UIConstants.Layout.cornerRadius)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: UIConstants.Button.menuButtonSize, height: UIConstants.Button.menuButtonSize)
                    
                    // 图标
                    Image(systemName: icon)
                        .font(.system(size: UIConstants.Button.iconSize))
                        .foregroundColor(.primary)
                        .frame(width: UIConstants.Button.menuButtonSize, height: UIConstants.Button.menuButtonSize)
                    
                    // 角标
                    if badge {
                        Circle()
                            .fill(Color.red)
                            .frame(width: UIConstants.Button.badgeSize, height: UIConstants.Button.badgeSize)
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

#Preview {
    ChatView()
}
