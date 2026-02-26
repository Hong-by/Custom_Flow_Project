import Cocoa
import FlutterMacOS
import WebKit

/// Flutter 플랫폼 뷰 팩토리
class NativeWebViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withViewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> NSView {
        let params = args as? [String: Any] ?? [:]
        let channelName = params["channelName"] as? String ?? "native_webview_\(viewId)"
        return NativeWebViewContainer(channelName: channelName, messenger: messenger)
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// WKWebView를 감싸는 NSView
/// - messageHandler를 등록하지 않아 Google OAuth 감지를 우회
/// - WKUIDelegate로 팝업(window.open)을 실제 자식 WKWebView로 생성 → window.opener 유지
/// - Chrome User-Agent → 모든 사이트 정상 렌더링
class NativeWebViewContainer: NSView, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    let channel: FlutterMethodChannel
    /// OAuth 팝업 등 window.open()으로 생성된 자식 WKWebView
    private var popupWebView: WKWebView?

    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/537.36 (KHTML, like Gecko) " +
        "Chrome/131.0.0.0 Safari/537.36"

    init(channelName: String, messenger: FlutterBinaryMessenger) {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "javaScriptEnabled")
        config.preferences.setValue(true, forKey: "javaScriptCanOpenWindowsAutomatically")
        // ★ messageHandler를 등록하지 않음 → window.webkit.messageHandlers 없음

        webView = WKWebView(frame: .zero, configuration: config)
        channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

        super.init(frame: .zero)

        webView.customUserAgent = NativeWebViewContainer.userAgent
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        setupMethodChannel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - MethodChannel

    private func setupMethodChannel() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(nil); return }
            switch call.method {
            case "loadUrl":
                if let urlStr = call.arguments as? String,
                   let url = URL(string: urlStr) {
                    self.webView.load(URLRequest(url: url))
                }
                result(nil)
            case "evaluateJavaScript":
                if let script = call.arguments as? String {
                    self.webView.evaluateJavaScript(script) { value, _ in
                        result(value)
                    }
                } else {
                    result(nil)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - 팝업 정리

    private func dismissPopup() {
        popupWebView?.removeFromSuperview()
        popupWebView = nil
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // 메인 웹뷰의 이벤트만 Flutter에 전달
        if webView == self.webView {
            channel.invokeMethod("onPageStarted", arguments: webView.url?.absoluteString ?? "")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 메인 웹뷰의 이벤트만 Flutter에 전달
        if webView == self.webView {
            channel.invokeMethod("onPageFinished", arguments: webView.url?.absoluteString ?? "")
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let url = navigationAction.request.url?.absoluteString ?? ""
        // cfmsg:// 커스텀 스킴 메시지 수신
        if url.hasPrefix("cfmsg://") {
            let msg = String(url.dropFirst("cfmsg://".count)).removingPercentEncoding ?? ""
            channel.invokeMethod("onMessage", arguments: msg)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    /// 네비게이션 오류 시 팝업이면 닫기
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if webView == popupWebView {
            dismissPopup()
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if webView == popupWebView {
            dismissPopup()
        }
    }

    // MARK: - WKUIDelegate (팝업 처리)

    /// window.open() 호출 시: 실제 자식 WKWebView를 생성하여 window.opener 유지
    /// Apple이 전달하는 configuration에 부모-자식 관계 정보가 포함되어 있으므로
    /// 반드시 이 configuration을 사용해야 window.opener가 작동한다.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // 기존 팝업이 있으면 정리
        dismissPopup()

        // ★ Apple이 전달한 configuration을 그대로 사용 → window.opener 보존
        let popup = WKWebView(frame: self.bounds, configuration: configuration)
        popup.customUserAgent = NativeWebViewContainer.userAgent
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.translatesAutoresizingMaskIntoConstraints = false

        // 메인 웹뷰 위에 오버레이로 추가
        addSubview(popup)
        NSLayoutConstraint.activate([
            popup.topAnchor.constraint(equalTo: topAnchor),
            popup.bottomAnchor.constraint(equalTo: bottomAnchor),
            popup.leadingAnchor.constraint(equalTo: leadingAnchor),
            popup.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        self.popupWebView = popup
        return popup  // ← nil이 아닌 실제 WKWebView 반환 → window.opener 작동
    }

    /// window.close() 호출 시: 팝업 제거 (OAuth 완료 후 팝업이 스스로 닫힘)
    func webViewDidClose(_ webView: WKWebView) {
        if webView == popupWebView {
            dismissPopup()
        }
    }

    /// JavaScript alert
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "확인")
        alert.runModal()
        completionHandler()
    }

    /// JavaScript confirm
    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "취소")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }
}
