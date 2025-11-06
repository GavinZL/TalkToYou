import SwiftUI

// MARK: - 对话界面使用示例
struct ConversationExampleView: View {
    @StateObject private var conversationManager = ConversationManager()
    @State private var inputText = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // 状态显示
            statusView
            
            // 消息列表
            messageList
            
            Spacer()
            
            // 控制按钮
            controlButtons
            
            // 文本输入（可选）
            textInputSection
        }
        .padding()
        .navigationTitle("对话")
        .onAppear {
            conversationManager.startNewSession()
        }
        .onDisappear {
            conversationManager.cleanup()
        }
    }
    
    // MARK: - View Components
    
    private var statusView: some View {
        HStack {
            statusIndicator
            Text(statusText)
                .font(.headline)
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch conversationManager.state {
        case .idle:
            Image(systemName: "circle.fill")
                .foregroundColor(.gray)
        case .recording:
            Image(systemName: "mic.fill")
                .foregroundColor(.red)
                .symbolEffect(.pulse)
        case .recognizing:
            ProgressView()
        case .thinking:
            ProgressView()
        case .speaking:
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(.blue)
                .symbolEffect(.variableColor)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
    
    private var statusText: String {
        switch conversationManager.state {
        case .idle:
            return "等待中"
        case .recording:
            return "正在录音..."
        case .recognizing:
            return "识别中..."
        case .thinking:
            return "思考中..."
        case .speaking:
            return "播放中..."
        case .error(let error):
            return "错误: \(error.localizedDescription)"
        }
    }
    
    private var statusColor: Color {
        switch conversationManager.state {
        case .idle:
            return .gray
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
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(conversationManager.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: conversationManager.messages.count) { _, _ in
                if let lastMessage = conversationManager.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            // 录音按钮
            recordButton
            
            // 停止播放按钮
            if case .speaking = conversationManager.state {
                Button {
                    conversationManager.stopSpeaking()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    @ViewBuilder
    private var recordButton: some View {
        switch conversationManager.state {
        case .idle:
            Button {
                conversationManager.startRecording()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("按住说话")
                        .font(.caption)
                }
            }
            
        case .recording:
            Button {
                conversationManager.stopRecording()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("松开发送")
                        .font(.caption)
                }
            }
            
        default:
            EmptyView()
        }
    }
    
    private var textInputSection: some View {
        HStack {
            TextField("输入消息...", text: $inputText)
                .textFieldStyle(.roundedBorder)
            
            Button {
                sendTextMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.blue)
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func sendTextMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        conversationManager.sendTextMessage(text)
        inputText = ""
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
                Text(message.textContent ?? "")
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationView {
        ConversationExampleView()
    }
}
