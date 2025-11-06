import Foundation
import AVFoundation

// MARK: - TTS Service
class TTSService: NSObject, ObservableObject {
    static let shared = TTSService()
    
    @Published var isSpeaking: Bool = false
    
    private let synthesizer = AVSpeechSynthesizer()
    private let settings = SettingsManager.shared
    private var completionHandler: (() -> Void)?
    
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
        
        // 创建语音请求
        let utterance = AVSpeechUtterance(string: processedText)
        
        // 根据检测到的语言选择语音
        let voice = selectVoice(for: detectedLanguage)
        utterance.voice = voice
        utterance.rate = settings.settings.speechRate
        utterance.pitchMultiplier = settings.settings.speechPitch
        utterance.volume = settings.settings.speechVolume
        
        print("🎙️ [TTS] 语音配置: language=\(voice?.language ?? "unknown"), name=\(voice?.name ?? "unknown"), rate=\(utterance.rate)")
        
        // 设置完成回调
        self.completionHandler = completion
        
        // 开始合成和播放
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    // MARK: - Control Methods
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }
    
    func resume() {
        synthesizer.continueSpeaking()
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
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
