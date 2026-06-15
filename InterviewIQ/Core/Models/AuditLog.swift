import Foundation

// Known auditable events. Kept as a closed set so logs stay queryable and
// consistent rather than free-form strings at each call site.
enum AuditAction: String, Codable, CaseIterable {
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

    // MARK: - Display

    /// Human-readable label for the Activity Log viewer.
    var label: String {
        switch self {
        case .userRegistered:         return "Account created"
        case .loginSucceeded:         return "Signed in"
        case .loginFailed:            return "Failed sign-in"
        case .passwordResetRequested: return "Password reset requested"
        case .sessionCreated:         return "Session created"
        case .sessionUpdated:         return "Session updated"
        case .sessionDeleted:         return "Session deleted"
        case .roleChanged:            return "Role changed"
        case .userActivated:          return "User activated"
        case .userDeactivated:        return "User deactivated"
        }
    }

    /// SF Symbol shown next to the entry.
    var iconName: String {
        switch self {
        case .userRegistered:         return "person.badge.plus"
        case .loginSucceeded:         return "checkmark.shield"
        case .loginFailed:            return "exclamationmark.shield"
        case .passwordResetRequested: return "key"
        case .sessionCreated:         return "plus.square"
        case .sessionUpdated:         return "square.and.pencil"
        case .sessionDeleted:         return "trash"
        case .roleChanged:            return "person.2.badge.gearshape"
        case .userActivated:          return "person.fill.checkmark"
        case .userDeactivated:        return "person.fill.xmark"
        }
    }

    /// Whether the event is security-sensitive (drives a warning tint).
    var isSecuritySensitive: Bool {
        switch self {
        case .loginFailed, .sessionDeleted, .roleChanged, .userDeactivated: return true
        default: return false
        }
    }
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
