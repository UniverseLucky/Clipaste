import AppKit
import Foundation
import os

@MainActor
final class ClipboardMonitor: ClipboardCaptureDraining {
    static let shared = ClipboardMonitor()
    nonisolated static let resourceLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "clipaste",
        category: "ClipboardResourcePolicy"
    )

    let pasteboard = NSPasteboard.general
    let defaults: UserDefaults
    var lastChangeCount: Int = 0
    var monitoringTimer: DispatchSourceTimer?
    var persistenceTasks: [UUID: Task<Void, Never>] = [:]
    /// 最近一次入队的落库任务；新任务排在它之后，保证串行、按复制顺序入库。
    var lastPersistenceTask: Task<Void, Never>?
    nonisolated(unsafe) var defaultsObserver: NSObjectProtocol?
    let fileURLType = NSPasteboard.PasteboardType("public.file-url")
    let utf8PlainTextType = NSPasteboard.PasteboardType("public.utf8-plain-text")
    /// 通用剪贴板（Handoff）从 iPhone / iPad 等其他设备同步过来的内容会带这个标记。
    let remoteClipboardType = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
    var isMonitoringLifecycleActive = false
    var isMonitoringPaused = false
    var pollingInterval: TimeInterval
    var ignoredBundleIdentifiers: Set<String>
    let captureSessionID = UUID()
    var isIgnoredNextChange: Bool = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isMonitoringPaused = defaults.bool(forKey: Keys.isMonitoringPaused)
        self.pollingInterval = Self.sanitizedPollingInterval(
            defaults.object(forKey: Keys.monitorInterval) as? Double
        )
        self.ignoredBundleIdentifiers = IgnoredAppsService.ignoredBundleIdentifierSet(defaults: defaults)
        observePreferences()
    }

    deinit {
        monitoringTimer?.cancel()
        for task in persistenceTasks.values {
            task.cancel()
        }
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    func startMonitoring() {
        isMonitoringLifecycleActive = true
        refreshMonitoringLoop(resetChangeBaseline: true)
    }

    func stopMonitoring() {
        isMonitoringLifecycleActive = false
        cancelMonitoringLoop()
    }

    func stopMonitoringAndDrain() async {
        stopMonitoring()
        let tasks = persistenceTasks
        for (id, task) in tasks {
            await task.value
            persistenceTasks.removeValue(forKey: id)
        }
    }

    private func observePreferences() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyPersistedPreferences()
            }
        }
    }

    private func applyPersistedPreferences() {
        let persistedPauseState = defaults.bool(forKey: Keys.isMonitoringPaused)
        let persistedInterval = Self.sanitizedPollingInterval(
            defaults.object(forKey: Keys.monitorInterval) as? Double
        )
        let persistedIgnoredBundleIdentifiers = IgnoredAppsService.ignoredBundleIdentifierSet(defaults: defaults)

        let pauseStateChanged = persistedPauseState != isMonitoringPaused
        let intervalChanged = persistedInterval != pollingInterval
        let ignoredAppsChanged = persistedIgnoredBundleIdentifiers != ignoredBundleIdentifiers

        guard pauseStateChanged || intervalChanged || ignoredAppsChanged else { return }

        isMonitoringPaused = persistedPauseState
        pollingInterval = persistedInterval
        ignoredBundleIdentifiers = persistedIgnoredBundleIdentifiers

        // Resume 时需要丢弃暂停期间的剪贴板变化，避免把“暂停期间产生的最新剪贴板”补录进历史。
        let shouldResetBaseline = pauseStateChanged && persistedPauseState == false
        refreshMonitoringLoop(resetChangeBaseline: shouldResetBaseline)
    }

    private func refreshMonitoringLoop(resetChangeBaseline: Bool) {
        if resetChangeBaseline {
            lastChangeCount = pasteboard.changeCount
            isIgnoredNextChange = false
        }

        let shouldMonitor = isMonitoringLifecycleActive && !isMonitoringPaused
        guard shouldMonitor else {
            cancelMonitoringLoop()
            return
        }

        cancelMonitoringLoop()

        // 轮询必须挂在主队列的定时器上，不能用 Swift 并发任务循环：连续复制时落库/查询任务会在
        // 协作线程池里同步等待 SQLite，把线程池占满，轮询任务醒不过来，期间的复制会被直接覆盖丢失。
        // 也不能用 .background QoS：后台定时器会被系统大幅合并/推迟（叠加 App Nap 时可达数秒），
        // 导致复制后立刻呼出面板时新记录还没被采集。
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(
            deadline: .now() + pollingInterval,
            repeating: .nanoseconds(Self.nanoseconds(for: pollingInterval)),
            leeway: Self.pollingLeeway(for: pollingInterval)
        )
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.pollPasteboardIfNeeded()
            }
        }
        timer.resume()
        monitoringTimer = timer
    }

    private func cancelMonitoringLoop() {
        monitoringTimer?.cancel()
        monitoringTimer = nil
    }

    private static func sanitizedPollingInterval(_ rawValue: Double?) -> TimeInterval {
        let candidate = rawValue ?? DefaultValues.monitorInterval
        guard candidate.isFinite, candidate >= 0.1 else {
            return DefaultValues.monitorInterval
        }

        return candidate
    }

    private static func pollingLeeway(for interval: TimeInterval) -> DispatchTimeInterval {
        .milliseconds(min(50, max(10, Int((interval * 100).rounded()))))
    }

    private static func nanoseconds(for interval: TimeInterval) -> Int {
        Int((interval * 1_000_000_000).rounded())
    }

}
