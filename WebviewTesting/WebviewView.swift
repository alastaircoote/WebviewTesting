//
//  WebviewView.swift
//  WebviewTesting
//
//  Created by Alastair on 3/30/23.
//

import Foundation

import SwiftUI

struct WebviewView: View {
    
    let webviewManager: WebviewManager
    
    @State private var webview: AsyncWebview?
    
    var body: some View {
        VStack {
            if let wv = self.webview {
                WebView(webview: wv, url: URL(string: "https://" + TARGET_DOMAIN + "/")!)
            }
        }
            .navigationTitle("Webview")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                self.webview = webviewManager.register(view: self)
            }
            
    }
    
   
}


import WebKit
 
struct WebView: UIViewRepresentable {
 
    let webview: AsyncWebview
    let url: URL
 
    func makeUIView(context: Context) -> AsyncWebview {
        return webview
    }
 
    func updateUIView(_ webView: AsyncWebview, context: Context) {
        Task {
            let request = URLRequest(url: url)
            try! await webView.load(request)
        }
    }
    
    static func dismantleUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator) {
        
    }
}
