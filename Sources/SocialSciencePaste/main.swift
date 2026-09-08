// SPDX-License-Identifier: MPL-2.0
import Cocoa
import ServiceManagement
import Darwin

private enum PreferenceKey {
    static let italic = "preserveItalic"
    static let bold = "preserveBold"
    static let links = "preserveLinks"
    static let language = "appLanguage"
    static let formattingDefaultsMigration = "formattingDefaultsMigrationV5"
}

private struct PastePreferences {
    let italic: Bool
    let bold: Bool
    let links: Bool
}

private struct ClipboardSnapshot {
    let changeCount: Int
    let itemCount: Int
    let types: [NSPasteboard.PasteboardType]
    let plainText: String?
    let rtfData: Data?
    let htmlData: Data?
}

private struct CleanedClipboardOutput {
    let plainText: String
    let htmlData: Data?
}


private enum AppLanguage: String, CaseIterable {
    case en, zh

    var displayName: String {
        switch self {
        case .en: return "English"
        case .zh: return "中文"
        }
    }

    static func systemDefault() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("zh") { return .zh }
        return .en
    }
}

private enum L10nKey {
    case pause
    case resume
    case keepFormatting
    case italic
    case bold
    case hyperlinks
    case language
    case launchAtLogin
    case about
    case quit
    case ok
    case aboutBody
    case noClipboard
    case loginApprovalTitle
    case loginApprovalBody
    case loginErrorTitle
}

private struct Localizer {
    let language: AppLanguage

    func text(_ key: L10nKey) -> String {
        switch language {
        case .en:
            return english(key)
        case .zh:
            return chinese(key)
        }
    }

    private func english(_ key: L10nKey) -> String {
        switch key {
        case .pause: return "Pause Social Science Paste"
        case .resume: return "Resume Social Science Paste"
        case .keepFormatting: return "Keep Formatting"
        case .italic: return "Italic"
        case .bold: return "Bold"
        case .hyperlinks: return "Hyperlinks"
        case .language: return "Language"
        case .launchAtLogin: return "Launch at Login"
        case .about: return "About Social Science Paste"
        case .quit: return "Quit Social Science Paste"
        case .ok: return "OK"
        case .aboutBody: return "A lightweight clipboard cleaner for academic writing. Social Science Paste follows a copy-time workflow: when you copy text, it snapshots the original clipboard, removes presentation styling, keeps only the semantic formatting you choose, and immediately writes that cleaned version back to the system clipboard. Paste is never intercepted: your normal ⌘V remains completely native.\n\nImages, files, PDFs and structured tables pass through unchanged. Use Pause from the menu whenever you want copied text to remain completely untouched. All clipboard processing stays on your Mac."
        case .noClipboard: return "No text was found on the clipboard."
        case .loginApprovalTitle: return "Login Item Approval Needed"
        case .loginApprovalBody: return "Social Science Paste was added as a login item, but macOS requires your approval in System Settings → General → Login Items."
        case .loginErrorTitle: return "Could Not Change Login Item"
        }
    }

    private func chinese(_ key: L10nKey) -> String {
        switch key {
        case .pause: return "暂停 Social Science Paste"
        case .resume: return "继续 Social Science Paste"
        case .keepFormatting: return "保留格式"
        case .italic: return "斜体"
        case .bold: return "粗体"
        case .hyperlinks: return "超链接"
        case .language: return "语言"
        case .launchAtLogin: return "登录时自动启动"
        case .about: return "关于 Social Science Paste"
        case .quit: return "退出 Social Science Paste"
        case .ok: return "确定"
        case .aboutBody: return "为学术写作设计的轻量剪贴板清理工具。Social Science Paste 采用“复制时清理”的工作方式：复制文字后，它会保存原始剪贴板快照、删除视觉样式、只保留你选择的语义格式，并立即把清理结果写回系统剪贴板。它完全不接管粘贴，你之后按下的 ⌘V 始终由目标软件原生执行。\n\n图片、文件、PDF 和结构化表格会原样放行。你可以随时从菜单选择“暂停”，让复制的文字完全保持原样。所有剪贴板处理都只在你的 Mac 本地完成。"
        case .noClipboard: return "剪贴板中没有可处理的文本。"
        case .loginApprovalTitle: return "需要批准登录项"
        case .loginApprovalBody: return "Social Science Paste 已加入登录项，但 macOS 需要你在“系统设置 → 通用 → 登录项”中批准。"
        case .loginErrorTitle: return "无法更改登录项"
        }
    }


}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let defaults = UserDefaults.standard
    private var clipboardTimer: Timer?
    private var lastObservedChangeCount: Int = NSPasteboard.general.changeCount
    private var appWrittenChangeCount: Int?
    private var originalSnapshot: ClipboardSnapshot?
    private var isPaused = false
    private let sourceMarkerType = NSPasteboard.PasteboardType("org.socialsciencepaste.cleaned")

    private var pauseItem: NSMenuItem?
    private var italicItem: NSMenuItem?
    private var boldItem: NSMenuItem?
    private var linksItem: NSMenuItem?
    private var launchAtLoginItem: NSMenuItem?

    private var language: AppLanguage {
        get {
            guard let raw = defaults.string(forKey: PreferenceKey.language),
                  let stored = AppLanguage(rawValue: raw) else {
                return AppLanguage.systemDefault()
            }
            return stored
        }
        set {
            defaults.set(newValue.rawValue, forKey: PreferenceKey.language)
        }
    }

    private var localizer: Localizer { Localizer(language: language) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        migrateFormattingDefaultsIfNeeded()
        registerDefaults()
        setupStatusItem()
        startClipboardMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardTimer?.invalidate()
    }

    /// The pre-release builds used a different formatting default. Reset the three
    /// formatting choices once so the public behaviour starts from a predictable,
    /// format-neutral state. Subsequent launches never overwrite the user's choices.
    private func migrateFormattingDefaultsIfNeeded() {
        guard !defaults.bool(forKey: PreferenceKey.formattingDefaultsMigration) else { return }
        defaults.set(false, forKey: PreferenceKey.italic)
        defaults.set(false, forKey: PreferenceKey.bold)
        defaults.set(false, forKey: PreferenceKey.links)
        defaults.set(true, forKey: PreferenceKey.formattingDefaultsMigration)
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            PreferenceKey.italic: false,
            PreferenceKey.bold: false,
            PreferenceKey.links: false,
            PreferenceKey.language: AppLanguage.systemDefault().rawValue
        ])
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusButton()
        rebuildMenu()
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }
        let symbolName = isPaused ? "pause.circle" : "doc.on.clipboard"
        let description = isPaused ? "Social Science Paste — Paused" : "Social Science Paste"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = isPaused ? "Ⅱ" : "SSP"
        }
        button.toolTip = description
    }

    private func rebuildMenu() {
        let t = localizer
        let menu = NSMenu()
        menu.delegate = self

        pauseItem = NSMenuItem(
            title: isPaused ? t.text(.resume) : t.text(.pause),
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pauseItem?.target = self
        menu.addItem(pauseItem!)
        menu.addItem(.separator())

        let formattingHeader = NSMenuItem(title: t.text(.keepFormatting), action: nil, keyEquivalent: "")
        formattingHeader.isEnabled = false
        menu.addItem(formattingHeader)

        italicItem = makeToggleItem(title: t.text(.italic), key: PreferenceKey.italic)
        boldItem = makeToggleItem(title: t.text(.bold), key: PreferenceKey.bold)
        linksItem = makeToggleItem(title: t.text(.hyperlinks), key: PreferenceKey.links)
        menu.addItem(italicItem!)
        menu.addItem(boldItem!)
        menu.addItem(linksItem!)

        menu.addItem(.separator())

        let languageMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.rawValue
            item.state = (lang == language) ? .on : .off
            languageMenu.addItem(item)
        }
        let languageItem = NSMenuItem(title: t.text(.language), action: nil, keyEquivalent: "")
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem(title: t.text(.launchAtLogin), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem?.target = self
        menu.addItem(launchAtLoginItem!)


        let aboutItem = NSMenuItem(title: t.text(.about), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: t.text(.quit), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshToggleStates()
    }

    private func makeToggleItem(title: String, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(togglePreference(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = key
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshToggleStates()
    }

    private func refreshToggleStates() {
        pauseItem?.title = isPaused ? localizer.text(.resume) : localizer.text(.pause)
        italicItem?.state = defaults.bool(forKey: PreferenceKey.italic) ? .on : .off
        boldItem?.state = defaults.bool(forKey: PreferenceKey.bold) ? .on : .off
        linksItem?.state = defaults.bool(forKey: PreferenceKey.links) ? .on : .off
        italicItem?.isEnabled = !isPaused
        boldItem?.isEnabled = !isPaused
        linksItem?.isEnabled = !isPaused
        launchAtLoginItem?.state = isLaunchAtLoginEnabled ? .on : .off
    }

    @objc private func togglePause() {
        isPaused.toggle()

        // Pause is session-only. Pausing/resuming never rewrites the clipboard.
        originalSnapshot = nil
        appWrittenChangeCount = nil
        lastObservedChangeCount = NSPasteboard.general.changeCount

        updateStatusButton()
        refreshToggleStates()
    }

    @objc private func togglePreference(_ sender: NSMenuItem) {
        guard !isPaused else { return }
        guard let key = sender.representedObject as? String else { return }

        // If a new external Copy happened between timer ticks, adopt it first so a settings
        // change can never rewrite an older source over the user's newest clipboard.
        captureLatestExternalSourceIfNeeded()

        defaults.set(!defaults.bool(forKey: key), forKey: key)
        refreshToggleStates()
        rewriteClipboardFromOriginalSnapshotIfPossible()
    }

    private var legacyLaunchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/app.socialsciencepaste.mac.login.plist")
    }

    private var isLaunchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            return status == .enabled || status == .requiresApproval
        }
        return FileManager.default.fileExists(atPath: legacyLaunchAgentURL.path)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let shouldEnable = !isLaunchAtLoginEnabled

        do {
            try setLaunchAtLogin(enabled: shouldEnable)
            refreshToggleStates()

            if #available(macOS 13.0, *),
               shouldEnable,
               SMAppService.mainApp.status == .requiresApproval {
                showLoginAlert(
                    title: localizer.text(.loginApprovalTitle),
                    body: localizer.text(.loginApprovalBody)
                )
            }
        } catch {
            refreshToggleStates()
            showLoginAlert(
                title: localizer.text(.loginErrorTitle),
                body: error.localizedDescription
            )
        }
    }

    private func setLaunchAtLogin(enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                if service.status == .notRegistered || service.status == .notFound {
                    try service.register()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
            return
        }

        try setLegacyLaunchAtLogin(enabled: enabled)
    }

    /// Compatibility path for macOS 11 and 12. The launch agent only asks
    /// LaunchServices to open this app by bundle identifier at user login.
    private func setLegacyLaunchAtLogin(enabled: Bool) throws {
        let fileManager = FileManager.default
        let url = legacyLaunchAgentURL
        let domain = "gui/\(getuid())"

        if enabled {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let plist: [String: Any] = [
                "Label": "app.socialsciencepaste.mac.login",
                "ProgramArguments": [
                    "/usr/bin/open",
                    "-b",
                    "app.socialsciencepaste.mac"
                ],
                "RunAtLoad": true
            ]
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: url, options: .atomic)

            _ = runLaunchctl(["bootout", domain, url.path])
            let status = runLaunchctl(["bootstrap", domain, url.path])
            if status != 0 {
                try? fileManager.removeItem(at: url)
                throw NSError(
                    domain: "SocialSciencePaste.LoginItem",
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "macOS could not register the login item."]
                )
            }
        } else {
            _ = runLaunchctl(["bootout", domain, url.path])
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    private func showLoginAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: localizer.text(.ok))
        alert.runModal()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let selected = AppLanguage(rawValue: raw) else { return }
        language = selected
        rebuildMenu()
    }

    private var preferences: PastePreferences {
        PastePreferences(
            italic: defaults.bool(forKey: PreferenceKey.italic),
            bold: defaults.bool(forKey: PreferenceKey.bold),
            links: defaults.bool(forKey: PreferenceKey.links)
        )
    }

    private func startClipboardMonitoring() {
        lastObservedChangeCount = NSPasteboard.general.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
            self?.observeClipboardChange()
        }
        RunLoop.main.add(clipboardTimer!, forMode: .common)
    }

    /// Observes only Copy-time clipboard changes. Paste is never intercepted or simulated.
    private func observeClipboardChange() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastObservedChangeCount else { return }

        if isPaused {
            // Do not clean, snapshot, or later retroactively process copies made while paused.
            lastObservedChangeCount = currentCount
            originalSnapshot = nil
            appWrittenChangeCount = nil
            return
        }

        // Ignore the generation we just wrote ourselves. The original source snapshot remains
        // in memory so changing a formatting switch can regenerate from the real Copy.
        if appWrittenChangeCount == currentCount {
            lastObservedChangeCount = currentCount
            return
        }

        // Do not mark an external generation as observed until its stable snapshot has actually
        // been captured. If the provider is still changing, the next timer tick retries it.
        guard let snapshot = captureStableClipboardSnapshot(),
              snapshot.changeCount == currentCount else { return }

        lastObservedChangeCount = currentCount

        // Never treat our own sanitised clipboard as a fresh user Copy (e.g. after delayed
        // pasteboard provider callbacks).
        if snapshot.types.contains(sourceMarkerType) { return }

        guard shouldClean(snapshot: snapshot) else {
            originalSnapshot = nil
            return
        }

        originalSnapshot = snapshot
        writeCleanedClipboard(from: snapshot, expectedCurrentCount: snapshot.changeCount)
    }

    /// Synchronously adopts a new external Copy before a user changes a formatting option.
    /// This closes the small gap between the 100 ms monitor ticks.
    private func captureLatestExternalSourceIfNeeded() {
        guard !isPaused else { return }
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        if currentCount == appWrittenChangeCount || currentCount == lastObservedChangeCount {
            return
        }

        lastObservedChangeCount = currentCount
        guard let snapshot = captureStableClipboardSnapshot(),
              snapshot.changeCount == currentCount,
              !snapshot.types.contains(sourceMarkerType),
              shouldClean(snapshot: snapshot) else {
            originalSnapshot = nil
            return
        }
        originalSnapshot = snapshot
    }

    /// Rebuilds the current clipboard from the immutable original Copy when the user changes
    /// Bold / Italic / Hyperlinks. No re-copy is required, and sanitisation never compounds.
    private func rewriteClipboardFromOriginalSnapshotIfPossible() {
        guard !isPaused else { return }
        guard let source = originalSnapshot else { return }
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        // Only rewrite when the clipboard still represents this source or our most recent
        // cleaned derivative. If something else was copied, leave it untouched.
        guard currentCount == source.changeCount || currentCount == appWrittenChangeCount else {
            return
        }
        writeCleanedClipboard(from: source, expectedCurrentCount: currentCount)
    }

    private func writeCleanedClipboard(from snapshot: ClipboardSnapshot, expectedCurrentCount: Int) {
        guard let output = cleanedClipboardOutput(from: snapshot, preferences: preferences) else { return }
        let pasteboard = NSPasteboard.general

        // Never overwrite a Copy that arrived while sanitisation was running.
        guard pasteboard.changeCount == expectedCurrentCount else {
            // A newer external Copy arrived. Do not mark it as observed here; the monitor must
            // capture that generation on the next tick before any sanitised data is written.
            return
        }

        // Richest representation first. Plain text remains the universal fallback.
        var declaredTypes: [NSPasteboard.PasteboardType] = []
        if output.htmlData != nil { declaredTypes.append(.html) }
        declaredTypes.append(.string)
        declaredTypes.append(sourceMarkerType)

        _ = pasteboard.declareTypes(declaredTypes, owner: nil)
        if let html = output.htmlData { _ = pasteboard.setData(html, forType: .html) }
        _ = pasteboard.setString(output.plainText, forType: .string)
        _ = pasteboard.setString(Bundle.main.bundleIdentifier ?? "app.socialsciencepaste.mac", forType: sourceMarkerType)

        appWrittenChangeCount = pasteboard.changeCount
        lastObservedChangeCount = pasteboard.changeCount
    }

    /// Reads all text representations from one NSPasteboardItem and verifies that the
    /// pasteboard generation did not change during the read. No later transformation reads
    /// NSPasteboard.general again.
    private func captureStableClipboardSnapshot() -> ClipboardSnapshot? {
        let pasteboard = NSPasteboard.general

        for _ in 0..<3 {
            let before = pasteboard.changeCount
            let items = pasteboard.pasteboardItems ?? []

            if items.count != 1 {
                let after = pasteboard.changeCount
                if before == after {
                    return ClipboardSnapshot(
                        changeCount: before,
                        itemCount: items.count,
                        types: pasteboard.types ?? [],
                        plainText: nil,
                        rtfData: nil,
                        htmlData: nil
                    )
                }
                continue
            }

            let item = items[0]
            let types = item.types
            let plainText = item.string(forType: .string)
            let rtfData = item.data(forType: .rtf)
            let htmlData = item.data(forType: .html)
            let after = pasteboard.changeCount

            if before == after {
                return ClipboardSnapshot(
                    changeCount: before,
                    itemCount: 1,
                    types: types,
                    plainText: plainText,
                    rtfData: rtfData,
                    htmlData: htmlData
                )
            }
        }

        return nil
    }

    private func shouldClean(snapshot: ClipboardSnapshot) -> Bool {
        guard snapshot.itemCount == 1 else { return false }

        // Respect common clipboard-manager conventions for sensitive, transient or generated
        // payloads. These should not be rewritten by a background cleaner.
        let protectedTypes: Set<String> = [
            "org.nspasteboard.concealedtype",
            "org.nspasteboard.transienttype",
            "org.nspasteboard.autogeneratedtype"
        ]
        if snapshot.types.contains(where: { protectedTypes.contains($0.rawValue.lowercased()) }) {
            return false
        }
        guard snapshot.plainText != nil || snapshot.rtfData != nil || snapshot.htmlData != nil else {
            return false
        }

        if containsNonTextPayload(types: snapshot.types) {
            return false
        }

        if containsStructuredTable(snapshot: snapshot) {
            return false
        }

        return true
    }

    /// If an item carries an image/file/PDF/media representation, preserve it natively even
    /// when the source also exposes alt text or another textual representation. This prevents
    /// Social Science Paste from turning a copied image into its caption or OCR text.
    private func containsNonTextPayload(types: [NSPasteboard.PasteboardType]) -> Bool {
        let nonTextTypes: Set<String> = [
            "public.file-url",
            "nsfilenamespboardtype",
            "public.tiff",
            "public.png",
            "public.jpeg",
            "public.jpg",
            "com.compuserve.gif",
            "public.heic",
            "public.heif",
            "com.adobe.pdf",
            "public.movie",
            "public.audio",
            "public.mpeg-4",
            "public.mpeg-4-audio",
            "com.apple.flat-rtfd",
            "com.apple.rtfd"
        ]

        return types.contains { type in
            let raw = type.rawValue.lowercased()
            if nonTextTypes.contains(raw) { return true }
            if raw.hasPrefix("public.image") || raw.hasPrefix("public.movie") || raw.hasPrefix("public.audio") {
                return true
            }
            return false
        }
    }

    /// Tables are structured objects, not just styled text. If the clipboard explicitly
    /// exposes table structure, pass it through unchanged so cells/columns are never flattened.
    /// Plain tab/newline text with no table representation is still treated as normal text.
    private func containsStructuredTable(snapshot: ClipboardSnapshot) -> Bool {
        if snapshot.types.contains(where: {
            let raw = $0.rawValue.lowercased()
            return raw.contains("tab-separated-values") || raw.contains("spreadsheet")
        }) {
            return true
        }

        if let htmlData = snapshot.htmlData,
           let html = String(data: htmlData, encoding: .utf8)?.lowercased() {
            if html.contains("<table") || (html.contains("<tr") && (html.contains("<td") || html.contains("<th"))) {
                return true
            }
        }

        if let rtfData = snapshot.rtfData {
            let rtf = String(decoding: rtfData, as: UTF8.self).lowercased()
            if rtf.contains("\\trowd") || rtf.contains("\\cellx") || rtf.contains("\\intbl") {
                return true
            }
        }

        return false
    }


    /// Builds cleaned text only from the immutable snapshot captured for this Copy.
    /// Plain text is the canonical payload. RTF/HTML may contribute selected semantic ranges,
    /// but never a different textual payload.
    private func cleanedClipboardOutput(
        from snapshot: ClipboardSnapshot,
        preferences prefs: PastePreferences
    ) -> CleanedClipboardOutput? {
        // The default path is deliberately cheap: when no semantic formatting is requested,
        // use the current plain-text representation directly and do not parse RTF/HTML at all.
        if !(prefs.italic || prefs.bold || prefs.links), let plain = snapshot.plainText {
            return CleanedClipboardOutput(
                plainText: normaliseLineBreaks(plain),
                htmlData: nil
            )
        }

        let richInput = sourceAttributedString(from: snapshot).map(normaliseAttributedLineBreaks)
        guard let canonicalTextSource = snapshot.plainText ?? richInput?.string else {
            return nil
        }
        let exactPlainText = normaliseLineBreaks(canonicalTextSource)

        // If the source did not provide plain text, the rich representation is still the only
        // available textual source. With all switches off, emit its text as plain text only.
        guard prefs.italic || prefs.bold || prefs.links else {
            return CleanedClipboardOutput(plainText: exactPlainText, htmlData: nil)
        }

        guard let input = richInput else {
            return CleanedClipboardOutput(plainText: exactPlainText, htmlData: nil)
        }

        // Rich attributes are transferred only when their textual payload aligns with the
        // canonical current plain text. Content correctness is never derived from RTF/HTML.
        guard semanticComparisonKey(input.string) == semanticComparisonKey(exactPlainText) else {
            return CleanedClipboardOutput(plainText: exactPlainText, htmlData: nil)
        }

        guard containsSelectedSemanticFormatting(in: input, preferences: prefs) else {
            return CleanedClipboardOutput(plainText: exactPlainText, htmlData: nil)
        }

        let body = semanticHTMLPreservingExactLineBreaks(
            rich: input,
            exactPlainText: exactPlainText,
            preferences: prefs
        )
        let html = "<html><head><meta charset=\"utf-8\"></head><body>\(body)</body></html>"
        return CleanedClipboardOutput(plainText: exactPlainText, htmlData: html.data(using: .utf8))
    }

    private func containsSelectedSemanticFormatting(
        in input: NSAttributedString,
        preferences prefs: PastePreferences
    ) -> Bool {
        guard input.length > 0 else { return false }

        var found = false
        let fullRange = NSRange(location: 0, length: input.length)

        input.enumerateAttributes(in: fullRange, options: []) { attributes, _, stop in
            var sourceItalic = false
            var sourceBold = false

            if let font = attributes[.font] as? NSFont {
                let traits = NSFontManager.shared.traits(of: font)
                sourceItalic = traits.contains(.italicFontMask)
                sourceBold = traits.contains(.boldFontMask)
            }

            if let obliqueness = attributes[.obliqueness] as? NSNumber,
               obliqueness.doubleValue != 0 {
                sourceItalic = true
            }

            let hasLink = attributes[.link].flatMap { linkURLString($0) } != nil

            if (prefs.italic && sourceItalic) ||
               (prefs.bold && sourceBold) ||
               (prefs.links && hasLink) {
                found = true
                stop.pointee = true
            }
        }

        return found
    }

    /// Reconciles semantic attributes from rich text with the exact current plain-text payload.
    /// Newlines/blank lines come only from exactPlainText, protecting code blocks and commands.
    private func semanticHTMLPreservingExactLineBreaks(
        rich input: NSAttributedString,
        exactPlainText: String,
        preferences prefs: PastePreferences
    ) -> String {
        let richString = input.string as NSString
        let plainString = exactPlainText as NSString

        var richIndex = 0
        var plainIndex = 0
        var body = ""
        var pendingText = ""
        var pendingAttributes: [NSAttributedString.Key: Any]?

        func flushPending() {
            guard !pendingText.isEmpty else { return }
            body += semanticFragment(
                text: pendingText,
                attributes: pendingAttributes ?? [:],
                preferences: prefs
            )
            pendingText = ""
            pendingAttributes = nil
        }

        while plainIndex < plainString.length {
            let plainRange = plainString.rangeOfComposedCharacterSequence(at: plainIndex)
            let plainChar = plainString.substring(with: plainRange)

            if plainChar == "\n" {
                flushPending()
                body += "<br>"
                plainIndex = NSMaxRange(plainRange)
                continue
            }

            while richIndex < richString.length {
                let richRange = richString.rangeOfComposedCharacterSequence(at: richIndex)
                if richString.substring(with: richRange) == "\n" {
                    richIndex = NSMaxRange(richRange)
                    continue
                }
                break
            }

            guard richIndex < richString.length else {
                flushPending()
                body += escapeHTML(plainChar)
                plainIndex = NSMaxRange(plainRange)
                continue
            }

            let richRange = richString.rangeOfComposedCharacterSequence(at: richIndex)
            let richChar = richString.substring(with: richRange)
            let attributes = input.attributes(at: richIndex, effectiveRange: nil)

            if semanticCharactersEquivalent(richChar, plainChar) {
                if let current = pendingAttributes,
                   attributesEquivalentForPaste(current, attributes) {
                    pendingText += plainChar
                } else {
                    flushPending()
                    pendingText = plainChar
                    pendingAttributes = attributes
                }
                richIndex = NSMaxRange(richRange)
            } else {
                // Comparison above says the representations are semantically equivalent, so
                // reaching this branch should be rare. Preserve current plain text and do not
                // invent an attribute at a position we cannot align safely.
                flushPending()
                body += escapeHTML(plainChar)
            }

            plainIndex = NSMaxRange(plainRange)
        }

        flushPending()
        return body
    }

    private func semanticFragment(
        text: String,
        attributes: [NSAttributedString.Key: Any],
        preferences prefs: PastePreferences
    ) -> String {
        var fragment = escapeHTML(normaliseLineBreaks(text))
            .replacingOccurrences(of: "\n", with: "<br>")

        let fontManager = NSFontManager.shared
        var sourceItalic = false
        var sourceBold = false

        if let font = attributes[.font] as? NSFont {
            let traits = fontManager.traits(of: font)
            sourceItalic = traits.contains(.italicFontMask)
            sourceBold = traits.contains(.boldFontMask)
        }

        if let obliqueness = attributes[.obliqueness] as? NSNumber,
           obliqueness.doubleValue != 0 {
            sourceItalic = true
        }

        if prefs.italic && sourceItalic {
            fragment = "<em>\(fragment)</em>"
        }

        if prefs.bold && sourceBold {
            fragment = "<strong>\(fragment)</strong>"
        }

        if prefs.links, let link = attributes[.link], let href = linkURLString(link) {
            fragment = "<a href=\"\(escapeHTMLAttribute(href))\">\(fragment)</a>"
        }

        return fragment
    }

    private func attributesEquivalentForPaste(
        _ lhs: [NSAttributedString.Key: Any],
        _ rhs: [NSAttributedString.Key: Any]
    ) -> Bool {
        func traits(_ attributes: [NSAttributedString.Key: Any]) -> (Bool, Bool, String?) {
            var italic = false
            var bold = false
            if let font = attributes[.font] as? NSFont {
                let value = NSFontManager.shared.traits(of: font)
                italic = value.contains(.italicFontMask)
                bold = value.contains(.boldFontMask)
            }
            if let obliqueness = attributes[.obliqueness] as? NSNumber,
               obliqueness.doubleValue != 0 {
                italic = true
            }
            let link = attributes[.link].flatMap { linkURLString($0) }
            return (italic, bold, link)
        }

        let a = traits(lhs)
        let b = traits(rhs)
        return a.0 == b.0 && a.1 == b.1 && a.2 == b.2
    }

    private func normaliseLineBreaks(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
    }

    /// Normalises line-break characters while preserving the attributed-string ranges. This
    /// avoids using indices from a normalised String against an unnormalised attributed string.
    private func normaliseAttributedLineBreaks(_ input: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: input)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.mutableString.replaceOccurrences(of: "\r\n", with: "\n", options: [], range: full)
        var range = NSRange(location: 0, length: mutable.length)
        mutable.mutableString.replaceOccurrences(of: "\r", with: "\n", options: [], range: range)
        range = NSRange(location: 0, length: mutable.length)
        mutable.mutableString.replaceOccurrences(of: "\u{2028}", with: "\n", options: [], range: range)
        range = NSRange(location: 0, length: mutable.length)
        mutable.mutableString.replaceOccurrences(of: "\u{2029}", with: "\n", options: [], range: range)
        return mutable
    }

    private func semanticComparisonKey(_ string: String) -> String {
        normaliseLineBreaks(string)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .precomposedStringWithCanonicalMapping
    }

    private func semanticCharactersEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        func key(_ value: String) -> String {
            value
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .replacingOccurrences(of: "\u{202F}", with: " ")
                .precomposedStringWithCanonicalMapping
        }
        return key(lhs) == key(rhs)
    }

    private func sourceAttributedString(from snapshot: ClipboardSnapshot) -> NSAttributedString? {
        let target = snapshot.plainText.map { semanticComparisonKey($0) }

        // Prefer RTF when it is available (Office produces it natively and it is cheaper to
        // parse than HTML). Only parse HTML if RTF is absent or does not align with plain text.
        if let rtf = snapshot.rtfData,
           let attributed = try? NSAttributedString(
                data: rtf,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
           ) {
            if target == nil || semanticComparisonKey(normaliseAttributedLineBreaks(attributed).string) == target {
                return attributed
            }
        }

        if let html = snapshot.htmlData,
           let attributed = try? NSAttributedString(
                data: html,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
           ) {
            if target == nil || semanticComparisonKey(normaliseAttributedLineBreaks(attributed).string) == target {
                return attributed
            }
        }

        if let plain = snapshot.plainText {
            return NSAttributedString(string: plain)
        }
        return nil
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func escapeHTMLAttribute(_ string: String) -> String {
        escapeHTML(string)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func linkURLString(_ value: Any) -> String? {
        if let url = value as? URL { return url.absoluteString }
        if let url = value as? NSURL { return url.absoluteString }
        if let string = value as? String { return string }
        return nil
    }


    @objc private func showAbout() {
        let alert = NSAlert()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        alert.messageText = version.isEmpty ? "Social Science Paste" : "Social Science Paste \(version)"
        alert.informativeText = localizer.text(.aboutBody) + "\n\nCreated by Social Science Paste project\n"
        alert.addButton(withTitle: localizer.text(.ok))
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
