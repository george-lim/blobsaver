//
//  NoClipTableView.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-04.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit

// HACK: - TSSSaverCell contains a WKWebView which needs to clip out of bounds. Subclassing UITableView and overriding
//   hitTest allows TSSSaverCell to receive touch events in areas of the WKWebView that are out of bounds.
class NoClipTableView: UITableView {
  
  // Since iOS 11, UITableViewWrapperView no longer exists.
  private var tableViewWrapperView: UIView? {
    guard #available(iOS 11.0, *) else {
      return subviews
        .filter{ String(describing: type(of: $0)) == "UITableViewWrapperView" }
        .first
    }
    
    return self
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    tableViewWrapperView?.layer.zPosition = 1 // Makes TSSSaverCell's WKWebView display on top of the section headers.
  }
  
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let tssSaverCell = tableViewWrapperView?.subviews
      .compactMap { $0 as? TSSSaverCell }
      .first
    
    let cellSubviews = tssSaverCell?.contentView.subviews
    return cellSubviews?
      .compactMap { return $0.hitTest($0.convert(point, from: self), with: event) }
      .first
      ?? self
  }
}
