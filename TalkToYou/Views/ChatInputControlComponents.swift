//
//  Untitled.swift
//  TalkToYou
//
//  Created by BIGO on 2025/11/9.
//
import SwiftUI

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

// MARK: - Chat Input Control View
struct ChatInputControlView: View {
    @Binding var inputText: String
    let conversationState: ConversationState
    let errorMessage: String?
    let isProcessing: Bool
    @Binding var showingMoreMenu: Bool
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

// MARK: - Text Input Area View
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
