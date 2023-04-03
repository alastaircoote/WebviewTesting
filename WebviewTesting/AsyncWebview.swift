//
//  AsyncWebview.swift
//  WebviewTesting
//
//  Created by Alastair on 4/1/23.
//

import Foundation
import WebKit

// Barely fleshed out but the idea here is to be able to do things like load URLs with Swift
// async calls when they're loaded, rather than relying on delegates etc etc

enum AsyncWebviewError : Error {
    case newRequestMade
    case mismatchedNavigationEntries
    case noNavigationGenerated
    case noCurrentNavigation
}

struct AsyncWebviewNavigation {
    let continuation: CheckedContinuation<(), any Error>
    let navigation: WKNavigation
}

class AsyncWebviewInternalNavigationDelegate : NSObject, WKNavigationDelegate {
    
    var externalNavigationDelegate: WKNavigationDelegate?
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let asyncWebView = webView as? AsyncWebview else {
            fatalError("Used an AsyncWebviewInternalNavigationDelete with a non-async webview")
        }
        
        guard let currentNavigation = asyncWebView.currentNavigation else {
            fatalError("Received WKNavigationDelegate event unexpectedly")
        }
        
        if currentNavigation.navigation != navigation {
            currentNavigation.continuation.resume(throwing: AsyncWebviewError.mismatchedNavigationEntries)
            return
        }
        asyncWebView.currentNavigation = nil
        currentNavigation.continuation.resume(returning: ())
    }
    
}

class AsyncWebview : WKWebView {
    
    var currentNavigation: AsyncWebviewNavigation?
    let internalNavigationDelegate = AsyncWebviewInternalNavigationDelegate()
    
    func stopCurrentNavigationIfRunning() {
        if let navigation = self.currentNavigation {
            // we have a pending navigation, stop it
            self.stopLoading()
            navigation.continuation.resume(throwing: AsyncWebviewError.newRequestMade)
        }
    }
    
    func performNavigation(callback: () -> WKNavigation?) async throws {
        if let navigation = self.currentNavigation {
            // we have a pending navigation, stop it
            self.stopLoading()
            navigation.continuation.resume(throwing: AsyncWebviewError.newRequestMade)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            
            if super.navigationDelegate == nil {
                super.navigationDelegate = self.internalNavigationDelegate
            }
            
            guard let navigation = callback() else {
                return continuation.resume(throwing: AsyncWebviewError.noNavigationGenerated)
            }
            
            self.currentNavigation = AsyncWebviewNavigation(continuation: continuation, navigation: navigation)
            
        }
    }
    
    func load(_ request: URLRequest) async throws {
        try await performNavigation {
            super.load(request)
        }
    }
    
     func loadHTMLString(_ string: String, baseURL: URL?) async throws {
         try await performNavigation {
             super.loadHTMLString(string, baseURL: baseURL)
         }
    }
    
    override var navigationDelegate: WKNavigationDelegate? {
        get {
            return self.internalNavigationDelegate.externalNavigationDelegate
        }
        
        set(value) {
            self.internalNavigationDelegate.externalNavigationDelegate = value
        }
    }
    
    // Service Workers are domain-based so we need to make sure we're on the correct
    // domain. A totally empty page is fine.
    func ensure(onDomain domain: String) async throws {
        if super.url?.host() == domain {
            return
        }
        var domainComponents = URLComponents()
        domainComponents.scheme = "https"
        domainComponents.host = domain
        
        try await self.loadHTMLString("", baseURL: domainComponents.url)
    }
    
}
