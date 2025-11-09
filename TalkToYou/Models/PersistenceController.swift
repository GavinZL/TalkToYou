import CoreData
import Foundation

// MARK: - Persistence Controller
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TalkToYou")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Save Context
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    // MARK: - Session Operations
    func createSession(title: String = "新对话", roleConfig: RoleConfig? = nil) -> Session {
        let session = Session(title: title, roleConfig: roleConfig)
        saveSession(session)
        return session
    }
    
    func saveSession(_ session: Session) {
        let context = container.viewContext
        let entity = SessionEntity(context: context)
        entity.id = session.id
        entity.title = session.title
        entity.createTime = session.createTime
        entity.updateTime = session.updateTime
        entity.messageCount = Int32(session.messageCount)
        
        if let roleConfig = session.roleConfig {
            if let data = try? JSONEncoder().encode(roleConfig) {
                entity.roleConfig = data
            }
        }
        
        save()
    }
    
    func updateSession(_ session: Session) {
        let context = container.viewContext
        let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            if let entity = try context.fetch(request).first {
                // 更新现有会话
                entity.title = session.title
                entity.updateTime = session.updateTime
                entity.messageCount = Int32(session.messageCount)
                
                if let roleConfig = session.roleConfig {
                    if let data = try? JSONEncoder().encode(roleConfig) {
                        entity.roleConfig = data
                    }
                }
                
                save()
                print("[持久化] 更新会话: \(session.title)")
            } else {
                // 如果不存在，创建新的
                print("[持久化] 会话不存在，创建新的")
                saveSession(session)
            }
        } catch {
            print("Failed to update session: \(error)")
        }
    }
    
    func fetchSessions() -> [Session] {
        let context = container.viewContext
        let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionEntity.updateTime, ascending: false)]
        
        do {
            let entities = try context.fetch(request)
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let title = entity.title,
                      let createTime = entity.createTime,
                      let updateTime = entity.updateTime else {
                    return nil
                }
                
                var roleConfig: RoleConfig?
                if let data = entity.roleConfig {
                    roleConfig = try? JSONDecoder().decode(RoleConfig.self, from: data)
                }
                
                return Session(
                    id: id,
                    title: title,
                    createTime: createTime,
                    updateTime: updateTime,
                    messageCount: Int(entity.messageCount),
                    roleConfig: roleConfig
                )
            }
        } catch {
            print("Failed to fetch sessions: \(error)")
            return []
        }
    }
    
    func deleteSession(_ session: Session) {
        let context = container.viewContext
        
        // 1. 先删除该会话的所有消息
        let messageRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        messageRequest.predicate = NSPredicate(format: "sessionId == %@", session.id as CVarArg)
        
        do {
            let messages = try context.fetch(messageRequest)
            let messageCount = messages.count
            messages.forEach { context.delete($0) }
            print("[持久化] 删除会话 \(session.title) 的 \(messageCount) 条消息")
        } catch {
            print("Failed to delete messages for session: \(error)")
        }
        
        // 2. 再删除会话本身
        let sessionRequest: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        sessionRequest.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            let entities = try context.fetch(sessionRequest)
            entities.forEach { context.delete($0) }
            print("[持久化] 删除会话: \(session.title)")
            save()
        } catch {
            print("Failed to delete session: \(error)")
        }
    }
    
    // MARK: - Message Operations
    func saveMessage(_ message: Message) {
        let context = container.viewContext
        let entity = MessageEntity(context: context)
        entity.id = message.id
        entity.sessionId = message.sessionId
        entity.role = message.role.rawValue
        entity.contentType = message.contentType.rawValue
        entity.textContent = message.textContent
        entity.audioPath = message.audioPath
        entity.createTime = message.createTime
        entity.duration = message.duration ?? 0
        
        save()
        
        // Update session message count
        updateSessionMessageCount(message.sessionId)
    }
    
    func fetchMessages(for sessionId: UUID) -> [Message] {
        let context = container.viewContext
        let request: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        request.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.createTime, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let sessionId = entity.sessionId,
                      let roleString = entity.role,
                      let role = MessageRole(rawValue: roleString),
                      let contentTypeString = entity.contentType,
                      let contentType = ContentType(rawValue: contentTypeString),
                      let textContent = entity.textContent,
                      let createTime = entity.createTime else {
                    return nil
                }
                
                return Message(
                    id: id,
                    sessionId: sessionId,
                    role: role,
                    contentType: contentType,
                    textContent: textContent,
                    audioPath: entity.audioPath,
                    createTime: createTime,
                    duration: entity.duration > 0 ? entity.duration : nil
                )
            }
        } catch {
            print("Failed to fetch messages: \(error)")
            return []
        }
    }
    
    private func updateSessionMessageCount(_ sessionId: UUID) {
        let context = container.viewContext
        let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
        
        do {
            if let session = try context.fetch(request).first {
                let messageRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
                messageRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
                let count = try context.count(for: messageRequest)
                session.messageCount = Int32(count)
                session.updateTime = Date()
                save()
            }
        } catch {
            print("Failed to update session message count: \(error)")
        }
    }
}
