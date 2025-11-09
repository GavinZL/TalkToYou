import Foundation
import AVFoundation

// MARK: - Qwen TTS Service
class QwenTTSService: NSObject, ObservableObject {
    static let shared = QwenTTSService()
    
    @Published var isSpeaking: Bool = false
    
    private let settings = SettingsManager.shared
    private var session: URLSession
    private var audioPlayer: AVAudioPlayer?
    private var completionHandler: (() -> Void)?
    
    // 用于加速播放的音频引擎组件
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var timePitch: AVAudioUnitTimePitch?
    
    // 错误回调
    var onError: ((Error) -> Void)?
    
    // TTS配置
    private let ttsEndpoint = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
    private let ttsModel = "qwen3-tts-flash"
    
    private override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
        super.init()
    }
    
    // MARK: - Speak
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        // 停止当前播放
        if isSpeaking {
            stop()
        }
        
        // 文本预处理
        let processedText = preprocessText(text)
        print("📝 [Qwen-TTS] 开始语音合成: \(processedText.prefix(50))...")
        
        // 从设置中获取语言和音色（从角色配置中获取）
        let languageType = settings.settings.roleConfig.ttsLanguage
        let voice = settings.settings.roleConfig.ttsVoice
        
        print("🌐 [Qwen-TTS] 配置语言: \(languageType)")
        print("🎙️ [Qwen-TTS] 配置音色: \(voice)")
        
        // 设置完成回调
        self.completionHandler = completion
        
        // 调用TTS API
        Task {
            do {
                // 配置音频会话为播放模式
                try configureAudioSession()
                
                // 调用TTS API获取音频
                let audioData = try await synthesizeSpeech(
                    text: processedText,
                    voice: voice,
                    languageType: languageType
                )
                
                // 播放音频
                await playAudio(audioData)
            } catch {
                await handleError(error)
            }
        }
    }
    
    // MARK: - Control Methods
    func pause() {
        audioPlayer?.pause()
        playerNode?.pause()
    }
    
    func resume() {
        audioPlayer?.play()
        playerNode?.play()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        // 停止音频引擎
        Task { @MainActor in
            stopAudioEngine()
        }
        
        isSpeaking = false
        completionHandler = nil
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        // 如果已经是 .playAndRecord 模式，则不需要重新配置
        if audioSession.category != .playAndRecord {
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("🔊 [Qwen-TTS] 音频会话已配置为播放模式")
        } else {
            print("🔊 [Qwen-TTS] 已处于 .playAndRecord 模式，无需重新配置")
        }
    }
    
    // MARK: - TTS API Call
    private func synthesizeSpeech(text: String, voice: String, languageType: String) async throws -> Data {
        // 检查网络连接
        guard NetworkMonitor.shared.isConnected else {
            throw TTSError.networkUnavailable
        }
        
        // 检查API Key
        let apiKey = settings.settings.apiKey
        guard !apiKey.isEmpty else {
            throw TTSError.authenticationFailed
        }
        
        // 构建请求
        guard let url = URL(string: ttsEndpoint) else {
            throw TTSError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 从角色配置中获取语速参数（0-2范围）
        let speechRate = settings.settings.roleConfig.speechRate
        print("🎵 [Qwen-TTS] 配置语速: \(speechRate)")
        
        // 构建请求体（语速参数可能不被API支持，先尝试不传）
        let requestBody: [String: Any] = [
            "model": ttsModel,
            "input": [
                "text": text,
                "voice": voice,
                "language_type": languageType
                // 注意：Qwen3-TTS-Flash 可能不支持 speech_rate 参数
                // 如果需要语速控制，需要使用音频处理或其他模型
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("📤 [Qwen-TTS] 发送TTS请求...")
        
        // 发送请求
        let (data, response) = try await session.data(for: request)
        
        // 检查HTTP响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }
        
        print("📥 [Qwen-TTS] 收到响应，状态码: \(httpResponse.statusCode)")
        
        // 打印响应头信息
        if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
            print("📄 [Qwen-TTS] Content-Type: \(contentType)")
        }
        
        // 如果是400错误，打印详细错误信息
        if httpResponse.statusCode == 400 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("❌ [Qwen-TTS] 400错误详情: \(errorJson)")
            }
        }
        
        // 处理不同的状态码
        switch httpResponse.statusCode {
        case 200:
            // 解析响应获取音频URL
            return try await downloadAudio(from: data)
        case 400:
            throw TTSError.badRequest
        case 401:
            throw TTSError.authenticationFailed
        case 429:
            throw TTSError.rateLimitExceeded
        case 500...599:
            throw TTSError.serverError
        default:
            throw TTSError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Parse Response & Download Audio
    private func downloadAudio(from responseData: Data) async throws -> Data {
        // 解析响应获取音频URL
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            print("❌ [Qwen-TTS] 无法解析JSON")
            throw TTSError.parseError
        }
        
        // 尝试多种可能的响应格式
        var audioUrlString: String?
        
        // 格式1: {"output": {"audio": {"url": "..."}}} (实际格式)
        if let output = json["output"] as? [String: Any],
           let audio = output["audio"] as? [String: Any],
           let url = audio["url"] as? String {
            audioUrlString = url
            print("✅ [Qwen-TTS] 找到音频URL (output.audio.url格式)")
        }
        // 格式2: {"output": {"audio_url": "..."}} (备用格式)
        else if let output = json["output"] as? [String: Any],
                let url = output["audio_url"] as? String {
            audioUrlString = url
            print("✅ [Qwen-TTS] 找到audio_url (output.audio_url格式)")
        }
        // 格式3: 直接包含URL字段
        else if let url = json["audio_url"] as? String {
            audioUrlString = url
            print("✅ [Qwen-TTS] 找到顶层audio_url")
        }
        
        guard let urlString = audioUrlString,
              let audioUrl = URL(string: urlString) else {
            print("❌ [Qwen-TTS] 未找到有效的音频URL")
            throw TTSError.parseError
        }
        
        print("🔗 [Qwen-TTS] 音频URL: \(audioUrlString)")
        print("⬇️  [Qwen-TTS] 下载音频文件...")
        
        // 下载音频文件
        let (audioData, audioResponse) = try await session.data(from: audioUrl)
        
        guard let httpResponse = audioResponse as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TTSError.downloadFailed
        }
        
        print("✅ [Qwen-TTS] 音频下载成功，大小: \(audioData.count) bytes")
        return audioData
    }
    
    // MARK: - Play Audio
    @MainActor
    private func playAudio(_ audioData: Data) async {
        // 获取配置的语速
        let speedRate = settings.settings.roleConfig.speechRate
        
        // 如果语速 > 1.0，使用 AVAudioEngine 加速播放
        if speedRate > 1.0 {
            await playAudioWithEngine(audioData, speedRate: speedRate)
        } else {
            // 使用原生 AVAudioPlayer
            await playAudioWithPlayer(audioData, speedRate: speedRate)
        }
    }
    
    // MARK: - Play with AVAudioPlayer (原生方式)
    @MainActor
    private func playAudioWithPlayer(_ audioData: Data, speedRate: Float) async {
        do {
            // 创建音频播放器
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.volume = settings.settings.roleConfig.speechVolume
            
            // AVAudioPlayer.rate 只支持 0.5-2.0，但需要先 enableRate
            audioPlayer?.enableRate = true
            if speedRate <= 1.0 {
                // 0.0-1.0 映射到 0.5-1.0
                audioPlayer?.rate = 0.5 + (speedRate * 0.5)
            } else {
                audioPlayer?.rate = speedRate
            }
            
            // 开始播放
            guard let player = audioPlayer, player.prepareToPlay(), player.play() else {
                throw TTSError.playbackFailed
            }
            
            isSpeaking = true
            print("▶️  [Qwen-TTS] 开始播放音频，时长: \(String(format: "%.2f", player.duration))秒，速率: \(String(format: "%.2f", player.rate))x")
        } catch {
            print("❌ [Qwen-TTS] 音频播放失败: \(error.localizedDescription)")
            await handleError(error)
        }
    }
    
    // MARK: - Play with AVAudioEngine (加速播放)
    @MainActor
    private func playAudioWithEngine(_ audioData: Data, speedRate: Float) async {
        do {
            print("🚀 [Qwen-TTS] 使用 AVAudioEngine 进行加速播放: \(speedRate)x")
            
            // 初始化音频引擎组件
            audioEngine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()
            timePitch = AVAudioUnitTimePitch()
            
            guard let engine = audioEngine,
                  let player = playerNode,
                  let timePitch = timePitch else {
                print("❌ [Qwen-TTS] 初始化音频引擎失败")
                // 降级到原生方式
                await playAudioWithPlayer(audioData, speedRate: 1.0)
                return
            }
            
            // 附加节点到引擎
            engine.attach(player)
            engine.attach(timePitch)
            
            // 从音频数据创建 AVAudioFile（自动检测格式：wav/mp3/m4a）
            // 注意：Qwen TTS 返回的是 WAV 格式
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("qwen_tts_temp.wav")
            try audioData.write(to: tempURL)
            
            print("📁 [Qwen-TTS] 临时文件: \(tempURL.lastPathComponent), 大小: \(audioData.count) bytes")
            
            let audioFile = try AVAudioFile(forReading: tempURL)
            let format = audioFile.processingFormat
            
            print("🎵 [Qwen-TTS] 音频格式: \(format.sampleRate)Hz, \(format.channelCount)声道")
            
            // 连接节点: playerNode -> timePitch -> output
            engine.connect(player, to: timePitch, format: format)
            engine.connect(timePitch, to: engine.mainMixerNode, format: format)
            
            // 设置加速倍率（rate 范围: 1/32 到 32）
            timePitch.rate = speedRate
            
            print("🎵 [Qwen-TTS] 设置加速倍率: \(speedRate)x")
            
            // 启动引擎
            try engine.start()
            
            // 播放音频
            player.scheduleFile(audioFile, at: nil) { [weak self] in
                // 播放完成
                DispatchQueue.main.async {
                    self?.isSpeaking = false
                    print("✅ [Qwen-TTS] 加速播放完成")
                    self?.completionHandler?()
                    self?.completionHandler = nil
                    self?.stopAudioEngine()
                    
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: tempURL)
                }
            }
            
            player.play()
            isSpeaking = true
            
            print("▶️  [Qwen-TTS] 开始加速播放 (\(speedRate)x)")
            
        } catch {
            print("❌ [Qwen-TTS] 加速播放失败: \(error.localizedDescription)")
            // 降级到原生方式
            await playAudioWithPlayer(audioData, speedRate: 1.0)
        }
    }
    
    // MARK: - Stop Audio Engine
    @MainActor
    private func stopAudioEngine() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        timePitch = nil
        print("⏹️ [Qwen-TTS] 音频引擎已停止")
    }
    
    // MARK: - Text Preprocessing
    private func preprocessText(_ text: String) -> String {
        var processed = text
        
        // 移除特殊符号和表情
        processed = processed.replacingOccurrences(of: "[emoji]", with: "", options: .regularExpression)
        
        // 处理换行符
        processed = processed.replacingOccurrences(of: "\n", with: " ")
        
        // 移除多余空格（合并连续空格为单个空格）
        processed = processed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 限制文本长度（Qwen3-TTS 最多 600 字符，为安全起见限制为 500 字符）
        // 注意：这里的限制是字符数，而非字节数
        let maxCharacters = 500  // 保守估计，避免超过 API 限制
        
        if processed.count > maxCharacters {
            processed = String(processed.prefix(maxCharacters))
            print("⚠️  [Qwen-TTS] 文本超长（\(text.count) 字符），已截断至 \(maxCharacters) 字符")
        }
        
        // 再次检查实际长度
        print("📏 [Qwen-TTS] 处理后文本长度: \(processed.count) 字符")
        
        return processed
    }
    
    
    // MARK: - Error Handling
    @MainActor
    private func handleError(_ error: Error) async {
        isSpeaking = false
        completionHandler = nil
        
        let errorMessage: String
        if let ttsError = error as? TTSError {
            errorMessage = ttsError.errorDescription ?? "未知错误"
        } else {
            errorMessage = error.localizedDescription
        }
        
        print("❌ [Qwen-TTS] 错误: \(errorMessage)")
        
        // 通知上层错误
        onError?(error)
    }
}

// MARK: - AVAudioPlayerDelegate
extension QwenTTSService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            print("✅ [Qwen-TTS] 播放完成")
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            if let error = error {
                print("❌ [Qwen-TTS] 解码错误: \(error.localizedDescription)")
            }
            self.completionHandler = nil
        }
    }
}

// MARK: - TTS Error
enum TTSError: LocalizedError {
    case networkUnavailable
    case invalidEndpoint
    case authenticationFailed
    case rateLimitExceeded
    case serverError
    case badRequest
    case requestFailed(statusCode: Int)
    case invalidResponse
    case parseError
    case downloadFailed
    case playbackFailed
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "网络不可用，请检查网络连接"
        case .invalidEndpoint:
            return "无效的TTS API地址"
        case .authenticationFailed:
            return "API认证失败，请检查密钥配置"
        case .rateLimitExceeded:
            return "API调用次数超限，请稍后重试"
        case .serverError:
            return "服务器错误，请稍后重试"
        case .badRequest:
            return "请求参数错误"
        case .requestFailed(let statusCode):
            return "请求失败，状态码: \(statusCode)"
        case .invalidResponse:
            return "无效的响应"
        case .parseError:
            return "响应解析失败"
        case .downloadFailed:
            return "音频下载失败"
        case .playbackFailed:
            return "音频播放失败"
        case .timeout:
            return "请求超时，请重试"
        }
    }
}
