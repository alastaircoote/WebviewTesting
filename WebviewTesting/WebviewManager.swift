//
//  WebviewManager.swift
//  WebviewTesting
//
//  Created by Alastair on 3/30/23.
//

import Foundation
import WebKit

let TARGET_DOMAIN = "thunder-iced-earwig.glitch.me"

class WebviewManager: NSObject, WKScriptMessageHandlerWithReply {
    
    // Quick hacky method for the webview to send progress events back to the native side:
    
    var messageListener: ((Any) -> String?)? = nil
    @MainActor func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
        return (nil, messageListener?(message.body) ?? "")
    }
    
    
    // For webviews to share storage they must use the same process pool
    static let processPool = WKProcessPool()
    
    // A WKContentWorld isolates JavaScript execution. This allows us to store a bunch of functions and message handlers
    // that web-side code never has access to.
    static let contentWorld = WKContentWorld.world(name: "WebviewTesting")
        
    func createNewWebView() -> AsyncWebview {
        
        let userContentController = WKUserContentController()
        userContentController.addScriptMessageHandler(self, contentWorld: Self.contentWorld, name: "feedback")
        userContentController.addUserScript(WKUserScript(source: actionsJavaScript, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: Self.contentWorld))
        
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        // We must limited to app bound domains in order to use service workers
        config.limitsNavigationsToAppBoundDomains = true
        // Make sure we're sharing storage
        config.processPool = Self.processPool
        let wv = AsyncWebview(frame: CGRect.zero, configuration: config)
        
        return wv
    }
    
    // Not really used here but interested in making future experiments around pooling webviews so we only ever need two
    var webviewPool: [AsyncWebview] = []
    
    override init() {
        super.init()
        let newWebView = createNewWebView()
        webviewPool.append(newWebView)
    }
    
    // As mentioned above I haven't really implemented anything resembling pooling here. But the bones exist:
    func getCommunicationWebview() async throws -> AsyncWebview {
        let webview = webviewPool.first!
        try await webview.ensure(onDomain: TARGET_DOMAIN)
        return webview
    }
    
    // The idea is that the view will 'register' with the webview manager, which will then control where the webview
    // goes and when. But again, for now, we do basically nothing:
    func register(view: WebviewView) -> AsyncWebview {
        return webviewPool.first!
    }
    
    @MainActor static func deleteAllStorage() async  {
        await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date.distantPast)
    }
    
    
}

// Really simple wrappers around the actions JS code
extension WebviewManager {
    func isServiceWorkerInstalled() async throws -> Bool {
        let webview = try await self.getCommunicationWebview()
        
        return try await webview.callAsyncJavaScript("return checkServiceWorkerStatus()", contentWorld: Self.contentWorld) as! Bool
    }
    
    func installServiceWorker() async throws {
        let webview = try await self.getCommunicationWebview()
        _ = try await webview.callAsyncJavaScript("return registerWorker()", contentWorld: Self.contentWorld)
    }
    
    func deleteServiceWorker() async throws {
        let webview = try await self.getCommunicationWebview()
        _ = try await webview.callAsyncJavaScript("return removeWorker()", contentWorld: Self.contentWorld)
    }
    
    func checkCacheStatus() async throws -> (assets: Int, shared: Int) {
        let webview = try await self.getCommunicationWebview()
        let value = try await webview.callAsyncJavaScript("return checkCacheStatus()", contentWorld: Self.contentWorld)
        let dictionary = value as! Dictionary<String,Int>
        return (assets: dictionary["assets"]!, shared: dictionary["shared"]!)
    }
    
    func addToCache() async throws {
        let webview = try await self.getCommunicationWebview()
        _ = try await webview.callAsyncJavaScript("""
            return addToCache(d => window.webkit.messageHandlers.feedback.postMessage(d))
        """, contentWorld: Self.contentWorld)
    }
    
    
    func deleteCache() async throws {
        let webview = try await self.getCommunicationWebview()
        _ = try await webview.callAsyncJavaScript("return deleteCache()", contentWorld: Self.contentWorld)
    }
}
