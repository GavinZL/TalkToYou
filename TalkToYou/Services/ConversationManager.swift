import Foundation
import Combine

// MARK: - Conversation State
enum ConversationState: Equatable {
    case idle
    case recording
    case recognizing
    case thinking
    case speaking
    case error(Error)
    
    static func == (lhs: ConversationState, rhs: ConversationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.recording, .recording):
            return true
        case (.recognizing, .recognizing):
            return true
        case (.thinking, .thinking):
            return true
        case (.speaking, .speaking):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

// MARK: - Conversation Manager
class ConversationManager: ObservableObject {
    @Published var state: ConversationState = .idle
    @Published var currentSession: Session?
    @Published var messages: [Message] = []
    @Published var errorMessage: String?
    
    private let audioRecorder = AudioRecorder.shared
    private let asrService = ASRService.shared
    private let llmService = LLMService.shared
    private let ttsService = QwenTTSService.shared  // 使用阿里云Qwen3-TTS-Flash
    private let persistence = PersistenceController.shared
    
    // 配置
    var targetLanguage: String = "en" // 默认英语
    
    // ASR 结果缓存
    private var currentTranscription = ""
    private var currentTranslation = ""
    private var isASRTaskActive = false
    private var isASRConnected = false  // 跟踪 WebSocket 连接状态
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        setupASRCallbacks()
        setupTTSCallbacks()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // 监听TTS状态
        ttsService.$isSpeaking
            .sink { [weak self] isSpeaking in
                if isSpeaking {
                    self?.state = .speaking
                } else if self?.state == .speaking {
                    self?.state = .idle
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupASRCallbacks() {
        // 识别结果回调（实时更新）
        asrService.onTranscriptionReceived = { [weak self] text, isComplete in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTranscription = text
                let status = isComplete ? "✅ 完整" : "⏳ 中间"
                print("📝 [ASR回调] 识别结果 [\(status)]: \(text)")
                
                // 当识别完成且有内容时，停止录音并处理
                if isComplete && !self.currentTranscription.isEmpty {
                    print("🚦 [流程] 识别完成，自动停止录音")
                    await self.stopRecordingAndProcess()
                }
            }
        }
        
        // 翻译结果回调（可选）
        asrService.onTranslationReceived = { [weak self] text, lang, isComplete in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTranslation = text
                let status = isComplete ? "✅ 完整" : "⏳ 中间"
                print("🌍 [ASR回调] 翻译结果 [\(lang)] [\(status)]: \(text)")
            }
        }
        
        // 任务完成回调
        asrService.onTaskCompleted = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.isASRTaskActive = false
                print("✅ [ASR回调] 识别任务完成")
            }
        }
        
        // 错误回调
        asrService.onError = { [weak self] error in
            guard let self = self else { return }
            Task { @MainActor in
                self.isASRTaskActive = false
                print("❌ [ASR回调] 错误: \(error.localizedDescription)")
                self.handleError(error)
            }
        }
    }
    
    private func setupTTSCallbacks() {
        // TTS错误回调
        ttsService.onError = { [weak self] error in
            guard let self = self else { return }
            Task { @MainActor in
                print("❌ [TTS回调] 错误: \(error.localizedDescription)")
                self.handleError(error)
                await self.cleanupAfterError()
            }
        }
    }
    
    // MARK: - Session Management
    
    /// 加载或创建当前角色的会话
    /// - Parameter roleConfig: 角色配置，如果为nil则使用当前设置中的角色
    func loadOrCreateSession(for roleConfig: RoleConfig? = nil) {
        let currentRole = roleConfig ?? SettingsManager.shared.settings.roleConfig
        
        print("[Session] 加载或创建会话 - 角色: \(currentRole.roleName)")
        
        // 1. 尝试查找当前角色的最新会话
        let allSessions = persistence.fetchSessions()
        let roleSessions = allSessions.filter { session in
            session.roleConfig?.roleName == currentRole.roleName
        }
        
        if let latestSession = roleSessions.first {
            // 找到最新会话，加载它
            print("[Session] 找到最新会话: \(latestSession.title)")
            loadSession(latestSession)
        } else {
            // 没有找到，创建新会话
            print("[Session] 未找到会话，创建新会话")
            startNewSession(roleConfig: currentRole)
        }
    }
    
    /// 创建新会话
    /// - Parameter roleConfig: 角色配置
    func startNewSession(roleConfig: RoleConfig? = nil) {
        // 如果当前有会话，先保存
        if let session = currentSession, !messages.isEmpty {
            print("[Session] 保存当前会话: \(session.title), 消息数: \(messages.count)")
            // 消息已经在 saveUserMessage 和 saveAssistantMessage 中保存
            // 这里只需要更新会话信息
            var updatedSession = session
            updatedSession.updateTime = Date()
            updatedSession.messageCount = messages.count
            persistence.updateSession(updatedSession)
        }
        
        let role = roleConfig ?? SettingsManager.shared.settings.roleConfig
        let session = persistence.createSession(
            title: "新对话 \(Date().formatted(.dateTime.month().day().hour().minute()))",
            roleConfig: role
        )
        
        currentSession = session
        messages = []  // 清空消息列表
        state = .idle
        
        print("[Session] 创建新会话: \(session.title), 角色: \(role.roleName)")
    }
    
    /// 切换角色（保存当前会话，创建新会话）
    /// - Parameter roleConfig: 新角色配置
    func switchRole(to roleConfig: RoleConfig) {
        print("[Session] 切换角色: \(roleConfig.roleName)")
        
        // 1. 保存当前会话
        if let session = currentSession, !messages.isEmpty {
            print("[Session] 保存上一个角色的会话: \(session.title)")
            var updatedSession = session
            updatedSession.updateTime = Date()
            updatedSession.messageCount = messages.count
            persistence.updateSession(updatedSession)
        }
        
        // 2. 清除消息列表
        messages = []
        print("[Session] 清空消息列表")
        
        // 3. 创建新角色的会话
        startNewSession(roleConfig: roleConfig)
    }
    
    /// 加载历史会话
    /// - Parameter session: 要加载的会话
    func loadSession(_ session: Session) {
        print("[Session] 加载历史会话: \(session.title), ID: \(session.id)")
        
        // 如果当前有不同的会话，先保存
        if let currentSession = currentSession,
           currentSession.id != session.id,
           !messages.isEmpty {
            print("[Session] 保存当前会话后再加载: \(currentSession.title)")
            var updatedSession = currentSession
            updatedSession.updateTime = Date()
            updatedSession.messageCount = messages.count
            persistence.updateSession(updatedSession)
        }
        
        currentSession = session
        messages = persistence.fetchMessages(for: session.id)
        state = .idle
        
        print("[Session] 加载了 \(messages.count) 条消息")
    }
    
    // MARK: - Recording Control
    
    /// 阶段 1：开始录音 & 实时识别
    func startRecording() {
        guard state == .idle || state == .speaking else { return }
        
        Task {
            do {
                print("🎤 ====== [流程] 阶段 1: 开始录音 & 实时识别 ======")
                
                // 如果正在播放，先停止播放
                if state == .speaking {
                    await MainActor.run {
                        ttsService.stop()
                    }
                }
                
                currentTranscription = ""
                currentTranslation = ""
                
                // 1.1 检查并建立 WebSocket 连接（只在未连接时建立）
                if !isASRConnected {
                    print("🔗 [步骤 1.1] 建立 ASR WebSocket 连接...")
                    try await asrService.connect()  // 只建立连接，不发送 run-task
                    isASRConnected = true
                    print("✅ WebSocket 连接已建立")
                } else {
                    print("✅ [复用] WebSocket 连接已存在，无需重新连接")
                }
                
                // 1.2 发送 run-task 开启新任务
                print("📨 [步骤 1.2] 发送 run-task 开启识别任务...")
                try await asrService.startTask(targetLang: targetLanguage, maxEndSilence: 10000)
                isASRTaskActive = true
                print("✅ 识别任务已开启")
                
                // 1.3 开始音频采集
                print("🎵 [步骤 1.3] 开始音频采集与流式传输...")
                try await audioRecorder.startRecording(targetLang: targetLanguage)
                
                await MainActor.run {
                    state = .recording
                    print("✅ [状态] 进入 recording 状态")
                }
            } catch {
                await MainActor.run {
                    isASRConnected = false  // 出错时重置连接状态
                    handleError(error)
                }
            }
        }
    }
    
    /// 自动停止录音并处理（识别完成后自动触发）
    private func stopRecordingAndProcess() async {
        guard state == .recording else { return }
        
        do {
            print("🚦 ====== [流程] 自动停止录音 & 处理识别结果 ======")
            
            await MainActor.run {
                state = .recognizing
                print("⏳ [状态] 进入 recognizing 状态")
            }
            
            // 停止录音
            print("📤 [步骤] 停止音频采集...")
            try await audioRecorder.stopRecording()
            
            // 结束当前 ASR 任务（但不断开 WebSocket 连接）
            if isASRTaskActive {
                print("📨 [步骤] 发送 finish-task 结束任务（保持连接）...")
                try await asrService.finishTask()  // 只结束任务，不断开连接
                isASRTaskActive = false
                print("✅ 任务已结束，WebSocket 连接保持")
            }
            
            // 处理识别结果
            if !currentTranscription.isEmpty {
                await handleASRComplete(text: currentTranscription)
            }
        } catch {
            await MainActor.run {
                handleError(error)
            }
        }
    }
    
    /// 手动完成录音（用户想要结束录音并获取识别结果）
    func finishRecording() {
        Task {
            await stopRecordingAndProcess()
        }
    }
    
    func cancelRecording() {
        Task {
            do {
                try await audioRecorder.stopRecording()
                
                if isASRTaskActive {
                    try await asrService.finishTask()  // 结束任务但保持连接
                    isASRTaskActive = false
                }
                
                await MainActor.run {
                    currentTranscription = ""
                    currentTranslation = ""
                    state = .idle
                }
            } catch {
                await MainActor.run {
                    state = .idle
                }
            }
        }
    }
    
    // MARK: - ASR Processing
    
    /// 阶段 3：处理 ASR 结果，调用 LLM
    private func handleASRComplete(text: String) async {
        print("🧠 ====== [流程] 阶段 3: LLM 大模型处理 ======")
        
        guard !text.isEmpty else {
            await MainActor.run {
                state = .idle
                handleError(NSError(domain: "ASR", code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "未识别到语音内容"]))
            }
            return
        }
        
        // 3.1 保存用户消息
        print("💾 [步骤 3.1] 保存用户消息: \(text)")
        await saveUserMessage(text)
        
        // 3.2 调用 LLM
        print("🤖 [步骤 3.2] 调用 LLM 生成回复...")
        await performLLM(userMessage: text)
        
        // 清空缓存
        await MainActor.run {
            currentTranscription = ""
            currentTranslation = ""
        }
    }
    
    // MARK: - LLM Processing
    
    /// 阶段 4：调用 LLM 生成回复
    /// - Parameters:
    ///   - userMessage: 用户消息
    ///   - enableTTS: 是否启用TTS播报（默认true，文字输入时为false）
    private func performLLM(userMessage: String, enableTTS: Bool = true) async {
        print("🤔 ====== [流程] 阶段 4: LLM 生成回复 ======")
        
        await MainActor.run {
            state = .thinking
            print("🧠 [状态] 进入 thinking 状态")
        }
        
        do {
            // 4.1 调用 LLM API
            print("💬 [步骤 4.1] 发送 LLM 请求...")
            let response = try await llmService.generateResponse(
                userMessage: userMessage,
                conversationHistory: messages,
                roleConfig: currentSession?.roleConfig
            )
            print("✅ [步骤 4.1] LLM 回复: \(response.prefix(50))...")
            
            // 4.2 保存 AI 回复
            print("💾 [步骤 4.2] 保存 AI 消息")
            await saveAssistantMessage(response)
            
            // 4.3 TTS 播放（根据enableTTS参数决定）
            if enableTTS {
                print("🔊 [步骤 4.3] 开始TTS语音播放...")
                await performTTS(text: response)
            } else {
                print("ℹ️ [步骤 4.3] 文字输入模式，跳过TTS播放")
                await MainActor.run {
                    state = .idle
                }
            }
        } catch {
            await MainActor.run {
                print("❌ LLM 错误: \(error.localizedDescription)")
                handleError(error)
            }
            // LLM错误时需要清理状态，避免卡在thinking状态
            await cleanupAfterError()
        }
    }
    
    // MARK: - TTS Processing
    
    /// 阶段 5：语音播放
    private func performTTS(text: String) async {
        print("🔊 ====== [流程] 阶段 5: TTS 语音播放 ======")
        
        await MainActor.run {
            print("🔊 [状态] 开始语音播放")
            ttsService.speak(text) { [weak self] in
                guard let self = self else { return }
                print("✅ [流程] TTS 播放完成")
                
                // TTS 播放完成后，自动重新开始录音
                Task {
                    print("🔄 [流程] 自动重新开始录音")
                    await self.startRecording()
                }
            }
        }
    }
    
    // MARK: - Message Management
    private func saveUserMessage(_ text: String) async {
        guard let sessionId = currentSession?.id else { return }
        
        let message = Message(
            sessionId: sessionId,
            role: .user,
            textContent: text
        )
        
        await MainActor.run {
            messages.append(message)
            persistence.saveMessage(message)
        }
    }
    
    private func saveAssistantMessage(_ text: String) async {
        guard let sessionId = currentSession?.id else { return }
        
        let message = Message(
            sessionId: sessionId,
            role: .assistant,
            textContent: text
        )
        
        await MainActor.run {
            messages.append(message)
            persistence.saveMessage(message)
        }
    }
    
    func sendTextMessage(_ text: String) {
        guard !text.isEmpty, let sessionId = currentSession?.id else { return }
        
        Task {
            // 保存用户消息
            let message = Message(
                sessionId: sessionId,
                role: .user,
                textContent: text
            )
            
            await MainActor.run {
                messages.append(message)
                persistence.saveMessage(message)
            }
            
            // 调用LLM（文字输入不进行TTS播报）
            await performLLM(userMessage: text, enableTTS: false)
        }
    }
    
    // MARK: - Playback Control
    func pauseSpeaking() {
        ttsService.pause()
    }
    
    func resumeSpeaking() {
        ttsService.resume()
    }
    
    func stopSpeaking() {
        ttsService.stop()
        state = .idle
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        state = .error(error)
        errorMessage = error.localizedDescription
        
        // 3秒后重置状态到 idle
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            if case .error = self.state {
                print("✅ [错误恢复] 3秒后自动恢复到 idle 状态")
                self.state = .idle
                self.errorMessage = nil
            }
        }
    }
    
    /// 错误后清理：确保资源释放和状态重置
    private func cleanupAfterError() async {
        print("🧽 [清理] 开始错误后清理...")
        
        // 停止当前正在进行的操作
        do {
            // 如果正在录音，停止录音
            if state == .recording || state == .recognizing {
                try await audioRecorder.stopRecording()
                print("✅ [清理] 录音已停止")
            }
            
            // 如果ASR任务活跃，结束任务
            if isASRTaskActive {
                try await asrService.finishTask()
                isASRTaskActive = false
                print("✅ [清理] ASR任务已结束")
            }
        } catch {
            print("⚠️ [清理] 清理过程出错: \(error.localizedDescription)")
        }
        
        // 停止TTS播放
        await MainActor.run {
            ttsService.stop()
            print("✅ [清理] TTS播放已停止")
        }
        
        // 取消LLM请求
        llmService.cancelCurrentRequest()
        print("✅ [清理] LLM请求已取消")
        
        // 清空缓存
        await MainActor.run {
            currentTranscription = ""
            currentTranslation = ""
            print("✅ [清理] 缓存已清空")
        }
        
        print("✅ [清理] 错误后清理完成")
        
        // 清理完成后立即恢复到 idle 状态
        await MainActor.run {
            if case .error = state {
                print("🔄 [清理] 恢复到 idle 状态")
                state = .idle
                errorMessage = nil
            }
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        cancelRecording()
        stopSpeaking()
        llmService.cancelCurrentRequest()
        
        // 清理时断开 WebSocket 连接
        if isASRConnected {
            asrService.disconnect()
            isASRConnected = false
            print("🔌 [清理] WebSocket 连接已断开")
        }
    }
}
