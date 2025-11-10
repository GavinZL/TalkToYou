import SwiftUI

// MARK: - UI常量定义
/// 全局UI常量，统一管理尺寸、间距、颜色等
enum UIConstants {
    
    // MARK: - 布局尺寸
    enum Layout {
        /// 底部功能菜单高度
        static let moreMenuHeight: CGFloat = 200
        
        /// 标准圆角半径
        static let cornerRadius: CGFloat = 16
        
        /// 小圆角半径
        static let smallCornerRadius: CGFloat = 12
        
        /// 大圆角半径
        static let largeCornerRadius: CGFloat = 20
        
        /// 按钮圆角半径
        static let buttonCornerRadius: CGFloat = 22
        
        /// 边框宽度（标准）
        static let borderWidth: CGFloat = 3
        
        /// 边框宽度（细）
        static let thinBorderWidth: CGFloat = 1
    }
    
    // MARK: - 间距
    enum Spacing {
        /// 标准内边距
        static let standard: CGFloat = 16
        
        /// 小内边距
        static let small: CGFloat = 8
        
        /// 极小内边距
        static let extraSmall: CGFloat = 6
        
        /// 大内边距
        static let large: CGFloat = 20
        
        /// 超大内边距
        static let extraLarge: CGFloat = 30
        
        /// 元素间距
        static let itemSpacing: CGFloat = 12
        
        /// 网格间距
        static let gridSpacing: CGFloat = 20
        
        /// 视图间距
        static let viewSpacing: CGFloat = 20
        
        /// 宽度预留
        static let widthReserve: CGFloat = 50
    }
    
    // MARK: - 按钮尺寸
    enum Button {
        /// 圆形按钮直径
        static let circleDiameter: CGFloat = 44
        
        /// 菜单按钮尺寸
        static let menuButtonSize: CGFloat = 60
        
        /// 图标大小
        static let iconSize: CGFloat = 28
        
        /// 小图标大小
        static let smallIconSize: CGFloat = 20
        
        /// 中等图标大小
        static let mediumIconSize: CGFloat = 16
        
        /// 徽章大小
        static let badgeSize: CGFloat = 12
        
        /// 按钮内边距（水平）
        static let horizontalPadding: CGFloat = 12
        
        /// 按钮内边距（垂直）
        static let verticalPadding: CGFloat = 6
        
        /// 按钮圆角（小）
        static let smallCornerRadius: CGFloat = 8
    }
    
    // MARK: - 字体大小
    enum FontSize {
        /// 标题
        static let title: CGFloat = 18
        
        /// 副标题
        static let subtitle: CGFloat = 16
        
        /// 正文
        static let body: CGFloat = 14
        
        /// 说明文字
        static let caption: CGFloat = 12
        
        /// 小说明文字
        static let smallCaption: CGFloat = 10
    }
    
    // MARK: - 透明度
    enum Opacity {
        /// 背景默认透明度
        static let backgroundDefault: Double = 0.3
        
        /// 半透明
        static let semiTransparent: Double = 0.5
        
        /// 高透明
        static let highTransparent: Double = 0.95
        
        /// 阴影透明度
        static let shadow: Double = 0.1
        
        /// 按钮背景透明度
        static let buttonBackground: Double = 0.1
        
        /// 图片压缩质量
        static let imageCompressionQuality: CGFloat = 0.8
    }
    
    // MARK: - 动画
    enum Animation {
        /// 弹簧响应时间
        static let springResponse: Double = 0.3
        
        /// 弹簧阻尼
        static let springDamping: Double = 0.8
        
        /// 标准动画时长
        static let standardDuration: Double = 0.3
        
        /// 抖动动画时长
        static let shakeDuration: Double = 0.1
        
        /// 抖动角度
        static let shakeRotation: Double = 2.0
        
        /// 长按最小时长
        static let longPressDuration: Double = 0.5
    }
    
    // MARK: - 语音设置范围
    enum VoiceSettings {
        /// 语速范围
        static let speechRateRange: ClosedRange<Float> = 0...2.0
        
        /// 语速步进
        static let speechRateStep: Float = 0.1
        
        /// 默认语速
        static let defaultSpeechRate: Float = 1.0
        
        /// 音调范围
        static let pitchRange: ClosedRange<Float> = 0.8...1.2
        
        /// 音调步进
        static let pitchStep: Float = 0.1
        
        /// 默认音调
        static let defaultPitch: Float = 1.0
        
        /// 音量范围
        static let volumeRange: ClosedRange<Float> = 0.5...1.0
        
        /// 音量步进
        static let volumeStep: Float = 0.1
        
        /// 默认音量
        static let defaultVolume: Float = 1.0
    }
    
    // MARK: - 对话设置范围
    enum ConversationSettings {
        /// 上下文轮数范围
        static let contextTurnsRange: ClosedRange<Int> = 5...20
        
        /// 默认上下文轮数
        static let defaultContextTurns: Int = 10
        
        /// 温度范围
        static let temperatureRange: ClosedRange<Float> = 0.7...1.0
        
        /// 温度步进
        static let temperatureStep: Float = 0.05
        
        /// 默认温度
        static let defaultTemperature: Float = 0.8
        
        /// Tokens范围
        static let maxTokensRange: ClosedRange<Int> = 500...4000
        
        /// Tokens步进
        static let maxTokensStep: Int = 500
        
        /// 默认最大Tokens
        static let defaultMaxTokens: Int = 2000
    }
    
    // MARK: - 背景设置
    enum Background {
        /// 透明度范围
        static let opacityRange: ClosedRange<Double> = 0.0...1.0
        
        /// 透明度步进
        static let opacityStep: Double = 0.05
        
        /// 背景图片预览高度
        static let imagePreviewHeight: CGFloat = 120
        
        /// 占位图标大小
        static let placeholderIconSize: CGFloat = 30
        
        /// 选中标记尺寸
        static let checkmarkSize: CGFloat = 24
        
        /// 选中标记背景尺寸
        static let checkmarkBackgroundSize: CGFloat = 20
        
        /// 选中标记偏移
        static let checkmarkOffset: CGFloat = -8
    }
}
