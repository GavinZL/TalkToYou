#!/bin/bash
# ASR Service 快速测试脚本

echo "==================================================="
echo "  TalkToYou - ASR Service 测试指南"
echo "==================================================="
echo ""

echo "📋 实现的功能："
echo "  ✅ WebSocket 实时连接到阿里云 Gummy 服务"
echo "  ✅ 实时语音识别（中文）"
echo "  ✅ 实时语音翻译（支持多语言）"
echo "  ✅ 流式音频数据传输"
echo "  ✅ 完整的错误处理机制"
echo ""

echo "📁 新增/修改的文件："
echo "  1. ASRService.swift - 核心 ASR WebSocket 服务"
echo "  2. AudioRecorder.swift - 音频录制与处理"
echo "  3. VoiceRecognitionViewModel.swift - 视图模型"
echo "  4. VoiceRecognitionView.swift - UI 界面"
echo ""

echo "🔧 使用步骤："
echo ""
echo "1. 配置 API Key（三种方式任选其一）："
echo "   方式1: 在 App 设置界面中输入"
echo "   方式2: export DASHSCOPE_API_KEY='your_api_key'"
echo "   方式3: 通过 UserDefaults 保存"
echo ""

echo "2. 在 ContentView.swift 中引入 VoiceRecognitionView："
echo "   NavigationLink(\"语音识别\") {"
echo "       VoiceRecognitionView()"
echo "   }"
echo ""

echo "3. 运行 App 并点击"开始录音"按钮"
echo ""

echo "📝 代码示例（在其他地方使用 ASRService）："
echo ""
cat << 'EOF'
// 配置 API Key
ASRService.shared.configure(apiKey: "your_api_key")

// 设置回调
ASRService.shared.onTranscriptionReceived = { text, isComplete in
    print("识别结果: \(text)")
}

ASRService.shared.onTranslationReceived = { text, lang, isComplete in
    print("翻译[\(lang)]: \(text)")
}

// 开始识别任务
try await ASRService.shared.startRecognition(targetLang: "en", maxEndSilence: 10000)

// 发送音频数据（16kHz, 单声道, PCM）
try await ASRService.shared.sendAudioData(audioData)

// 结束任务
try await ASRService.shared.finishRecognition()

// 关闭连接
ASRService.shared.disconnect()
EOF

echo ""
echo ""
echo "🎯 技术特点："
echo "  • 基于 URLSessionWebSocketTask 实现 WebSocket 连接"
echo "  • 完全遵循阿里云 Gummy API 协议"
echo "  • 支持实时流式音频传输"
echo "  • 自动处理 task-started/result-generated/task-finished 事件"
echo "  • 完整的错误处理和状态管理"
echo ""

echo "⚠️  注意事项："
echo "  1. 音频格式必须是：16kHz, 单声道, 16-bit PCM"
echo "  2. max_end_silence 参数控制静音检测时长（建议 10000ms 用于长音频）"
echo "  3. 使用 gummy-realtime-v1 模型支持长时间连续识别"
echo "  4. 需要在 Info.plist 中添加麦克风权限：NSMicrophoneUsageDescription"
echo ""

echo "✅ 完成！现在可以构建并运行 App 了"
echo ""
