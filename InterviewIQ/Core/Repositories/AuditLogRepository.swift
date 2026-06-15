import Foundation
import FirebaseDatabase

// Append-only writer for audit logs at auditLogs/{logId} (FR-11).
// Exposes no update or delete — records are written once and never mutated from
// the app. True tamper-proofing additionally requires Firebase Security Rules
// that forbid client updates/deletes on this node (server-side enforcement).
nonisolated final class AuditLogRepository {
    private let db = Database.database().reference()

    func record(_ log: AuditLog) async throws {
        let data: [String: Any] = [
            "id": log.id,
            "actorId": log.actorId,
            "actorRole": log.actorRole,
            "action": log.action.rawValue,
            "targetType": log.targetType,
            "targetId": log.targetId,
            "timestamp": log.timestamp.timeIntervalSince1970,
            "details": log.details
        ]
        try await db.child("auditLogs").child(log.id).setValue(data)
    }
}
