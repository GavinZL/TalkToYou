import SwiftUI

// MARK: - Message List View
struct MessageListView: View {
    let messages: [Message]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.textContent)
                    .padding(12)
                    .background(message.role == .user ? Color.green : Color.blue.opacity(0.6))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.createTime.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
}



// MARK: - Background Image Helper
enum BackgroundImageHelper {
    /// 加载背景图片视图
    static func loadBackgroundImage(imageName: String?, opacity: Double) -> some View {
        Group {
            if let imageName = imageName, !imageName.isEmpty {
                // 尝试从文档目录加载（自定义图片）
                if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                   let image = UIImage(contentsOfFile: documentsPath.appendingPathComponent(imageName).path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .opacity(opacity)
                        .ignoresSafeArea()
                }
                // 尝试从 Bundle 加载（预设图片）
                else if let imagesURL = Bundle.main.url(forResource: "Images", withExtension: nil),
                        let imageURL = URL(string: imageName, relativeTo: imagesURL),
                        let image = UIImage(contentsOfFile: imageURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .opacity(opacity)
                        .ignoresSafeArea()
                } else {
                    Color(uiColor: .systemGroupedBackground)
                }
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
        }
    }
    
    /// 加载图片为 UIImage（用于预览等场景）
    static func loadImage(named imageName: String) -> UIImage? {
        // 尝试从文档目录加载（自定义图片）
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imagePath = documentsPath.appendingPathComponent(imageName).path
            if let image = UIImage(contentsOfFile: imagePath) {
                return image
            }
        }
        
        // 尝试从 Bundle 的 Resources/Images 目录加载（预设图片）
        if let imagesURL = Bundle.main.url(forResource: "Images", withExtension: nil),
           let imageURL = URL(string: imageName, relativeTo: imagesURL) {
            if let image = UIImage(contentsOfFile: imageURL.path) {
                return image
            }
        }
        
        return nil
    }
}
