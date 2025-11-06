import Foundation
import onnxruntime_objc

/// SenseVoice ONNX Runtime 集成示例
/// 使用 onnxruntime-objc 在 iOS 中运行 SenseVoice 模型

class SenseVoiceONNXModel {
    
    // MARK: - Properties
    
    private var session: ORTSession?
    private let modelPath: String
    
    // 模型信息
    private let sampleRate: Int = 16000
    private let maxAudioLength: Int = 30  // 秒
    
    // MARK: - Initialization
    
    init(modelPath: String) {
        self.modelPath = modelPath
        loadModel()
    }
    
    private func loadModel() {
        do {
            // 创建 ONNX Runtime 环境
            let env = try ORTEnv(loggingLevel: .warning)
            
            // 配置 Session
            let options = try ORTSessionOptions()
            options.logSeverityLevel = .warning
            
            // 使用所有可用的计算单元
            // 注意: ONNX Runtime 会自动选择最佳执行提供者
            try options.setGraphOptimizationLevel(.all)
            
            // 加载模型
            session = try ORTSession(
                env: env,
                modelPath: modelPath,
                sessionOptions: options
            )
            
            print("✅ SenseVoice ONNX 模型加载成功")
            
            // 打印模型信息
            printModelInfo()
            
        } catch {
            print("❌ 模型加载失败: \(error)")
        }
    }
    
    private func printModelInfo() {
        guard let session = session else { return }
        
        do {
            let inputNames = try session.inputNames()
            let outputNames = try session.outputNames()
            
            print("\n📊 模型信息:")
            print("输入: \(inputNames)")
            print("输出: \(outputNames)")
        } catch {
            print("获取模型信息失败: \(error)")
        }
    }
    
    // MARK: - Audio Preprocessing
    
    /// 预处理音频数据
    /// - Parameter audioData: PCM 音频数据 (16kHz, 16bit, mono)
    /// - Returns: 预处理后的特征
    func preprocessAudio(_ audioData: Data) -> ([Float], [Int64], [Int64])? {
        // 1. 将 Data 转换为 Float 数组
        let audioSamples: [Float] = audioData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            return int16Ptr.map { Float($0) / 32768.0 }  // 归一化到 [-1, 1]
        }
        
        // 2. 计算音频长度
        let audioLength = Int64(audioSamples.count)
        
        // 3. 语言设置 (0: auto, 1: zh, 2: en, 3: yue, 4: ja, 5: ko)
        let language: Int64 = 0  // auto
        
        print("📊 音频信息:")
        print("  采样点数: \(audioSamples.count)")
        print("  时长: \(Float(audioSamples.count) / Float(sampleRate)) 秒")
        
        return (audioSamples, [audioLength], [language])
    }
    
    // MARK: - Inference
    
    /// 执行语音识别推理
    /// - Parameter audioData: 音频数据
    /// - Returns: 识别结果文本
    func recognize(audioData: Data) async throws -> String {
        guard let session = session else {
            throw NSError(domain: "SenseVoice", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "模型未加载"])
        }
        
        // 1. 预处理音频
        guard let (audioSamples, lengths, language) = preprocessAudio(audioData) else {
            throw NSError(domain: "SenseVoice", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "音频预处理失败"])
        }
        
        // 2. 创建输入张量
        let speechTensor = try createTensor(
            data: audioSamples,
            shape: [1, NSNumber(value: audioSamples.count)]
        )
        
        let lengthsTensor = try createTensor(
            data: lengths,
            shape: [1]
        )
        
        let languageTensor = try createTensor(
            data: language,
            shape: [1]
        )
        
        // 3. 准备输入
        let inputs: [String: ORTValue] = [
            "speech": speechTensor,
            "speech_lengths": lengthsTensor,
            "language": languageTensor
        ]
        
        // 4. 执行推理
        print("🔄 执行推理...")
        let outputs = try session.run(
            withInputs: inputs,
            outputNames: ["ctc_logits", "encoder_out_lens"],
            runOptions: nil
        )
        
        // 5. 解析输出
        guard let logits = outputs["ctc_logits"] else {
            throw NSError(domain: "SenseVoice", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "输出解析失败"])
        }
        
        // 6. 解码结果
        let text = try decodeLogits(logits)
        
        return text
    }
    
    // MARK: - Helper Methods
    
    private func createTensor<T>(data: [T], shape: [NSNumber]) throws -> ORTValue {
        let tensorData = NSMutableData(
            bytes: data,
            length: data.count * MemoryLayout<T>.size
        )
        
        let dataType: ORTTensorElementDataType
        if T.self == Float.self {
            dataType = .float
        } else if T.self == Int64.self {
            dataType = .int64
        } else {
            throw NSError(domain: "SenseVoice", code: -4,
                         userInfo: [NSLocalizedDescriptionKey: "不支持的数据类型"])
        }
        
        return try ORTValue(
            tensorData: tensorData,
            elementType: dataType,
            shape: shape
        )
    }
    
    private func decodeLogits(_ logits: ORTValue) throws -> String {
        // TODO: 实现 CTC 解码
        // 需要 SenseVoice 的词汇表文件和 CTC 解码器
        
        print("⚠️  CTC 解码功能待实现")
        print("需要:")
        print("  1. SenseVoice 词汇表文件")
        print("  2. CTC 解码算法实现")
        
        return "[解码功能待实现]"
    }
}

// MARK: - Usage Example

extension SenseVoiceONNXModel {
    
    /// 使用示例
    static func example() async {
        // ONNX 模型路径
        let modelPath = "/Users/bigo/.cache/modelscope/hub/models/iic/SenseVoiceSmall/model.onnx"
        
        // 创建模型实例
        let model = SenseVoiceONNXModel(modelPath: modelPath)
        
        // 假设有音频数据
        guard let audioData = loadAudioData() else {
            print("❌ 加载音频数据失败")
            return
        }
        
        do {
            let text = try await model.recognize(audioData: audioData)
            print("✅ 识别结果: \(text)")
        } catch {
            print("❌ 识别失败: \(error)")
        }
    }
    
    private static func loadAudioData() -> Data? {
        // 从文件或录音获取音频数据
        // 返回 PCM 格式: 16kHz, 16bit, mono
        return nil
    }
}

// MARK: - iOS Bundle Integration

extension SenseVoiceONNXModel {
    
    /// 从 App Bundle 加载模型
    static func loadFromBundle() -> SenseVoiceONNXModel? {
        // 方式1: 模型在 Bundle 中
        guard let modelURL = Bundle.main.url(
            forResource: "model",
            withExtension: "onnx",
            subdirectory: "SenseVoice"
        ) else {
            print("❌ 找不到 ONNX 模型文件")
            return nil
        }
        
        return SenseVoiceONNXModel(modelPath: modelURL.path)
    }
}

// MARK: - Notes

/*
 使用说明:
 
 1. 模型文件部署
    - 将 model.onnx 和 model.onnx.data 添加到 Xcode 项目
    - 位置: /Users/bigo/.cache/modelscope/hub/models/iic/SenseVoiceSmall/
    - 确保两个文件都在 Copy Bundle Resources 中
 
 2. 依赖配置
    - 已通过 CocoaPods 集成 onnxruntime-objc 1.14.0
    - Podfile 中已配置: pod 'onnxruntime-objc', '~> 1.14.0'
 
 3. CTC 解码
    - 当前示例未实现 CTC 解码
    - 需要额外实现或集成 CTC 解码库
    - 需要 SenseVoice 的词汇表文件
 
 4. 性能优化
    - ONNX Runtime 自动选择最佳执行提供者
    - 支持 CPU 和 CoreML 后端
    - 模型较大 (~900MB)，注意内存使用
 
 5. 替代方案
    如果 ONNX Runtime 遇到问题:
    - 使用云端 ASR API (阿里云/腾讯云)
    - 使用 iOS 系统 Speech Framework
    - 考虑使用更小的模型
 
 6. 参考资料
    - SenseVoice: https://github.com/FunAudioLLM/SenseVoice
    - ONNX Runtime: https://onnxruntime.ai/docs/tutorials/mobile/
    - FunASR: https://github.com/modelscope/FunASR
 */
