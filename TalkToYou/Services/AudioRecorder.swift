import Foundation
import AVFoundation

// MARK: - Audio Recorder
// 录音并将音频数据发送到 ASR 服务
class AudioRecorder: NSObject {
    static let shared = AudioRecorder()
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    // 音频格式
    private let sampleRate: Double = 16000
    private let channels: AVAudioChannelCount = 1
    
    // 音频缓冲
    private var audioBuffer = Data()
    private let bufferSize = 3200 // 字节，与 Python 代码保持一致
    
    // 音频转换器
    private var audioConverter: AVAudioConverter?
    
    // 状态
    private var isRecording = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 开始录音（只负责音频采集，ASR 连接由 ConversationManager 管理）
    func startRecording(targetLang: String = "en") async throws {
        guard !isRecording else { return }
        
        // 请求录音权限
        let granted = await requestMicrophonePermission()
        guard granted else {
            throw AudioRecorderError.permissionDenied
        }
        
        // 配置音频会话
        try configureAudioSession()
        
        // 启动音频引擎
        try startAudioEngine()
        
        isRecording = true
        print("🎤 开始录音...")
    }
    
    /// 停止录音（只负责停止音频采集，不管理 ASR 任务）
    func stopRecording() async throws {
        guard isRecording else { return }
        
        // 停止音频引擎
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // 发送剩余音频数据
        if !audioBuffer.isEmpty {
            try await ASRService.shared.sendAudioData(audioBuffer)
            audioBuffer.removeAll()
        }
        
        isRecording = false
        print("⏹️ 停止录音")
    }
    
    // MARK: - Private Methods
    
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        // 使用 .playAndRecord 模式，支持同时录音和播放
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)
        print("✅ [录音] 音频会话已配置为 .playAndRecord 模式")
    }
    
    private func startAudioEngine() throws {
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            throw AudioRecorderError.engineInitFailed
        }
        
        inputNode = audioEngine.inputNode
        
        guard let inputNode = inputNode else {
            throw AudioRecorderError.inputNodeNotFound
        }
        
        // 获取输入节点的实际硬件格式
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // 目标格式：16kHz, 单声道, PCM 16-bit
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        ) else {
            throw AudioRecorderError.invalidFormat
        }
        
        // 创建音频转换器
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterInitFailed
        }
        audioConverter = converter
        
        // 使用输入节点的实际格式安装 tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        // 启动引擎
        try audioEngine.start()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter = audioConverter else { return }
        
        // 准备转换后的缓冲区
        let targetFormat = converter.outputFormat
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("⚠️  音频转换错误: \(error)")
            return
        }
        
        // 转换为 Data
        guard let channelData = convertedBuffer.int16ChannelData else { return }
        let channelDataPointer = channelData[0]
        let frameLength = Int(convertedBuffer.frameLength)
        let data = Data(bytes: channelDataPointer, count: frameLength * 2) // 2 bytes per sample (16-bit)
        
        // 添加到缓冲区
        audioBuffer.append(data)
        
        // 当缓冲区达到指定大小时，发送数据
        if audioBuffer.count >= bufferSize {
            let dataToSend = audioBuffer.prefix(bufferSize)
            audioBuffer.removeFirst(bufferSize)
            
            Task {
                do {
                    try await ASRService.shared.sendAudioData(Data(dataToSend))
                } catch {
                    print("❌ 发送音频数据失败: \(error)")
                }
            }
        }
    }
}

// MARK: - Audio Recorder Error
enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case engineInitFailed
    case inputNodeNotFound
    case invalidFormat
    case converterInitFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "麦克风权限被拒绝"
        case .engineInitFailed:
            return "音频引擎初始化失败"
        case .inputNodeNotFound:
            return "未找到音频输入节点"
        case .invalidFormat:
            return "无效的音频格式"
        case .converterInitFailed:
            return "音频转换器初始化失败"
        }
    }
}
