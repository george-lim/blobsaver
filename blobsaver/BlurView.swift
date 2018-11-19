//
//  BlurView.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-06.
//  Copyright © 2018 George Lim. All rights reserved.
//

import VisualEffectView

// A UIVisualEffectView subclass which supports custom colorTint, colorTintAlpha, and blurRadius values.
// NOTE: - Modifying the BlurView layer is not supported in iOS 10 (eg. Adding a layer shadow).
class BlurView: VisualEffectView {
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    colorTint = .black
    colorTintAlpha = 0.3
    blurRadius = 15
  }
}
