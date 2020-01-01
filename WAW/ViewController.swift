//
//  ViewController.swift
//  WAW
//
//  Created by Sebastian Faul on 02.12.18.
//  Copyright © 2018 Sebastian Faul. All rights reserved.
//

import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, UIDropInteractionDelegate  {
    
    enum Views {
        case Side
        case Chat
        case Both
    }
    
    enum PageState {
        case ScanCode
        case PageLoading
        case PageLoaded
        case Undefined
    }
    
    
    private var observer: NSKeyValueObservation?
    var wkView:WKWebView
    var status:PageState
    var statusView:Views
    var frst:Bool
    
    let js_getPageState = """
            // simple send state method to easily send the current state of the site
            function sndste(state) {
                switch (state) {
                    case 0:
                        webkit.messageHandlers.state.postMessage("code");
                        break;
                    case 1:
                        webkit.messageHandlers.state.postMessage("loading");
                        break;
                    case 2:
                        webkit.messageHandlers.state.postMessage("loaded");
                        break;
                }
            }
            
            
            function sndnotify() {
                webkit.messageHandlers.notify.postMessage("");
            }

            var c = new XMLSerializer().serializeToString(document);

            if (c.includes("Scan me!")) {
                sndste(0);
            } else {
                if(c.includes("_3q4NP k1feT")) { // if page contains side view (list of chats)
                    sndste(2);
                    var meta = document.createElement('meta');
                    meta.setAttribute('name', 'viewport');
                    meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
                    document.getElementsByTagName('head')[0].appendChild(meta);
                    document.getElementsByClassName('app _3dqpi two')[0].style.minWidth = "320px";
                    sndnotify();
                } else {
                sndste(1);
                }
            }
            """
    
    let js_update = "webkit.messageHandlers.update.postMessage('update_data');"
    
    let js_addBackButton = """
            if (document.getElementById('backbutton') == null) {
                var backbtn = document.createElement('div');
                backbtn.setAttribute('id', 'backbutton');
                backbtn.style.marginRight = "10px";
                backbtn.innerHTML = '<span><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path fill="#263238" d="M20 11H7.8l5.6-5.6L12 4l-8 8 8 8 1.4-1.4L7.8 13H20v-2z"></path></svg></span>';
                var header = document.getElementsByClassName('_3AwwN')[0];
                header.insertBefore(backbtn, header.childNodes[0]);
                document.getElementById('backbutton').style.display = 'none';
                document.getElementById('backbutton').addEventListener('click', function() {webkit.messageHandlers.back.postMessage("back");});
            }
            """
    
    func setTrigger(){
        wkView.evaluateJavaScript("document.getElementsByClassName('_1f1zm')[0].addEventListener('click', function(){webkit.messageHandlers.notify.postMessage('trigger');});", completionHandler: nil)
    }
    
    func setView(view:Views) {
        if (status == PageState.PageLoaded) {
            self.statusView = view
            switch (view){
            case Views.Side:
                wkView.evaluateJavaScript("""
                document.getElementsByClassName('k1feT') [0].style.flex = "0 0 100%";         // start new Chat etc.
                document.getElementsByClassName('_3q4NP k1feT') [1].style.flex = "0 0 100%";  // side view ( List of chats)
                document.getElementsByClassName('_1Iexl')[0].style.flex = "0 0 0%";           // search etc.
                document.getElementsByClassName('_3q4NP _1Iexl')[1].style.flex = "0 0 0%";    // chat view

                document.getElementById('backbutton').style.display = "none";
                """, completionHandler: nil)
                break;
            case Views.Chat:
                wkView.evaluateJavaScript("""
                document.getElementsByClassName('k1feT') [0].style.flex = "0 0 0%";
                document.getElementsByClassName('_3q4NP k1feT') [1].style.flex = "0 0 0%";
                document.getElementsByClassName('_1Iexl')[0].style.flex = "0 0 100%";
                document.getElementsByClassName('_3q4NP _1Iexl')[1].style.flex = "0 0 100%";

                document.getElementsByClassName('_3q4NP _2yeJ5')[0].style.width = "100%";
                document.getElementsByClassName('_3q4NP _2yeJ5')[0].style.flex = "0 0 100%";
                document.getElementsByClassName('_3q4NP _2yeJ5')[0].style.left = "0";

                document.getElementById('backbutton').style.display = "block";
                """, completionHandler: nil)
                setTrigger()
                break;
            case Views.Both:
                wkView.evaluateJavaScript("""
                document.getElementsByClassName('k1feT') [0].style.flex = "0 0 35%";
                document.getElementsByClassName('_3q4NP k1feT') [1].style.flex = "0 0 35%";
                document.getElementsByClassName('_1Iexl')[0].style.flex = "0 0 65%";
                document.getElementsByClassName('_3q4NP _1Iexl')[1].style.flex = "0 0 65%";

                document.getElementsByClassName('_3q4NP _2yeJ5')[0].style.width = "65%";
                document.getElementsByClassName('_3q4NP _2yeJ5')[0].style.flex = "0 0 65%";
                document.getElementsByClassName('_3q4NP _2yeJ5')[0].style.left = "35%";

                document.getElementById('backbutton').style.display = "none";
                """, completionHandler: nil)
                setTrigger()
                break;
            }
        }
    }
    
    func restoreChats() {
        wkView.evaluateJavaScript("document.getElementsByClassName('_1f1zm')[0].removeEventListener('click');", completionHandler: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        let script = WKUserScript(source: js_update, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        
        let contentController = WKUserContentController()
        contentController.addUserScript(script)
        
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.userContentController = contentController
        
        wkView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        
        status = PageState.Undefined
        statusView = Views.Both
        frst = true
        
        super.init(coder: aDecoder)
        
        contentController.add(self, name: "debug")
        contentController.add(self, name: "state")
        contentController.add(self, name: "notify")
        contentController.add(self, name: "update")
        contentController.add(self, name: "back")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        observer = view.layer.observe(\.bounds) { object, _ in
            if(object.bounds.width < 650.0) {
                if(self.statusView == Views.Both) {
                    self.statusView = Views.Side
                }
                self.setView(view: self.statusView)
                self.setTrigger()
            } else {
                self.setView(view: Views.Both)
            }
            
            self.wkView.frame = object.bounds
            self.wkView.setNeedsLayout()
            self.wkView.layoutIfNeeded()
            self.view.bounds = object.bounds
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        
        wkView.topAnchor.anchorWithOffset(to: view.topAnchor)
        wkView.leftAnchor.anchorWithOffset(to: view.leftAnchor)
        wkView.bottomAnchor.anchorWithOffset(to: view.bottomAnchor)
        wkView.rightAnchor.anchorWithOffset(to: view.rightAnchor)
        wkView.frame = self.view.bounds
        wkView.setNeedsLayout()
        wkView.layoutIfNeeded()
        
        wkView.navigationDelegate = self
        wkView.allowsBackForwardNavigationGestures = false
        wkView.scrollView.isScrollEnabled = true
        wkView.scrollView.bounces = false
        
        wkView.scrollView.delegate = self
        
        self.view.addSubview(wkView)
        
        view.addInteraction(UIDropInteraction(delegate: self ))
        
        let url = URL(string: "https://web.whatsapp.com")!
        let userAgent = "Mozilla/5.0 (X11; Linux i586; rv:31.0) Gecko/20100101 Firefox/71.0"
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        wkView.customUserAgent = userAgent
        wkView.load(request)
    }
    
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        switch(message.name) {
        case "debug":
            print(message.body)
            break;
        case "state":
            switch(message.body as! String){
            case "code":
                status = PageState.ScanCode
                break;
            case "loading":
                status = PageState.PageLoading
                break;
            case "loaded":
                status = PageState.PageLoaded
                break;
            default:
                status = PageState.Undefined
            }
            
            break;
        case "notify":
            if ( self.view.bounds.width < 650.0) {
                if(frst) {
                    frst = false
                    setView(view: Views.Side)
                } else {
                    setView(view: Views.Chat)
                }
            }
            wkView.frame = self.view.bounds
            wkView.setNeedsLayout()
            wkView.layoutIfNeeded()
            
            self.wkView.evaluateJavaScript(self.js_addBackButton, completionHandler: nil)
            break;
        case "update":
            if (String(describing: message.body).contains("update_data")) {
                wkView.evaluateJavaScript(js_getPageState, completionHandler: nil)
            }
            break;
        case "back":
            if(message.body as! String == "back") {
                if (self.view.bounds.width < 650.0) {
                    setView(view: Views.Side)
                    setTrigger()
                }
            }
            break;
        default:
            // do nothing...
            return;
        }
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        if( self.view.bounds.width < 650.0) {
            self.setView(view: Views.Chat)
        }
        return true
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated  {
            if let url = navigationAction.request.url,
                UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                
            }
        } else {
            decisionHandler(.allow)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        observer?.invalidate()
    }
    
}
extension ViewController: UIScrollViewDelegate {
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
}


