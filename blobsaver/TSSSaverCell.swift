//
//  TSSSaverCell.swift
//  blobsaver
//
//  Created by George Lim on 2018-10-28.
//  Copyright © 2018 George Lim. All rights reserved.
//

import WebKit

protocol TSSSaverCellDelegate {
  func handleRequestSubmit()
}

class TSSSaverCell: UITableViewCell, WKNavigationDelegate {
  
  static let identifier = "TSSSaverCell"
  
  private var delegate: TSSSaverCellDelegate?
  private var deviceInfo: DeviceInfo!
  private var deviceModelOption: Int!
  
  private lazy var webView: WKWebView = {
    let webConfiguration = WKWebViewConfiguration()
    
    if let deviceModelOption = deviceModelOption {
      // HACK: - A very ad-hoc solution to hide all elements that are not the submit form and Google ReCaptcha.
      //   Populates the form fields with deviceInfo data.
      var launchScriptSource = """
      let sheet = (function() {
      let style = document.createElement('style');
      document.head.appendChild(style);
      return style.sheet;
      })();
      
      sheet.insertRule('body { padding: 0; background-color: transparent; }', 0);
      sheet.insertRule('body > *:not(div:last-of-type:not(.box)), form > *:not(#newCaptcha) { display: none; }', 0);
      sheet.insertRule('.box { margin: 0; padding: 0; background-color: transparent; }', 0);
      sheet.insertRule('body > div:last-of-type:not(.box) > :first-child { background-color: transparent !important; -webkit-tap-highlight-color: transparent; }', 0);
      
      document.body.querySelector('.box > form').parentNode.style.display = 'block';
      document.body.querySelector('[name=ECIDType]').value = 1;
      document.body.querySelector('[name=ECID]').value = '\(deviceInfo.ecid)';
      document.body.querySelector('#deviceType').value = '\(deviceInfo.type)';
      document.body.querySelector('#deviceModel').value = '\(deviceModelOption)';
      """
      
      if deviceInfo.boardConfig.count > 0 {
        launchScriptSource += """
        let inp_bc = document.body.querySelector('#inp_bc');
        inp_bc.removeAttribute('name');
        inp_bc.setAttribute('name', 'boardConfig');
        inp_bc.value = '\(deviceInfo.boardConfig)';
        """
      }
      
      let launchScript = WKUserScript(source: launchScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
      let contentController = WKUserContentController()
      contentController.addUserScript(launchScript)
      webConfiguration.userContentController = contentController
    }
    
    let webView = WKWebView(frame: .zero, configuration: webConfiguration)
    webView.navigationDelegate = self
    webView.backgroundColor = .clear
    webView.isOpaque = false
    webView.isHidden = true
    webView.scrollView.isScrollEnabled = false
    
    contentView.addSubview(webView)
    
    if let url = URL(string: API.TSSSaverURL.root) {
      webView.load(URLRequest(url: url))
    }
    
    return webView
  }()
  
  @IBOutlet private weak var webViewLoadingSpinner: UIActivityIndicatorView!
  @IBOutlet private weak var submitLabel: UILabel!
  
  func configure(delegate: TSSSaverCellDelegate, deviceInfo: DeviceInfo, deviceModelOption: Int) {
    self.delegate = delegate
    self.deviceInfo = deviceInfo
    self.deviceModelOption = deviceModelOption
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    webView.frame.size = CGSize(width: contentView.bounds.width, height: 600)
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    guard webView.isHidden else { return }
    webViewLoadingSpinner.startAnimating()
  }
  
  // MARK: - WKNavigationDelegate
  
  private func loadPostLaunchScript() {
    // HACK: - Captures the site key, deletes the old ReCaptcha element, and re-renders a new ReCaptcha element
    //   to auto submit form when ReCaptcha successfully verifies the user. Assumes that the TSSSaver website uses
    //   Google ReCaptcha v2.
    let postScriptSource = """
    document.body.style.paddingLeft = '\(layoutMargins.left)px';
    
    let oldCaptcha = document.body.querySelector('div.g-recaptcha');
    let siteKey = oldCaptcha.getAttribute('data-sitekey');
    oldCaptcha.parentNode.removeChild(oldCaptcha);
    
    let newCaptcha = document.createElement('div');
    newCaptcha.id = 'newCaptcha';
    document.body.querySelector('form').appendChild(newCaptcha);

    grecaptcha.render('newCaptcha', {
    'sitekey': siteKey,
    'theme': 'dark',
    'callback': function() { document.body.querySelector('input[type=submit]').click(); }
    });
    """
    
    webView.evaluateJavaScript(postScriptSource)
  }
  
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    // HACK: - Add a 0.5s delay to launch the post-launch script because ReCaptcha sometimes takes more time to load.
    // NOTE: - If ReCaptcha fails to load in time, the webView looks empty because the new ReCaptcha is not rendered.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.loadPostLaunchScript()
      webView.isHidden = false
      self.webViewLoadingSpinner.stopAnimating()
    }
  }
  
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if navigationAction.navigationType == .formSubmitted {
      submitLabel.isHidden = false
      delegate?.handleRequestSubmit()
      
      UIView.animate(withDuration: 0.25, animations: {
        webView.alpha = 0
      }) { _ in
        webView.isHidden = true
      }
    }
    
    decisionHandler(.allow)
  }
}
