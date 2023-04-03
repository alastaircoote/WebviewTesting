//
//  StatusPanel.swift
//  WebviewTesting
//
//  Created by Alastair on 4/2/23.
//

import SwiftUI

enum ServiceWorkerState {
    case unknown
    case noRegistration
    case registered
}

struct StatusPanel: View {
    
    @State private var workerState: ServiceWorkerState = .unknown
    
    @State private var cacheButtonsDisabled = true
    
    @State private var sharedCacheUsage: Int? = nil
    @State private var assetCacheUsage: Int? = nil
    
    let webviewManager = WebviewManager()
    
    private var serviceWorkerButtonLabel: String {
        switch self.workerState {
        case .unknown:
            return "Working..."
        case .noRegistration:
            return "No"
        case .registered:
            return "Yes"
        }
    }
    
    private var serviceWorkerLabelTextColor: Color? {
        switch self.workerState {
        case .unknown:
            return .gray
        default:
            return nil
        }
    }
    
    private var sharedCacheUsageString : String {
        guard let cache = self.sharedCacheUsage else {
            return "-"
        }
        return "\(cache / 1000)KB"
    }
    
    private var assetCacheUsageString : String {
        guard let cache = self.assetCacheUsage else {
            return "-"
        }
        return "\(cache / 1000)KB"
    }
    
    func checkCacheState() async throws {
        let sizes = try await webviewManager.checkCacheStatus()
        self.assetCacheUsage = sizes.assets
        self.sharedCacheUsage = sizes.shared
        cacheButtonsDisabled = false
    }
    
    func checkWorkerState() async throws {
        if try await webviewManager.isServiceWorkerInstalled() {
            self.workerState = .registered
            
            try await checkCacheState()
            cacheButtonsDisabled = false
        } else {
            self.workerState = .noRegistration
            cacheButtonsDisabled = true
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Service Worker")) {
                    HStack {
                        Text("Service worker installed:")
                        
                        Spacer()
                        Text(serviceWorkerButtonLabel)
                            .foregroundColor(serviceWorkerLabelTextColor)
                        
                    }
                    if workerState != .registered {
                        Button("Register service worker") {
                            self.workerState = .unknown
                            Task {
                                try await webviewManager.installServiceWorker()
                                try await checkWorkerState()
                            }
                        }.disabled(workerState == .unknown)
                    } else {
                        Button("Delete service worker", role: .destructive) {
                            self.workerState = .unknown
                            Task {
                                try await webviewManager.deleteServiceWorker()
                                try await checkWorkerState()
                            }
                        }
                    }
                    
                }
                
                Section(header: Text("Cache")) {
                    HStack {
                        Text("Shared cache usage:")
                        Spacer()
                        Text(sharedCacheUsageString)
                        
                    }
                    HStack {
                        Text("Asset cache usage:")
                        Spacer()
                        Text(assetCacheUsageString)
                    }
                    
          
                    Text("We can simulate loading cached resources. If nothing has been cached yet we'll load the shared cache before asset-specific dummy resources.")
                    Button("Load 10 dummy interactives") {
                        Task {
                            self.cacheButtonsDisabled = true
                            try await webviewManager.addToCache()
                            try await checkCacheState()
                            self.cacheButtonsDisabled = false
                        }
                    }.disabled(cacheButtonsDisabled)
                    Button("Delete cache", role: .destructive) {
                        Task {
                            self.cacheButtonsDisabled = true
                            try await webviewManager.deleteCache()
                            try await checkCacheState()
                            self.cacheButtonsDisabled = false
                        }
                    }.disabled(cacheButtonsDisabled)
                }
                
                
                Section(header: Text("Webview")) {
                    Text("When the service worker is installed this webview will load the page locally with no network connectivity required. Without the worker it will load remotely. No code change is required on the native side.")
                    NavigationLink("Open webview at root URL") {
                        WebviewView(webviewManager: self.webviewManager)
                    }
                }
                
                Section(header: Text("In case of emergency")) {
                    Button("Clear all webview cache data", role: .destructive) {
                        self.workerState = .unknown
                        Task {
                            await WebviewManager.deleteAllStorage()
                            try await checkWorkerState()
                        }
                    }
                }
                
                   
            }
            .navigationTitle("Webview Tests")
        }.onAppear {
            Task {
                
                webviewManager.messageListener = { message in
                    let payload = message as! Dictionary<String, Any>
                    if payload["cacheName"] as! String == "assets" {
                        self.assetCacheUsage = payload["newCacheSize"] as? Int
                    }
                    if payload["cacheName"] as! String == "shared" {
                        self.sharedCacheUsage = payload["newCacheSize"] as? Int
                    }
                    return "true"
                }
                try await checkWorkerState()
            }
         
        }
        
    }
}

struct StatusPanel_Previews: PreviewProvider {
    static var previews: some View {
        StatusPanel()
    }
}
