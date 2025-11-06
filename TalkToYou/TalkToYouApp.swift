import SwiftUI

@main
struct TalkToYouApp: App {
    // 持久化控制器
    let persistenceController = PersistenceController.shared
    
    // 应用启动时初始化
    init() {
        // 配置日志
        setupLogging()
        
        // 初始化设置
        SettingsManager.shared.loadSettings()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        #if DEBUG
        print("TalkToYou App Launched - Debug Mode")
        #endif
    }
}
