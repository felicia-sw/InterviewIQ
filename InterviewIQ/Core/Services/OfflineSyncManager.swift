import Foundation
import Network

// Monitors network connectivity and syncs pending ScoreRecords to the Realtime
// Database when connectivity is restored (NFR-07, SRS extension 7b).
//
// State is surfaced to the UI so panelists can see how many scores are still
// queued, whether a sync is in flight, and whether the last attempt failed —
// and can trigger a manual retry. Stays @MainActor (it drives observable UI);
// the actual network writes hop off the main thread via the nonisolated repo.
@Observable
final class OfflineSyncManager {
    /// Whether the device currently has a satisfied network path.
    var isOnline: Bool = false
    /// Number of score records saved locally but not yet synced.
    private(set) var pendingCount: Int = 0
    /// True while a sync pass is in flight.
    private(set) var isSyncing: Bool = false
    /// True if the most recent sync attempt left records unsynced.
    private(set) var lastSyncFailed: Bool = false

    private let monitor = NWPathMonitor()
    private let scoreRepo = ScoreRepository()

    init() {
        refreshPendingCount()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = path.status == .satisfied
                // Auto-sync the moment we come back online.
                if wasOffline && self.isOnline {
                    Task { await self.syncPending() }
                }
            }
        }
        monitor.start(queue: .global(qos: .background))
    }

    deinit { monitor.cancel() }

    // Saves locally immediately; syncs to the database if online.
    func enqueue(_ record: ScoreRecord) {
        scoreRepo.saveLocally(record)
        refreshPendingCount()
        if isOnline {
            Task { await syncRecord(record) }
        }
    }

    /// User-initiated retry of every pending record (the "Retry" button).
    func retryNow() {
        Task { await syncPending() }
    }

    func syncPending() async {
        let pending = scoreRepo.loadAllPending()
        guard !pending.isEmpty else {
            refreshPendingCount()
            return
        }
        isSyncing = true
        lastSyncFailed = false
        defer {
            isSyncing = false
            refreshPendingCount()
        }
        for record in pending {
            await syncRecord(record)
        }
    }

    private func syncRecord(_ record: ScoreRecord) async {
        do {
            var synced = record
            synced.syncStatus = .synced
            try await scoreRepo.submit(synced)
            scoreRepo.saveLocally(synced)
        } catch {
            // Stays queued in UserDefaults; will retry on the next connectivity
            // event or manual retry. Flag it so the UI can show a problem.
            lastSyncFailed = true
        }
        refreshPendingCount()
    }

    private func refreshPendingCount() {
        pendingCount = scoreRepo.loadAllPending().count
    }
}
