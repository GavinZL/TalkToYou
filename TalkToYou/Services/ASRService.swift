import Foundation
import Combine

// MARK: - ASR Service
// 基于阿里云灵积 Gummy WebSocket API 实现
class ASRService: NSObject {
    static let shared = ASRService()
    
    // WebSocket 配置
    private let wsURL = "wss://dashscope.aliyuncs.com/api-ws/v1/inference"
    private var apiKey: String = ""
    
    // WebSocket 连接
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    
    // 任务管理
    private var currentTaskId: String?
    private var isTaskStarted = false
    
    // 心跳保活
    private var heartbeatTimer: Task<Void, Never>?
    private let heartbeatInterval: TimeInterval = 30  // 30秒发送一次心跳
    
    // 音频参数
    private let sampleRate = 16000
    private let format = "pcm"
    
    // 识别结果回调
    var onTranscriptionReceived: ((String, Bool) -> Void)?
    var onTranslationReceived: ((String, String, Bool) -> Void)?
    var onTaskCompleted: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    private override init() {
        super.init()
        loadConfig()
        setupURLSession()
    }
    
    private func loadConfig() {
        // 从 SettingsManager 获取 API Key
        apiKey = SettingsManager.shared.settings.apiKey
        
        // 如果 SettingsManager 中没有，则尝试从环境变量或 UserDefaults 获取
        if apiKey.isEmpty {
            if let key = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"] {
                apiKey = key
            } else if let key = UserDefaults.standard.string(forKey: "DASHSCOPE_API_KEY") {
                apiKey = key
            }
        }
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Public API
    
    /// 设置 API Key
    func configure(apiKey: String) {
        self.apiKey = apiKey
        
        // 同步更新到 SettingsManager
        SettingsManager.shared.settings.apiKey = apiKey
        SettingsManager.shared.saveSettings()
        
        // 也保存到 UserDefaults 作为备用
        UserDefaults.standard.set(apiKey, forKey: "DASHSCOPE_API_KEY")
    }
    
    /// 建立 WebSocket 连接（不发送 run-task）
    func connect() async throws {
        guard !apiKey.isEmpty else {
            throw ASRError.configurationError
        }
        
        // 如果已经连接，直接返回
        if let task = webSocketTask, task.state == .running {
            print("✅ WebSocket 已连接，复用现有连接")
            return
        }
        
        guard let url = URL(string: wsURL) else {
            throw ASRError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("TalkToYou/1.0", forHTTPHeaderField: "user-agent")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-DataInspection")
        
        guard let session = urlSession else {
            throw ASRError.sessionNotInitialized
        }
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // 开始接收消息
        Task {
            await receiveMessages()
        }
        
        // 等待连接建立
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        print("✅ WebSocket 连接已建立")
        
        // 启动心跳保活
        startHeartbeat()
    }
    
    /// 开始新任务（发送 run-task）
    func startTask(targetLang: String = "en", maxEndSilence: Int = 10000) async throws {
        guard webSocketTask != nil, webSocketTask?.state == .running else {
            throw ASRError.notConnected
        }
        
        // 生成任务 ID
        currentTaskId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        isTaskStarted = false
        
        // 发送 run-task 指令
        try await sendRunTask(targetLang: targetLang, maxEndSilence: maxEndSilence)
        
        // 等待 task-started 事件
        try await waitForTaskStarted()
    }
    
    /// 结束当前任务（发送 finish-task，但不断开连接）
    func finishTask() async throws {
        guard let taskId = currentTaskId else {
            throw ASRError.noActiveTask
        }
        
        // 检查连接状态
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            print("⚠️  WebSocket 已断开，跳过 finish-task")
            return
        }
        
        // 发送 finish-task 指令（必须包含完整的 payload 参数）
        let finishMessage: [String: Any] = [
            "header": [
                "task_id": taskId,
                "action": "finish-task",
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "input": [:]
            ]
        ]
        
        do {
            try await sendJSON(finishMessage)
            print("📤 已发送 finish-task 指令（保持连接）")
            
            // 等待 task-finished 事件（最多等待 1 秒）
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            print("⚠️  发送 finish-task 失败: \(error.localizedDescription)")
        }
        
        // 重置任务状态，但不断开连接
        currentTaskId = nil
        isTaskStarted = false
        print("✅ 任务已结束，连接保持")
    }
    
    /// 开始识别任务（兼容旧接口，建立连接 + 开启任务）
    @available(*, deprecated, message: "请使用 connect() 和 startTask() 分开调用")
    func startRecognition(targetLang: String = "en", maxEndSilence: Int = 10000) async throws {
        try await connect()
        try await startTask(targetLang: targetLang, maxEndSilence: maxEndSilence)
    }
    
    /// 结束识别任务（兼容旧接口，结束任务 + 断开连接）
    @available(*, deprecated, message: "请使用 finishTask() 或 disconnect()")
    func finishRecognition() async throws {
        try await finishTask()
        disconnect()
    }
    
    /// 发送音频数据
    func sendAudioData(_ data: Data) async throws {
        guard isTaskStarted else {
            throw ASRError.taskNotStarted
        }
        
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            throw ASRError.notConnected
        }
        
        // 发送二进制音频数据
        let message = URLSessionWebSocketTask.Message.data(data)
        try await webSocketTask.send(message)
    }
    
    /// 关闭连接
    func disconnect() {
        guard webSocketTask != nil else { return }
        
        // 停止心跳
        stopHeartbeat()
        
        // 取消 WebSocket 连接
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        // 重置状态
        currentTaskId = nil
        isTaskStarted = false
        
        print("🔌 已断开 WebSocket 连接")
    }
    
    // MARK: - Private Methods
    
    private func sendRunTask(targetLang: String, maxEndSilence: Int) async throws {
        guard let taskId = currentTaskId else {
            throw ASRError.noActiveTask
        }
        
        let runTaskMessage: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskId,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": "gummy-realtime-v1",
                "input": [
                    "format": format,
                    "sample_rate": sampleRate,
                    "audio_type": "sentence",
                    "translation": [
                        "target_lang": targetLang,
                        "source_lang": "auto"
                    ]
                ],
                "parameters": [
                    "max_end_silence": maxEndSilence,
                    "enable_inverse_text_normalization": true
                ]
            ]
        ]
        
        try await sendJSON(runTaskMessage)
        print("✅ 已发送 run-task 指令 (目标语言: \(targetLang), 静音检测: \(maxEndSilence)ms)")
    }
    
    private func waitForTaskStarted() async throws {
        // 等待最多 5 秒
        let maxWaitTime = 5.0
        let startTime = Date()
        
        while !isTaskStarted {
            if Date().timeIntervalSince(startTime) > maxWaitTime {
                throw ASRError.taskStartTimeout
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    private func sendJSON(_ object: [String: Any]) async throws {
        guard let webSocketTask = webSocketTask else {
            throw ASRError.notConnected
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: object)
        let message = URLSessionWebSocketTask.Message.string(String(data: jsonData, encoding: .utf8)!)
        try await webSocketTask.send(message)
    }
    
    private func receiveMessages() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            while webSocketTask.state == .running {
                let message = try await webSocketTask.receive()
                
                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            // 如果是正常关闭，不报告错误
            if webSocketTask.closeCode == .normalClosure || webSocketTask.closeCode == .goingAway {
                print("🔌 WebSocket 已正常关闭")
                return
            }
            
            // 如果已经断开，不报告错误
            if (error as NSError).code == 57 { // Socket is not connected
                print("🔌 WebSocket 已断开")
                return
            }
            
            print("❌ WebSocket 接收错误: \(error)")
            DispatchQueue.main.async {
                self.onError?(error)
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let header = json["header"] as? [String: Any],
              let event = header["event"] as? String else {
            return
        }
        
        switch event {
        case "task-started":
            isTaskStarted = true
            print("✅ 任务已开启")
            
        case "result-generated":
            handleResult(json)
            
        case "task-finished":
            print("✅ 任务已完成")
            isTaskStarted = false  // 重置任务状态
            onTaskCompleted?()
            // 不自动断开连接，由上层决定
            
        case "task-failed":
            handleError(json)
            isTaskStarted = false  // 重置任务状态
            // 错误时也不自动断开，保留连接供下次使用
            
        default:
            print("⚠️  未知事件: \(event)")
        }
    }
    
    private func handleResult(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any],
              let output = payload["output"] as? [String: Any] else {
            return
        }
        
        // 处理识别结果
        if let transcription = output["transcription"] as? [String: Any],
           let text = transcription["text"] as? String,
           let sentenceEnd = transcription["sentence_end"] as? Bool {
            DispatchQueue.main.async {
                self.onTranscriptionReceived?(text, sentenceEnd)
            }
        }
        
        // 处理翻译结果
        if let translations = output["translations"] as? [[String: Any]] {
            for translation in translations {
                if let lang = translation["lang"] as? String,
                   let text = translation["text"] as? String,
                   let sentenceEnd = translation["sentence_end"] as? Bool {
                    DispatchQueue.main.async {
                        self.onTranslationReceived?(text, lang, sentenceEnd)
                    }
                }
            }
        }
    }
    
    private func handleError(_ json: [String: Any]) {
        guard let header = json["header"] as? [String: Any],
              let errorCode = header["error_code"] as? String,
              let errorMessage = header["error_message"] as? String else {
            return
        }
        
        print("❌ 任务失败: \(errorCode) - \(errorMessage)")
        
        let error = ASRError.apiError(code: errorCode, message: errorMessage)
        DispatchQueue.main.async {
            self.onError?(error)
        }
    }
    
    // MARK: - Heartbeat
    
    /// 启动心跳保活
    private func startHeartbeat() {
        // 停止旧的心跳
        stopHeartbeat()
        
        heartbeatTimer = Task {
            while !Task.isCancelled {
                // 等待心跳间隔
                try? await Task.sleep(nanoseconds: UInt64(heartbeatInterval * 1_000_000_000))
                
                // 检查连接状态
                guard !Task.isCancelled,
                      let webSocketTask = self.webSocketTask,
                      webSocketTask.state == .running else {
                    break
                }
                
                // 发送 ping 心跳
                await sendHeartbeat()
            }
        }
        
        print("💓 心跳保活已启动（间隔: \(Int(heartbeatInterval))秒）")
    }
    
    /// 停止心跳
    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        print("💔 心跳保活已停止")
    }
    
    /// 发送心跳包
    private func sendHeartbeat() async {
        do {
            guard let webSocketTask = webSocketTask else { return }
            
            // 发送 WebSocket Ping 帧
            try await webSocketTask.sendPing { error in
                if let error = error {
                    print("⚠️  心跳发送失败: \(error.localizedDescription)")
                } else {
                    print("💓 心跳 Ping 已发送")
                }
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension ASRService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, 
                   didOpenWithProtocol protocol: String?) {
        print("✅ WebSocket 连接已建立")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, 
                   didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("⚠️  WebSocket 连接已关闭: \(closeCode)")
        self.webSocketTask = nil
        isTaskStarted = false
    }
}

// MARK: - ASR Error
enum ASRError: LocalizedError {
    case configurationError
    case invalidURL
    case notConnected
    case sessionNotInitialized
    case noActiveTask
    case taskNotStarted
    case taskStartTimeout
    case invalidAudioData
    case apiError(code: String, message: String)
    case responseParsingError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .configurationError:
            return "ASR 配置错误，请设置 DASHSCOPE_API_KEY"
        case .invalidURL:
            return "WebSocket URL 无效"
        case .notConnected:
            return "WebSocket 未连接"
        case .sessionNotInitialized:
            return "URLSession 未初始化"
        case .noActiveTask:
            return "没有活跃的任务"
        case .taskNotStarted:
            return "任务尚未开始，请等待 task-started 事件"
        case .taskStartTimeout:
            return "等待任务开启超时"
        case .invalidAudioData:
            return "无效的音频数据"
        case .apiError(let code, let message):
            return "API 错误 [\(code)]: \(message)"
        case .responseParsingError:
            return "响应解析失败"
        case .networkError:
            return "网络连接失败"
        }
    }
}
