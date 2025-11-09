import Foundation
import AVFoundation

// MARK: - TTS Service
class TTSService: NSObject, ObservableObject {
    static let shared = TTSService()
    
    @Published var isSpeaking: Bool = false
    
    private let synthesizer = AVSpeechSynthesizer()
    private let settings = SettingsManager.shared
    private var completionHandler: (() -> Void)?
    
    // 用于加速播放的音频引擎组件
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var timePitch: AVAudioUnitTimePitch?
    private var audioBuffer: AVAudioPCMBuffer?
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Speak
    func speak(_ text: String, completion: (() -> Void)? = nil) {
        // 停止当前播放
        if isSpeaking {
            stop()
        }
        
        // 配置音频会话为播放模式（兼容 .playAndRecord 模式）
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // 如果已经是 .playAndRecord 模式，则不需要重新配置
            if audioSession.category != .playAndRecord {
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
                print("🔊 [TTS] 音频会话已配置为播放模式")
            } else {
                print("🔊 [TTS] 已处于 .playAndRecord 模式，无需重新配置")
            }
        } catch {
            print("❌ [TTS] 音频会话配置失败: \(error.localizedDescription)")
        }
        
        // 文本预处理
        let processedText = preprocessText(text)
        print("📝 [TTS] 开始播放: \(processedText.prefix(50))...")
        
        // 智能检测语言并选择合适的语音
        let detectedLanguage = detectLanguage(processedText)
        print("🌐 [TTS] 检测到语言: \(detectedLanguage)")
        
        // 获取配置的语速
        let configuredRate = settings.settings.roleConfig.speechRate
        
        // 判断是否需要使用 AVAudioEngine 进行加速（1.0 以上）
        if configuredRate > 1.0 {
            // 使用 AVAudioEngine 进行时间拉伸加速
            speakWithAudioEngine(processedText, language: detectedLanguage, speedRate: configuredRate, completion: completion)
        } else {
            // 使用原生 AVSpeechSynthesizer
            speakWithSynthesizer(processedText, language: detectedLanguage, speedRate: configuredRate, completion: completion)
        }
    }
    
    // MARK: - Speak with AVSpeechSynthesizer (原生方式)
    private func speakWithSynthesizer(_ text: String, language: String, speedRate: Float, completion: (() -> Void)?) {
        // 创建语音请求
        let utterance = AVSpeechUtterance(string: text)
        
        // 根据检测到的语言选择语音
        let voice = selectVoice(for: language)
        utterance.voice = voice
        
        // 应用语速映射（0.0-2.0 映射到 AVSpeechUtterance 的有效范围）
        let mappedRate: Float
        if speedRate <= 1.0 {
            // 慢速区间: 0.0-1.0 → MinimumSpeechRate 到 DefaultSpeechRate
            mappedRate = AVSpeechUtteranceMinimumSpeechRate + (AVSpeechUtteranceDefaultSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * speedRate
        } else {
            // 快速区间: 1.0-2.0 → DefaultSpeechRate 到 MaximumSpeechRate
            let ratio = speedRate - 1.0
            mappedRate = AVSpeechUtteranceDefaultSpeechRate + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceDefaultSpeechRate) * ratio
        }
        utterance.rate = mappedRate
        
        utterance.pitchMultiplier = settings.settings.roleConfig.speechPitch
        utterance.volume = settings.settings.roleConfig.speechVolume
        
        print("🎙️ [TTS] 语音配置: language=\(voice?.language ?? "unknown"), name=\(voice?.name ?? "unknown")")
        print("🎵 [TTS] 语速参数: 配置值=\(speedRate), 映射值=\(String(format: "%.2f", mappedRate)) (原生AVSpeechSynthesizer)")
        print("🎼 [TTS] 音调=\(settings.settings.roleConfig.speechPitch), 音量=\(settings.settings.roleConfig.speechVolume)")
        
        // 设置完成回调
        self.completionHandler = completion
        
        // 开始合成和播放
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    // MARK: - Speak with AVAudioEngine (时间拉伸加速)
    private func speakWithAudioEngine(_ text: String, language: String, speedRate: Float, completion: (() -> Void)?) {
        print("🚀 [TTS] 使用 AVAudioEngine 进行加速播放: \(speedRate)x")
        
        // 保存完成回调
        self.completionHandler = completion
        
        // 创建语音请求
        let utterance = AVSpeechUtterance(string: text)
        let voice = selectVoice(for: language)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate  // 使用正常速度生成
        utterance.pitchMultiplier = settings.settings.roleConfig.speechPitch
        utterance.volume = settings.settings.roleConfig.speechVolume
        
        // 使用 AVSpeechSynthesizer 的输出作为音频源
        // 方案：先生成音频，然后用 AVAudioEngine 加速播放
        
        // 初始化音频引擎组件
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        timePitch = AVAudioUnitTimePitch()
        
        guard let engine = audioEngine,
              let player = playerNode,
              let timePitch = timePitch else {
            print("❌ [TTS] 初始化音频引擎失败")
            // 降级到原生方式
            speakWithSynthesizer(text, language: language, speedRate: 1.0, completion: completion)
            return
        }
        
        // 附加节点到引擎
        engine.attach(player)
        engine.attach(timePitch)
        
        // 设置音频格式
        let format = AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1)!
        
        // 连接节点: playerNode -> timePitch -> output
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        
        // 设置加速倍率（rate 范围: 1/32 到 32）
        timePitch.rate = speedRate
        
        print("🎵 [TTS] 设置加速倍率: \(speedRate)x")
        
        // 配置音频会话
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            print("❌ [TTS] 音频会话配置失败: \(error.localizedDescription)")
        }
        
        // 启动引擎
        do {
            try engine.start()
            print("✅ [TTS] 音频引擎已启动")
        } catch {
            print("❌ [TTS] 启动音频引擎失败: \(error.localizedDescription)")
            // 降级到原生方式
            speakWithSynthesizer(text, language: language, speedRate: 1.0, completion: completion)
            return
        }
        
        // 使用 AVSpeechSynthesizer 生成音频数据并实时送入 AVAudioEngine
        synthesizer.write(utterance) { [weak self] buffer in
            guard let self = self,
                  let pcmBuffer = buffer as? AVAudioPCMBuffer,
                  let player = self.playerNode else {
                return
            }
            
            // 调度 buffer 到播放器
            player.scheduleBuffer(pcmBuffer, completionHandler: nil)
            
            // 如果是第一次接收到 buffer，开始播放
            if !player.isPlaying {
                player.play()
                DispatchQueue.main.async {
                    self.isSpeaking = true
                    print("▶️  [TTS] 开始加速播放 (\(speedRate)x)")
                }
            }
        }
    }
    
    // MARK: - Control Methods
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        playerNode?.pause()
    }
    
    func resume() {
        synthesizer.continueSpeaking()
        playerNode?.play()
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        
        // 停止音频引擎
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        timePitch = nil
        audioBuffer = nil
        
        isSpeaking = false
        completionHandler = nil
    }
    
    // MARK: - Text Preprocessing
    private func preprocessText(_ text: String) -> String {
        var processed = text
        
        // 移除特殊符号和表情
        processed = processed.replacingOccurrences(of: "[emoji]", with: "", options: .regularExpression)
        
        // 移除常见标点符号（中英文）
        let punctuations = ["."]
        
        for punctuation in punctuations {
            processed = processed.replacingOccurrences(of: punctuation, with: " ")
        }
        
        // 处理换行符
        processed = processed.replacingOccurrences(of: "\n", with: " ")
        
        // 移除多余空格（合并连续空格为单个空格）
        processed = processed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Language Detection
    
    /// 智能检测文本主要语言
    private func detectLanguage(_ text: String) -> String {
        // 统计中文字符数
        let chineseCharCount = text.filter { char in
            let scalar = char.unicodeScalars.first!
            return (0x4E00...0x9FFF).contains(scalar.value) // 中文汉字 Unicode 范围
        }.count
        
        // 统计英文字母数
        let englishCharCount = text.filter { $0.isLetter && $0.isASCII }.count
        
        // 总字符数
        let totalChars = text.filter { !$0.isWhitespace }.count
        
        guard totalChars > 0 else {
            return "en-US" // 默认英语
        }
        
        let chineseRatio = Double(chineseCharCount) / Double(totalChars)
        let englishRatio = Double(englishCharCount) / Double(totalChars)
        
        print("📊 [TTS] 语言分析: 中文\(Int(chineseRatio*100))%, 英文\(Int(englishRatio*100))%")
        
        // 判断主要语言（超过50%）
        if chineseRatio > 0.5 {
            return "zh-CN" // 中文
        } else if englishRatio > 0.3 {
            return "en-US" // 英语
        } else {
            // 混合文本，选择占比较高的
            return chineseRatio > englishRatio ? "zh-CN" : "en-US"
        }
    }
    
    /// 根据语言选择最佳语音
    private func selectVoice(for language: String) -> AVSpeechSynthesisVoice? {
        // 先尝试使用检测到的语言
        if let voice = AVSpeechSynthesisVoice(language: language) {
            print("✅ [TTS] 使用 \(language) 语音: \(voice.name)")
            return voice
        }
        
        // 如果检测到的语音不可用，尝试备用方案
        let fallbackLanguages: [String]
        if language.hasPrefix("zh") {
            fallbackLanguages = ["zh-CN", "zh-TW", "zh-HK", "en-US"]
        } else {
            fallbackLanguages = ["en-US", "en-GB", "zh-CN"]
        }
        
        for fallback in fallbackLanguages {
            if let voice = AVSpeechSynthesisVoice(language: fallback) {
                print("⚠️  [TTS] 使用备用语音: \(fallback) - \(voice.name)")
                return voice
            }
        }
        
        // 最后使用系统默认语音
        let defaultVoice = AVSpeechSynthesisVoice.speechVoices().first
        print("⚠️  [TTS] 使用系统默认语音: \(defaultVoice?.language ?? "unknown")")
        return defaultVoice
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.completionHandler = nil
        }
    }
}
