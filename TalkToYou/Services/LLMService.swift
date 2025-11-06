import Foundation

// MARK: - LLM Service
class LLMService {
    static let shared = LLMService()
    
    private let settings = SettingsManager.shared
    private var session: URLSession
    private var currentRequest: URLSessionDataTask?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generate Response
    func generateResponse(
        userMessage: String,
        conversationHistory: [Message],
        roleConfig: RoleConfig? = nil
    ) async throws -> String {
        // 检查网络连接
        guard NetworkMonitor.shared.isConnected else {
            throw LLMError.networkUnavailable
        }
        
        // 构建消息上下文
        let messages = buildMessages(
            userMessage: userMessage,
            history: conversationHistory,
            roleConfig: roleConfig ?? settings.settings.roleConfig
        )
        
        // 构建请求
        let request = try buildRequest(messages: messages)
        
        // 发送请求
        return try await performRequest(request)
    }
    
    // MARK: - Build Messages
    private func buildMessages(
        userMessage: String,
        history: [Message],
        roleConfig: RoleConfig
    ) -> [[String: String]] {
        var messages: [[String: String]] = []
        
        // System message (角色设定)
        messages.append([
            "role": "system",
            "content": roleConfig.rolePrompt
        ])
        
        // 添加历史对话上下文（最近N轮）
        let contextTurns = settings.settings.contextTurns
        let recentMessages = Array(history.suffix(contextTurns * 2))
        
        for message in recentMessages {
            messages.append([
                "role": message.role.rawValue,
                "content": message.textContent
            ])
        }
        
        // 添加当前用户消息
        messages.append([
            "role": "user",
            "content": userMessage
        ])
        
        return messages
    }
    
    // MARK: - Build Request
    private func buildRequest(messages: [[String: String]]) throws -> URLRequest {
        guard let url = URL(string: settings.settings.apiEndpoint) else {
            throw LLMError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.settings.apiKey)", forHTTPHeaderField: "Authorization")
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": settings.settings.modelVersion,
            "input": [
                "messages": messages
            ],
            "parameters": [
                "result_format": "message",
                "max_tokens": settings.settings.maxTokens,
                "temperature": settings.settings.temperature
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return request
    }
    
    // MARK: - Perform Request
    private func performRequest(_ request: URLRequest, retryCount: Int = 0) async throws -> String {
        let maxRetries = 3
        
        do {
            let (data, response) = try await session.data(for: request)
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }
            
            // 处理不同的状态码
            switch httpResponse.statusCode {
            case 200:
                return try parseResponse(data)
            case 401:
                throw LLMError.authenticationFailed
            case 429:
                throw LLMError.rateLimitExceeded
            case 500...599:
                // 服务器错误，尝试重试
                if retryCount < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000)
                    return try await performRequest(request, retryCount: retryCount + 1)
                }
                throw LLMError.serverError
            default:
                throw LLMError.requestFailed(statusCode: httpResponse.statusCode)
            }
        } catch let error as LLMError {
            throw error
        } catch {
            // 网络错误，尝试重试
            if retryCount < maxRetries {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000)
                return try await performRequest(request, retryCount: retryCount + 1)
            }
            throw LLMError.networkError(error)
        }
    }
    
    // MARK: - Parse Response
    private func parseResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.parseError
        }
        
        // 解析千问API响应格式
        guard let output = json["output"] as? [String: Any],
              let choices = output["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.parseError
        }
        
        return content
    }
    
    // MARK: - Cancel Request
    func cancelCurrentRequest() {
        currentRequest?.cancel()
        currentRequest = nil
    }
}

// MARK: - LLM Error
enum LLMError: LocalizedError {
    case networkUnavailable
    case invalidEndpoint
    case authenticationFailed
    case rateLimitExceeded
    case serverError
    case requestFailed(statusCode: Int)
    case networkError(Error)
    case invalidResponse
    case parseError
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "网络不可用，请检查网络连接"
        case .invalidEndpoint:
            return "无效的API地址"
        case .authenticationFailed:
            return "API认证失败，请检查密钥配置"
        case .rateLimitExceeded:
            return "API调用次数超限，请稍后重试"
        case .serverError:
            return "服务器错误，请稍后重试"
        case .requestFailed(let statusCode):
            return "请求失败，状态码: \(statusCode)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case .parseError:
            return "响应解析失败"
        case .timeout:
            return "请求超时，请重试"
        }
    }
}

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected: Bool = true
    
    private init() {
        // TODO: 实现实际的网络监控
        // 可以使用Network framework的NWPathMonitor
    }
}
