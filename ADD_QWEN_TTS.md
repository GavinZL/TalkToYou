# 添加 QwenTTSService 到 Xcode 项目

## 🎯 目标
将新创建的 `QwenTTSService.swift` 文件添加到 Xcode 项目中，使其能够正常编译。

## 📝 步骤

### 方法一：使用 Xcode GUI（推荐）

1. **打开 Xcode 项目**
   ```bash
   open /Users/bigo/Documents/AI/App/TalkToYou/TalkToYou.xcodeproj
   ```

2. **添加文件到项目**
   - 在 Xcode 左侧项目导航器中，右键点击 `Services` 文件夹
   - 选择 "Add Files to 'TalkToYou'..."
   - 找到并选择：`/Users/bigo/Documents/AI/App/TalkToYou/TalkToYou/Services/QwenTTSService.swift`
   - 确保勾选以下选项：
     - ✅ Copy items if needed
     - ✅ Create groups
     - ✅ Add to targets: TalkToYou
   - 点击 "Add"

3. **验证文件已添加**
   - 在项目导航器中，展开 `TalkToYou` → `Services`
   - 确认 `QwenTTSService.swift` 已显示在列表中

4. **编译测试**
   - 按 `Cmd + B` 编译项目
   - 确保没有编译错误

### 方法二：使用命令行（备选）

如果你熟悉 Xcode 项目文件，可以手动编辑 `project.pbxproj`：

```bash
# 1. 备份项目文件
cp TalkToYou.xcodeproj/project.pbxproj TalkToYou.xcodeproj/project.pbxproj.backup

# 2. 在 Xcode 中手动添加（推荐方法一）
```

⚠️ **警告**：不推荐手动编辑 `.pbxproj` 文件，容易导致项目损坏。

## ✅ 验证清单

完成后，请确认以下事项：

- [ ] `QwenTTSService.swift` 在 Xcode 项目导航器中可见
- [ ] 文件显示在 `TalkToYou/Services/` 目录下
- [ ] 文件的 Target Membership 包含 `TalkToYou`
- [ ] 项目可以成功编译（无错误）
- [ ] `ConversationManager.swift` 中的 `import` 语句无警告

## 🧪 测试步骤

1. **编译项目**
   ```bash
   xcodebuild -workspace TalkToYou.xcworkspace \
              -scheme TalkToYou \
              -configuration Debug \
              clean build
   ```

2. **运行应用**
   - 在模拟器或真机上运行应用
   - 开始一个对话
   - 说话后等待 LLM 回复
   - 观察 TTS 是否正常播放

3. **查看日志**
   在 Xcode Console 中应该能看到类似输出：
   ```
   📝 [Qwen-TTS] 开始语音合成: 你好...
   🌐 [Qwen-TTS] 检测到语言: Chinese
   🎙️ [Qwen-TTS] 使用音色: Cherry
   📤 [Qwen-TTS] 发送TTS请求...
   ✅ [Qwen-TTS] 音频下载成功
   ▶️  [Qwen-TTS] 开始播放音频
   ```

## 🐛 常见问题

### Q1: 找不到 `QwenTTSService` 类型
**原因**：文件未正确添加到项目中

**解决方案**：
1. 检查文件是否在项目导航器中可见
2. 检查文件的 Target Membership
3. 重新执行"方法一"的步骤

### Q2: 编译错误："Use of unresolved identifier 'QwenTTSService'"
**原因**：文件未包含在编译目标中

**解决方案**：
1. 选中 `QwenTTSService.swift` 文件
2. 打开右侧的 File Inspector
3. 确保 "Target Membership" 中的 `TalkToYou` 已勾选

### Q3: API 调用失败
**原因**：API Key 未配置或无效

**解决方案**：
1. 打开应用的"设置"页面
2. 填入有效的阿里云 API Key (格式: sk-xxx)
3. 保存设置后重试

### Q4: 无法播放音频
**原因**：网络问题或音频下载失败

**解决方案**：
1. 检查网络连接
2. 查看 Console 日志中的错误信息
3. 确认 API 响应中包含有效的 `audio_url`

## 📚 相关文档

- [TTS_INTEGRATION.md](./TTS_INTEGRATION.md) - 详细的集成文档
- [ConversationManager.swift](./TalkToYou/Services/ConversationManager.swift) - 已更新为使用 QwenTTSService
- [QwenTTSService.swift](./TalkToYou/Services/QwenTTSService.swift) - 新的 TTS 服务实现

## 🎉 完成

按照以上步骤操作后，你的 TalkToYou 应用就已经成功集成了阿里云 Qwen3-TTS-Flash 语音合成服务！

如有问题，请查看日志输出或参考 [TTS_INTEGRATION.md](./TTS_INTEGRATION.md) 中的故障排除部分。
