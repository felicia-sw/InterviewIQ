import Foundation

// Known auditable events. Kept as a closed set so logs stay queryable and
// consistent rather than free-form strings at each call site.
enum AuditAction: String, Codable {
    case userRegistered
    case loginSucceeded
    case loginFailed
    case passwordResetRequested
    case sessionCreated
    case sessionUpdated
    case sessionDeleted
    case roleChanged
    case userActivated
    case userDeactivated
}

// Immutable record of an administrative or authentication event (FR-11).
// Stored at auditLogs/{logId} in Realtime Database. Matches the Data Collection
// Plan fields: actorId, actorRole, action, targetType, targetId, timestamp, details.
struct AuditLog: Identifiable, Codable {
    let id: String
    let actorId: String
    let actorRole: String
    let action: AuditAction
    let targetType: String
    let targetId: String
    let timestamp: Date
    let details: String

    init(
        id: String = UUID().uuidString,
        actorId: String,
        actorRole: String = "",
        action: AuditAction,
        targetType: String,
        targetId: String,
        timestamp: Date = Date(),
        details: String = ""
    ) {
        self.id = id
        self.actorId = actorId
        self.actorRole = actorRole
        self.action = action
        self.targetType = targetType
        self.targetId = targetId
        self.timestamp = timestamp
        self.details = details
    }
}
