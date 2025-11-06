import SwiftUI

struct VoiceRecognitionView: View {
    @StateObject private var viewModel = VoiceRecognitionViewModel()
    @State private var showAPIKeySheet = false
    @State private var apiKeyInput = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 标题
                Text("语音识别与翻译")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // 语言选择
                languageSelector
                
                Spacer()
                
                // 识别结果显示
                resultSection
                
                Spacer()
                
                // 录音按钮
                recordButton
                
                // 错误信息
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAPIKeySheet = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showAPIKeySheet) {
                apiKeySheet
            }
        }
    }
    
    // MARK: - View Components
    
    private var languageSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("目标语言")
                .font(.headline)
            
            Picker("目标语言", selection: $viewModel.targetLanguage) {
                ForEach(viewModel.availableLanguages, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }
    
    private var resultSection: some View {
        VStack(spacing: 16) {
            // 识别结果
            resultCard(
                title: "📝 识别结果",
                text: viewModel.transcriptionText,
                placeholder: "等待语音输入..."
            )
            
            // 翻译结果
            resultCard(
                title: "🌍 翻译结果",
                text: viewModel.translationText,
                placeholder: "等待翻译..."
            )
        }
        .padding(.horizontal)
    }
    
    private func resultCard(title: String, text: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            ScrollView {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 100)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var recordButton: some View {
        Button {
            if viewModel.isRecording {
                viewModel.stopRecording()
            } else {
                viewModel.startRecording()
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(viewModel.isRecording ? .red : .blue)
                
                Text(viewModel.isRecording ? "停止录音" : "开始录音")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(viewModel.isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
        )
        .padding(.horizontal)
    }
    
    private var apiKeySheet: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("输入 DASHSCOPE_API_KEY", text: $apiKeyInput)
                    
                    Button("保存") {
                        viewModel.configureAPIKey(apiKeyInput)
                        showAPIKeySheet = false
                        apiKeyInput = ""
                    }
                    .disabled(apiKeyInput.isEmpty)
                } header: {
                    Text("API 配置")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请输入阿里云灵积平台的 API Key")
                        Text("获取地址: https://dashscope.console.aliyun.com/apiKey")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showAPIKeySheet = false
                        apiKeyInput = ""
                    }
                }
            }
        }
    }
}

#Preview {
    VoiceRecognitionView()
}
