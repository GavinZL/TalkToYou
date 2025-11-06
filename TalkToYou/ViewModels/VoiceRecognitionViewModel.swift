import Foundation
import SwiftUI
import Combine

// MARK: - Voice Recognition ViewModel
@MainActor
class VoiceRecognitionViewModel: ObservableObject {
    // 发布的状态
    @Published var isRecording = false
    @Published var transcriptionText = ""
    @Published var translationText = ""
    @Published var errorMessage: String?
    @Published var targetLanguage = "en"
    
    // 可用的目标语言
    let availableLanguages = [
        ("en", "英语"),
        ("ja", "日语"),
        ("ko", "韩语"),
        ("es", "西班牙语"),
        ("fr", "法语"),
        ("de", "德语")
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupASRCallbacks()
    }
    
    // MARK: - Public Methods
    
    /// 开始录音识别
    func startRecording() {
        Task {
            do {
                errorMessage = nil
                transcriptionText = ""
                translationText = ""
                
                try await AudioRecorder.shared.startRecording(targetLang: targetLanguage)
                isRecording = true
            } catch {
                errorMessage = error.localizedDescription
                print("❌ 开始录音失败: \(error)")
            }
        }
    }
    
    /// 停止录音识别
    func stopRecording() {
        Task {
            do {
                try await AudioRecorder.shared.stopRecording()
                isRecording = false
            } catch {
                errorMessage = error.localizedDescription
                print("❌ 停止录音失败: \(error)")
            }
        }
    }
    
    /// 配置 API Key
    func configureAPIKey(_ apiKey: String) {
        ASRService.shared.configure(apiKey: apiKey)
    }
    
    // MARK: - Private Methods
    
    private func setupASRCallbacks() {
        // 识别结果回调
        ASRService.shared.onTranscriptionReceived = { [weak self] text, isComplete in
            guard let self = self else { return }
            Task { @MainActor in
                self.transcriptionText = text
            }
        }
        
        // 翻译结果回调
        ASRService.shared.onTranslationReceived = { [weak self] text, lang, isComplete in
            guard let self = self else { return }
            Task { @MainActor in
                if lang == self.targetLanguage {
                    self.translationText = text
                }
            }
        }
        
        // 任务完成回调
        ASRService.shared.onTaskCompleted = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.isRecording = false
            }
        }
        
        // 错误回调
        ASRService.shared.onError = { [weak self] error in
            guard let self = self else { return }
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
                self.isRecording = false
            }
        }
    }
}
