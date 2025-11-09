import SwiftUI
import PhotosUI

//// MARK: - Background Image Helper
//enum BackgroundImageHelper {
//    /// 加载背景图片（优先从文档目录，其次从Bundle）
//    static func loadImage(named: String) -> UIImage? {
//        // 先尝试从文档目录加载（自定义图片）
//        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
//           let image = UIImage(contentsOfFile: documentsPath.appendingPathComponent(named).path) {
//            return image
//        }
//        
//        // 再尝试从 Bundle 加载（预设图片）
//        if let imagesURL = Bundle.main.url(forResource: "Images", withExtension: nil),
//           let imageURL = URL(string: named, relativeTo: imagesURL),
//           let image = UIImage(contentsOfFile: imageURL.path) {
//            return image
//        }
//        
//        return nil
//    }
//}

// MARK: - Background Image Picker
struct BackgroundImagePicker: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var showingPhotoPicker = false
    @State private var editingMode = false
    @State private var shakeOffset: CGFloat = 0
    
    // 预设背景图片列表（从 Resources/Images 目录加载）
    private var backgroundImages: [String] {
        var images: [String] = [""] // 无背景
        
        // 获取 Bundle 中的预设图片
        if let imagesURL = Bundle.main.url(forResource: "Images", withExtension: nil),
           let fileNames = try? FileManager.default.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil) {
            
            let imageFiles = fileNames
                .filter { url in
                    let ext = url.pathExtension.lowercased()
                    return ext == "jpg" || ext == "jpeg" || ext == "png"
                }
                .map { $0.lastPathComponent }
                .sorted()
            
            images.append(contentsOf: imageFiles)
        }
        
        // 获取文档目录中的自定义图片
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let fileNames = try? FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
            
            let customImages = fileNames
                .filter { url in
                    let fileName = url.lastPathComponent
                    return fileName.hasPrefix("custom_") && 
                           ["jpg", "jpeg", "png"].contains(url.pathExtension.lowercased())
                }
                .map { $0.lastPathComponent }
                .sorted()
            
            images.append(contentsOf: customImages)
        }
        
        return images
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: UIConstants.Spacing.viewSpacing) {
                    // 透明度调节
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.itemSpacing) {
                        Text("背景透明度")
                            .font(.headline)
                        
                        HStack {
                            Text("\(Int(settingsManager.settings.backgroundOpacity * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: UIConstants.Spacing.widthReserve)
                            
                            Slider(
                                value: Binding(
                                    get: { settingsManager.settings.backgroundOpacity },
                                    set: { newValue in
                                        settingsManager.updateBackgroundSettings(
                                            imageName: settingsManager.settings.backgroundImageName,
                                            opacity: newValue
                                        )
                                    }
                                ),
                                in: UIConstants.Background.opacityRange,
                                step: UIConstants.Background.opacityStep
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: UIConstants.Layout.smallCornerRadius)
                            .fill(Color(uiColor: .systemBackground))
                    )
                    
                    // 背景图片选择
                    VStack(alignment: .leading, spacing: UIConstants.Spacing.itemSpacing) {
                        HStack {
                            Text("选择背景")
                                .font(.headline)
                            
                            Spacer()
                            
                            // 自选图片按钮
                            Button(action: {
                                showingPhotoPicker = true
                            }) {
                                HStack(spacing: UIConstants.Spacing.extraSmall) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: UIConstants.Button.mediumIconSize))
                                    Text("自选图片")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, UIConstants.Button.horizontalPadding)
                                .padding(.vertical, UIConstants.Button.verticalPadding)
                                .background(
                                    RoundedRectangle(cornerRadius: UIConstants.Button.smallCornerRadius)
                                        .fill(Color.blue.opacity(UIConstants.Opacity.buttonBackground))
                                )
                            }
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: UIConstants.Spacing.standard) {
                            ForEach(backgroundImages, id: \.self) { imageName in
                                BackgroundImageCell(
                                    imageName: imageName,
                                    isSelected: settingsManager.settings.backgroundImageName == imageName,
                                    isEditing: editingMode,
                                    shakeOffset: shakeOffset,
                                    onSelect: {
                                        if !editingMode {
                                            settingsManager.updateBackgroundSettings(
                                                imageName: imageName.isEmpty ? nil : imageName,
                                                opacity: settingsManager.settings.backgroundOpacity
                                            )
                                        } else {
                                            // 点击其他区域退出编辑模式
                                            editingMode = false
                                        }
                                    },
                                    onLongPress: {
                                        // 只有自定义图片才能删除
                                        if imageName.hasPrefix("custom_") {
                                            editingMode = true
                                        }
                                    },
                                    onDelete: {
                                        // 直接删除，不弹确认框
                                        deleteImage(imageName)
                                        editingMode = false
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: UIConstants.Layout.smallCornerRadius)
                            .fill(Color(uiColor: .systemBackground))
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 点击空白区域退出编辑模式
                        if editingMode {
                            editingMode = false
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("背景设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPicker(onImageSelected: { image in
                    saveCustomImage(image)
                })
            }
            .onChange(of: editingMode) { newValue in
                if newValue {
                    // 进入编辑模式，启动抖动动画
                    startShakeAnimation()
                } else {
                    // 退出编辑模式，立即停止抖动
                    stopShakeAnimation()
                }
            }
        }
    }
    
    // MARK: - Animation Control
    private func startShakeAnimation() {
        withAnimation(
            .easeInOut(duration: UIConstants.Animation.shakeDuration)
            .repeatForever(autoreverses: true)
        ) {
            shakeOffset = UIConstants.Animation.shakeRotation
        }
    }
    
    private func stopShakeAnimation() {
        // 关键：使用 .default 动画（而不是 nil）来平滑过渡到 0
        withAnimation(.easeOut(duration: 0.05)) {
            shakeOffset = 0
        }
    }
    
    // MARK: - Helper Methods
    private func deleteImage(_ imageName: String) {
        // 只删除自定义图片
        guard imageName.hasPrefix("custom_") else { return }
        
        // 获取文档目录
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("无法获取文档目录")
            return
        }
        
        let filePath = documentsPath.appendingPathComponent(imageName)
        
        do {
            try FileManager.default.removeItem(at: filePath)
            print("图片已删除: \(filePath.path)")
            
            // 如果删除的是当前背景，清除设置
            if settingsManager.settings.backgroundImageName == imageName {
                settingsManager.updateBackgroundSettings(
                    imageName: nil,
                    opacity: settingsManager.settings.backgroundOpacity
                )
            }
        } catch {
            print("删除图片失败: \(error)")
        }
    }
    
    private func saveCustomImage(_ image: UIImage) {
        // 生成唯一文件名
        let fileName = "custom_\(UUID().uuidString).jpg"
        
        // 获取文档目录
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("无法获取文档目录")
            return
        }
        
        let filePath = documentsPath.appendingPathComponent(fileName)
        
        // 压缩并保存图片
        if let imageData = image.jpegData(compressionQuality: UIConstants.Opacity.imageCompressionQuality) {
            do {
                try imageData.write(to: filePath)
                print("图片已保存: \(filePath.path)")
                
                // 设置为当前背景
                settingsManager.updateBackgroundSettings(
                    imageName: fileName,
                    opacity: settingsManager.settings.backgroundOpacity
                )
            } catch {
                print("保存图片失败: \(error)")
            }
        }
    }
}

// MARK: - Background Image Cell
struct BackgroundImageCell: View {
    let imageName: String
    let isSelected: Bool
    let isEditing: Bool
    let shakeOffset: CGFloat
    let onSelect: () -> Void
    let onLongPress: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressing = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 背景预览
            Group {
                if imageName.isEmpty {
                    RoundedRectangle(cornerRadius: UIConstants.Layout.smallCornerRadius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(UIConstants.Opacity.backgroundDefault), Color.purple.opacity(UIConstants.Opacity.backgroundDefault)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text("无背景")
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                } else {
                    // 从 Resources/Images 文件夹或文档目录加载图片
                    if let image = BackgroundImageHelper.loadImage(named: imageName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: UIConstants.Background.imagePreviewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: UIConstants.Layout.smallCornerRadius))
                    } else {
                        // 如果加载失败，显示占位符
                        RoundedRectangle(cornerRadius: UIConstants.Layout.smallCornerRadius)
                            .fill(Color.gray.opacity(UIConstants.Opacity.backgroundDefault))
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: UIConstants.Background.placeholderIconSize))
                                        .foregroundColor(.gray)
                                    Text("加载失败")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                }
            }
            .frame(height: UIConstants.Background.imagePreviewHeight)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.Layout.smallCornerRadius)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: UIConstants.Layout.borderWidth)
            )
            
            // 选中标记
            if isSelected && !isEditing {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: UIConstants.Background.checkmarkSize))
                    .foregroundColor(.blue)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: UIConstants.Background.checkmarkBackgroundSize, height: UIConstants.Background.checkmarkBackgroundSize)
                    )
                    .offset(x: UIConstants.Background.checkmarkOffset, y: UIConstants.Spacing.small)
            }
            
            // 删除按钮（只在编辑模式且是自定义图片时显示）
            if isEditing && imageName.hasPrefix("custom_") {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: UIConstants.Background.checkmarkSize))
                        .foregroundColor(.red)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: UIConstants.Background.checkmarkBackgroundSize, height: UIConstants.Background.checkmarkBackgroundSize)
                        )
                }
                .offset(x: UIConstants.Background.checkmarkOffset, y: UIConstants.Spacing.small)
            }
        }
        // 抖动效果（由父组件控制）
        .rotationEffect(.degrees(shakeOffset))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onLongPressGesture(
            minimumDuration: UIConstants.Animation.longPressDuration,
            perform: {
                // 长按触发（长按结束时）
                if imageName.hasPrefix("custom_") {
                    onLongPress()
                }
            },
            onPressingChanged: { pressing in
                // 长按状态变化
                isPressing = pressing
                if pressing && imageName.hasPrefix("custom_") {
                    // 开始长按，震动反馈
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    #endif
                }
            }
        )
    }
}

// MARK: - Photo Picker
struct PhotoPicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let error = error {
                    print("加载图片错误: \(error)")
                    return
                }
                
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.onImageSelected(image)
                    }
                }
            }
        }
    }
}

