import Cocoa
import WebKit

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow!
    var webView: WKWebView!
    var navigationDelegate: NavigationDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup main window
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

        // Setup WKWebView
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(ScriptMessageHandler(), name: "nativeApp")

        config.userContentController = contentController
        config.preferences = WKPreferences()
        config.defaultWebpagePreferences = WKWebpagePreferences()
        config.defaultWebpagePreferences?.allowsContentJavaScript = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        let navDelegate = NavigationDelegate()
        webView.navigationDelegate = navDelegate
        self.navigationDelegate = navDelegate

        mainWindow.contentView = webView

        // Load bundled HTML
        loadHTML()

        mainWindow.makeKeyAndOrderFront(nil)
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

// MARK: - Navigation Delegate

class NavigationDelegate: NSObject, WKNavigationDelegate {
    @MainActor func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.scheme == "file" {
                decisionHandler(.allow)
                return
            }
            // Open external links in default browser
            if url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}

// MARK: - Script Message Handler

class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "nativeApp" {
            if let body = message.body as? [String: Any],
               let action = body["action"] as? String {
                switch action {
                case "setTitle":
                    if let title = body["title"] as? String {
                        NSApp.mainWindow?.title = title
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - App Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
