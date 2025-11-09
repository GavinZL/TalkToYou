import SwiftUI
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
                            BackgroundImageHelper.loadBackgroundImage(
                                imageName: settingsManager.settings.backgroundImageName,
                                opacity: settingsManager.settings.backgroundOpacity
                            )
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


#Preview {
    ChatView()
}
