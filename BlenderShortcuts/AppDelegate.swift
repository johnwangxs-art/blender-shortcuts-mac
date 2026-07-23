import Cocoa
import WebKit
import UniformTypeIdentifiers

// ═══ Constants ═══
let GITHUB_OWNER = "johnwangxs-art"
let GITHUB_REPO_NAME = "blender-shortcuts-mac"
let GITHUB_API_BASE = "https://api.github.com/repos/\(GITHUB_OWNER)/\(GITHUB_REPO_NAME)"

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow!
    var webView: WKWebView!
    var navDelegate: NavigationDelegate?
    var updateManager: UpdateManager!
    var messageHandler: AppMessageHandler!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Window
        let contentRect = NSRect(x: 0, y: 0, width: 860, height: 700)
        mainWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        mainWindow.title = "Blender 快捷键查询"
        mainWindow.center()
        mainWindow.minSize = NSSize(width: 500, height: 400)

        // WebView
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        messageHandler = AppMessageHandler()
        contentController.add(messageHandler, name: "nativeApp")

        config.userContentController = contentController
        config.preferences = WKPreferences()
        config.defaultWebpagePreferences = WKWebpagePreferences()
        config.defaultWebpagePreferences?.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        let nd = NavigationDelegate()
        webView.navigationDelegate = nd
        self.navDelegate = nd

        mainWindow.contentView = webView

        // UpdateManager
        updateManager = UpdateManager()

        // Wire up references
        messageHandler.appDelegate = self

        // Load HTML
        loadHTML()

        mainWindow.makeKeyAndOrderFront(nil)

        // Check for updates after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.updateManager.checkForUpdate()
        }
    }

    private func loadHTML() {
        if let htmlPath = Bundle.main.path(forResource: "blender_shortcuts", ofType: "html", inDirectory: "Resources") {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            let htmlDirectory = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlDirectory)
        } else if let htmlPath = Bundle.main.path(forResource: "blender_shortcuts", ofType: "html") {
            let htmlURL = URL(fileURLWithPath: htmlPath)
            let htmlDirectory = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlDirectory)
        } else {
            print("ERROR: blender_shortcuts.html not found in app bundle")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Update Manager

@MainActor
class UpdateManager {
    func checkForUpdate() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        Task {
            do {
                let release = try await fetchLatestRelease()
                let remoteVersion = release.tagName.replacingOccurrences(of: "v", with: "")

                if compareVersions(remoteVersion, currentVersion) > 0 {
                    showUpdateAlert(version: remoteVersion, release: release)
                }
            } catch {
                print("Update check failed: \(error.localizedDescription)")
            }
        }
    }

    private func fetchLatestRelease() async throws -> (tagName: String, body: String, htmlUrl: String, zipAssetUrl: String?) {
        guard let url = URL(string: "\(GITHUB_API_BASE)/releases/latest") else {
            throw UpdateError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UpdateError.networkError
        }

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let tagName = json["tag_name"] as! String
        let body = json["body"] as? String ?? ""
        let htmlUrl = json["html_url"] as! String

        var zipUrl: String?
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let name = asset["name"] as? String, name.hasSuffix(".zip"),
                   let dlUrl = asset["browser_download_url"] as? String {
                    zipUrl = dlUrl
                    break
                }
            }
        }

        return (tagName: tagName, body: body, htmlUrl: htmlUrl, zipAssetUrl: zipUrl)
    }

    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(p1.count, p2.count) {
            let a = i < p1.count ? p1[i] : 0
            let b = i < p2.count ? p2[i] : 0
            if a > b { return 1 }
            if a < b { return -1 }
        }
        return 0
    }

    private func showUpdateAlert(version: String, release: (tagName: String, body: String, htmlUrl: String, zipAssetUrl: String?)) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 v\(version)"
        alert.informativeText = release.body.isEmpty ? "有新版本可用" : String(release.body.prefix(500))
        alert.alertStyle = .informational

        let hasZip = release.zipAssetUrl != nil
        if hasZip {
            alert.addButton(withTitle: "自动更新")
        }
        alert.addButton(withTitle: "打开下载页")
        alert.addButton(withTitle: "稍后提醒")

        guard let window = NSApp.mainWindow else { return }
        alert.beginSheetModal(for: window) { response in
            let buttonIndex = response.rawValue
            // button indices: first=1000, second=1001, third=1002
            if hasZip && buttonIndex == 1000 {
                if let zipUrl = release.zipAssetUrl {
                    self.downloadAndInstall(zipUrl: zipUrl, version: version)
                }
            } else if (!hasZip && buttonIndex == 1000) || (hasZip && buttonIndex == 1001) {
                if let url = URL(string: release.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func downloadAndInstall(zipUrl: String, version: String) {
        guard let url = URL(string: zipUrl) else { return }

        // Progress alert
        let alert = NSAlert()
        alert.messageText = "正在下载更新 v\(version)..."
        alert.informativeText = "请稍候，下载完成后将自动替换并重启应用。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "取消")

        guard let window = NSApp.mainWindow else { return }
        alert.beginSheetModal(for: window) { _ in }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                // Close progress alert
                window.endSheet(alert.window)

                // Save & extract
                let tempDir = FileManager.default.temporaryDirectory
                let zipPath = tempDir.appendingPathComponent("BS_update_\(version).zip")
                try data.write(to: zipPath)

                let extractDir = tempDir.appendingPathComponent("BS_update_\(version)")
                try? FileManager.default.removeItem(at: extractDir)
                try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                proc.arguments = ["-o", zipPath.path, "-d", extractDir.path]
                try proc.run()
                proc.waitUntilExit()

                // Find new .app
                let contents = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                guard let newAppURL = contents.first(where: { $0.pathExtension == "app" }) else {
                    self.showError("解压失败：未找到 .app 文件")
                    return
                }

                // Remove quarantine
                let xattr = Process()
                xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattr.arguments = ["-cr", newAppURL.path]
                try xattr.run()
                xattr.waitUntilExit()

                // Replace
                let currentAppURL = Bundle.main.bundleURL

                // Try to trash old app
                do {
                    try FileManager.default.trashItem(at: currentAppURL, resultingItemURL: nil)
                } catch {
                    // If trash fails, try direct remove
                    try? FileManager.default.removeItem(at: currentAppURL)
                }

                // Copy new app
                try FileManager.default.copyItem(at: newAppURL, to: currentAppURL)

                // Restart
                let restartAlert = NSAlert()
                restartAlert.messageText = "更新成功！"
                restartAlert.informativeText = "新版本 v\(version) 已安装，需要重启应用完成更新。"
                restartAlert.addButton(withTitle: "立即重启")

                restartAlert.beginSheetModal(for: window) { _ in
                    let config = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.openApplication(at: currentAppURL, configuration: config)
                    NSApp.terminate(nil)
                }

            } catch {
                window.endSheet(alert.window)
                self.showError("更新失败：\(error.localizedDescription)")
            }
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "更新出错"
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

enum UpdateError: Error {
    case invalidURL
    case networkError
}

// MARK: - Navigation Delegate

class NavigationDelegate: NSObject, WKNavigationDelegate {
    @MainActor func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.scheme == "file" {
                decisionHandler(.allow)
                return
            }
            if url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}

// MARK: - Message Handler (Native Bridge)

class AppMessageHandler: NSObject, WKScriptMessageHandler {
    weak var appDelegate: AppDelegate?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "nativeApp",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        let callbackId = body["callbackId"] as? String

        switch action {
        case "setTitle":
            if let title = body["title"] as? String {
                NSApp.mainWindow?.title = title
            }

        case "getAppVersion":
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            jsCallback(callbackId: callbackId, result: ["success": true, "version": version])

        case "checkUpdate":
            appDelegate?.updateManager.checkForUpdate()
            jsCallback(callbackId: callbackId, result: ["success": true])

        case "openFile":
            handleOpenFile(body: body, callbackId: callbackId)

        case "saveFile":
            handleSaveFile(body: body, callbackId: callbackId)

        default:
            jsCallback(callbackId: callbackId, result: ["success": false, "error": "Unknown action: \(action)"])
        }
    }

    // ── File Open ──
    private func handleOpenFile(body: [String: Any], callbackId: String?) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.message = "选择要导入的文件"

            if let filters = body["filters"] as? [String] {
                var types: [UTType] = []
                for f in filters {
                    let ext = f.hasPrefix(".") ? String(f.dropFirst()) : f
                    if let ut = UTType(filenameExtension: ext) { types.append(ut) }
                }
                if !types.isEmpty { panel.allowedContentTypes = types }
            }

            if panel.runModal() == .OK, let url = panel.url {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    self.jsCallback(callbackId: callbackId, result: [
                        "success": true,
                        "content": content,
                        "path": url.path,
                        "name": url.lastPathComponent
                    ])
                } catch {
                    self.jsCallback(callbackId: callbackId, result: ["success": false, "error": "读取文件失败"])
                }
            } else {
                self.jsCallback(callbackId: callbackId, result: ["success": false, "error": "cancelled"])
            }
        }
    }

    // ── File Save ──
    private func handleSaveFile(body: [String: Any], callbackId: String?) {
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = body["defaultName"] as? String ?? "export.json"
            panel.message = "选择保存位置"

            if let ext = body["ext"] as? String {
                let e = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
                if let ut = UTType(filenameExtension: e) {
                    panel.allowedContentTypes = [ut]
                }
            }

            if panel.runModal() == .OK, let url = panel.url {
                do {
                    let content = body["content"] as? String ?? ""
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    self.jsCallback(callbackId: callbackId, result: ["success": true, "path": url.path])
                } catch {
                    self.jsCallback(callbackId: callbackId, result: ["success": false, "error": "保存文件失败"])
                }
            } else {
                self.jsCallback(callbackId: callbackId, result: ["success": false, "error": "cancelled"])
            }
        }
    }

    // ── JS Callback ──
    private func jsCallback(callbackId: String?, result: [String: Any]) {
        guard let callbackId = callbackId else { return }
        guard let webView = appDelegate?.webView else { return }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: result)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let js = "window._nativeResolve('\(callbackId)', \(jsonString))"
            webView.evaluateJavaScript(js)
        } catch {
            print("JS callback serialization failed: \(error)")
        }
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
