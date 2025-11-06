import SwiftUI

// MARK: - Voice Call View
struct VoiceCallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    let characterName: String
    let characterImageName: String?
    let conversationState: ConversationState  // 添加对话状态
    let errorMessage: String?  // 添加错误信息
    let onHangup: () -> Void
    let onInterrupt: () -> Void
    
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    
    init(
        characterName: String = "智能助手",
        characterImageName: String? = nil,
        conversationState: ConversationState = .idle,
        errorMessage: String? = nil,
        onHangup: @escaping () -> Void = {},
        onInterrupt: @escaping () -> Void = {}
    ) {
        self.characterName = characterName
        self.characterImageName = characterImageName
        self.conversationState = conversationState
        self.errorMessage = errorMessage
        self.onHangup = onHangup
        self.onInterrupt = onInterrupt
    }
    
    var body: some View {
        ZStack {
            // 背景图片
            if let imageName = characterImageName ?? settingsManager.settings.backgroundImageName,
               !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                // 默认渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            // 半透明遮罩层
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack {
                // 顶部关闭按钮
                HStack {
                    Button(action: {
                        onHangup()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                // 角色名称
                Text(characterName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .padding(.top, 40)
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                
                Spacer()
                
                // 中间提示文字区域
                VStack(spacing: 20) {
                    // 状态图标和文字
                    HStack(spacing: 12) {
                        Image(systemName: stateIcon)
                            .font(.system(size: 24))
                            .foregroundColor(stateIconColor)
                        
                        Text(stateText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                    
                    // 提示文字
                    Text(promptText)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.5))
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 30)
                
                Spacer()
                
                // 底部控制区域
                VStack(spacing: 30) {
                    // "点击打断"文字
                    Button(action: onInterrupt) {
                        Text("点击打断")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    }
                    
                    // 挂断按钮
                    Button(action: {
                        onHangup()
                        dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 70, height: 70)
                                .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimating = true
            pulseAnimation = true
        }
    }
    
    // MARK: - Helper Properties
    private var stateText: String {
        switch conversationState {
        case .idle:
            return "准备就绪"
        case .recording:
            return "正在录音"
        case .recognizing:
            return "识别中"
        case .thinking:
            return "思考中"
        case .speaking:
            return "播放中"
        case .error:
            return "错误"
        }
    }
    
    private var stateIcon: String {
        switch conversationState {
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
    
    private var stateIconColor: Color {
        switch conversationState {
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
    
    private var promptText: String {
        switch conversationState {
        case .idle:
            return "您好，我在听，请说..."
        case .recording:
            return "正在录音，请说出您的问题..."
        case .recognizing:
            return "正在识别你的声音..."
        case .thinking:
            return "让我想想如何回答你..."
        case .speaking:
            return "点击下方\"打断\"可以停止播放"
        case .error:
            return errorMessage ?? "出现了一些问题，请稍后再试"
        }
    }
}

#Preview {
    VoiceCallView(
        characterName: "柳舒瑶",
        conversationState: .speaking
    )
}
