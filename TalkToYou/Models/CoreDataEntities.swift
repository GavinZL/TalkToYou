import Foundation
import CoreData

// MARK: - Session Entity
@objc(SessionEntity)
public class SessionEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var createTime: Date?
    @NSManaged public var updateTime: Date?
    @NSManaged public var messageCount: Int32
    @NSManaged public var roleConfig: Data?
}

extension SessionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SessionEntity> {
        return NSFetchRequest<SessionEntity>(entityName: "SessionEntity")
    }
}

// MARK: - Message Entity
@objc(MessageEntity)
public class MessageEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var sessionId: UUID?
    @NSManaged public var role: String?
    @NSManaged public var contentType: String?
    @NSManaged public var textContent: String?
    @NSManaged public var audioPath: String?
    @NSManaged public var createTime: Date?
    @NSManaged public var duration: TimeInterval
}

extension MessageEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MessageEntity> {
        return NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
    }
}
