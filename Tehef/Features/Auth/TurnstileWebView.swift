import SwiftUI
import WebKit

/// Cloudflare Turnstile widget in a `WKWebView` (same token flow as web).
struct TurnstileWebView: UIViewRepresentable {
    let siteKey: String
    @Binding var token: String?
    var resetID: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(token: $token)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "turnstile")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.load(siteKey: siteKey, baseURL: APIEnvironment.baseURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastResetID != resetID {
            context.coordinator.lastResetID = resetID
            context.coordinator.resetWidget()
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "turnstile")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var token: String?
        weak var webView: WKWebView?
        var lastResetID: UUID?
        private var loadedSiteKey: String?

        init(token: Binding<String?>) {
            _token = token
        }

        func load(siteKey: String, baseURL: URL) {
            loadedSiteKey = siteKey
            let html = Self.html(siteKey: siteKey)
            webView?.loadHTMLString(html, baseURL: baseURL)
        }

        func resetWidget() {
            token = nil
            webView?.evaluateJavaScript("if (typeof turnstile !== 'undefined') { turnstile.reset(); }") { _, _ in }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "turnstile",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String
            else { return }

            switch type {
            case "success":
                token = body["token"] as? String
            case "expired", "error":
                token = nil
            default:
                break
            }
        }

        private static func html(siteKey: String) -> String {
            let escapedKey = siteKey
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return """
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
              <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
              <style>
                * { box-sizing: border-box; }
                html, body {
                  margin: 0;
                  padding: 0;
                  background: transparent;
                  display: flex;
                  justify-content: center;
                  align-items: center;
                  min-height: 70px;
                }
              </style>
            </head>
            <body>
              <div class="cf-turnstile"
                   data-sitekey="\(escapedKey)"
                   data-callback="onTurnstileSuccess"
                   data-error-callback="onTurnstileError"
                   data-expired-callback="onTurnstileExpired"
                   data-theme="auto"
                   data-size="normal"></div>
              <script>
                function post(type, token) {
                  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.turnstile) {
                    window.webkit.messageHandlers.turnstile.postMessage(
                      token ? { type: type, token: token } : { type: type }
                    );
                  }
                }
                function onTurnstileSuccess(token) { post('success', token); }
                function onTurnstileError() { post('error'); }
                function onTurnstileExpired() { post('expired'); }
              </script>
            </body>
            </html>
            """
        }
    }
}

/// Auth form Turnstile row: hidden when no site key is configured.
struct TurnstileField: View {
    @Binding var token: String?
    @Binding var resetID: UUID

    static var isEnabled: Bool {
        TurnstileEnvironment.isConfigured
    }

    var body: some View {
        if let siteKey = TurnstileEnvironment.siteKey {
            TurnstileWebView(siteKey: siteKey, token: $token, resetID: resetID)
                .frame(height: 72)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    static func reset(token: inout String?, resetID: inout UUID) {
        token = nil
        resetID = UUID()
    }
}
