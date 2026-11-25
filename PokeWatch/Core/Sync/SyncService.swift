import Foundation
import Observation
import WatchConnectivity

/// The link between the iPhone and watch apps (WatchConnectivity).
///
/// * Settings travel both ways as the application context; the newer side wins.
/// * The watch reports which sprite packs it has installed in its context.
/// * Sprite packs travel phone → watch with `transferFile`, queued by the system,
///   so they finish even if either app is closed.
@MainActor @Observable
final class SyncService: NSObject {
    nonisolated static let settingsKey = "settings"
    nonisolated static let packsKey = "installedPacks"
    nonisolated static let packMetadataKey = "pack"

    private(set) var activated = false
    private(set) var reachable = false
    #if os(iOS)
    private(set) var paired = false
    private(set) var watchAppInstalled = false
    /// Packs the watch says it has.
    private(set) var watchPacks: [SpritePackKind] = []
    /// Fraction done for packs being sent, by kind.
    private(set) var transfers: [SpritePackKind: Double] = [:]
    @ObservationIgnored private var progressObservers: [SpritePackKind: NSKeyValueObservation] = [:]
    #endif

    /// Settings received from the other device.
    @ObservationIgnored var onSettings: (([String: Any]) -> Void)?
    /// A sprite pack arrived (watch only).
    @ObservationIgnored var onPack: ((SpritePackKind, URL) -> Void)?

    @ObservationIgnored private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }
    @ObservationIgnored private var pendingContext: [String: Any] = [:]

    func activate() {
        guard let session, session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    /// Publishes this side's state (latest wins on the other side).
    func publish(settings: [String: Any], installedPacks: [SpritePackKind]? = nil) {
        var context: [String: Any] = [Self.settingsKey: settings]
        if let installedPacks { context[Self.packsKey] = installedPacks.map(\.rawValue) }
        pendingContext = context
        flush()
    }

    private func flush() {
        guard let session, session.activationState == .activated, !pendingContext.isEmpty else { return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        do {
            try session.updateApplicationContext(pendingContext)
            pendingContext = [:]
        } catch {
            // Retried on the next state change.
        }
    }

    #if os(iOS)
    /// Queues a pack file for the watch. Progress appears in `transfers`.
    func send(pack: SpritePackKind, file: URL) {
        guard let session, session.activationState == .activated else { return }
        let transfer = session.transferFile(file, metadata: [Self.packMetadataKey: pack.rawValue,
                                                             "version": SpritePackKind.formatVersion])
        transfers[pack] = 0
        progressObservers[pack] = transfer.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            let value = p.fractionCompleted
            Task { @MainActor in self?.transfers[pack] = value }
        }
    }

    func cancelTransfers() {
        session?.outstandingFileTransfers.forEach { $0.cancel() }
        transfers.removeAll()
        progressObservers.removeAll()
    }
    #endif

    fileprivate func update(from session: WCSession) {
        activated = session.activationState == .activated
        reachable = session.isReachable
        #if os(iOS)
        paired = session.isPaired
        watchAppInstalled = session.isWatchAppInstalled
        #endif
        flush()
    }

    fileprivate func received(context: [String: Any]) {
        if let settings = context[Self.settingsKey] as? [String: Any] { onSettings?(settings) }
        #if os(iOS)
        if let packs = context[Self.packsKey] as? [String] {
            watchPacks = packs.compactMap(SpritePackKind.init(rawValue:))
            for p in watchPacks { transfers[p] = nil; progressObservers[p] = nil }
        }
        #endif
    }
}

extension SyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            self.update(from: session)
            if !context.isEmpty { self.received(context: context) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.update(from: session) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        Task { @MainActor in self.received(context: context) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.update(from: session) }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let kind = (fileTransfer.file.metadata?[SyncService.packMetadataKey] as? String).flatMap(SpritePackKind.init(rawValue:))
        Task { @MainActor in
            if let kind, error != nil { self.transfers[kind] = nil }
            else if let kind { self.transfers[kind] = 1 }
        }
    }
    #endif

    #if os(watchOS)
    /// The received file is deleted when this returns, so it is moved aside synchronously.
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let raw = file.metadata?[SyncService.packMetadataKey] as? String,
              let kind = SpritePackKind(rawValue: raw) else { return }
        let keep = FileManager.default.temporaryDirectory.appendingPathComponent("\(raw)-\(UUID().uuidString).pwpk")
        do { try FileManager.default.moveItem(at: file.fileURL, to: keep) } catch { return }
        Task { @MainActor in self.onPack?(kind, keep) }
    }
    #endif
}
