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

    // MARK: - Read (Activity Log viewer)

    // Returns the most recent audit entries, newest first. The published security
    // rules allow any signed-in user to read auditLogs; this powers the in-app
    // Activity Log so the data the app already collects is actually visible.
    func fetchRecent(limit: Int = 100) async throws -> [AuditLog] {
        let snapshot = try await db.child("auditLogs").getData()
        guard let dict = snapshot.value as? [String: Any] else { return [] }

        let logs: [AuditLog] = dict.values.compactMap { value in
            guard
                let entry = value as? [String: Any],
                let id = entry["id"] as? String,
                let actorId = entry["actorId"] as? String,
                let actionRaw = entry["action"] as? String,
                let action = AuditAction(rawValue: actionRaw),
                let timestamp = entry["timestamp"] as? TimeInterval
            else { return nil }

            return AuditLog(
                id: id,
                actorId: actorId,
                actorRole: entry["actorRole"] as? String ?? "",
                action: action,
                targetType: entry["targetType"] as? String ?? "",
                targetId: entry["targetId"] as? String ?? "",
                timestamp: Date(timeIntervalSince1970: timestamp),
                details: entry["details"] as? String ?? ""
            )
        }

        return Array(logs.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
}
