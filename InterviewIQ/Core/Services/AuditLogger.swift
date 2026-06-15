import Foundation

// Best-effort audit logging facade (FR-11). Logging must never break the user
// action it records, so failures are swallowed (and printed in debug). Call
// sites stay terse: one `log(...)` instead of building a record + handling
// write errors everywhere.
nonisolated final class AuditLogger {
    private let repo: AuditLogRepository

    init(repo: AuditLogRepository = AuditLogRepository()) {
        self.repo = repo
    }

    func log(
        _ action: AuditAction,
        actorId: String,
        actorRole: String = "",
        targetType: String,
        targetId: String,
        details: String = ""
    ) async {
        let entry = AuditLog(
            actorId: actorId,
            actorRole: actorRole,
            action: action,
            targetType: targetType,
            targetId: targetId,
            details: details
        )
        do {
            try await repo.record(entry)
        } catch {
            #if DEBUG
            print("[AuditLogger] failed to record \(action.rawValue): \(error.localizedDescription)")
            #endif
        }
    }
}
