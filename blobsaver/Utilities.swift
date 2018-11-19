//
//  Utilities.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-03.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit
import AudioToolbox

// MARK: - Basic

extension String {
  func matches(_ regex: String) -> [String] {
    do {
      let regex = try NSRegularExpression(pattern: regex)
      let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
      return results.map { String(self[Range($0.range, in: self)!]) }
    } catch let error {
      print("ERROR: invalid regex.\n" + error.localizedDescription)
      return []
    }
  }
}

// MARK: - Custom

struct Colors {
  static let silver = UIColor(white: 0.5, alpha: 1)
  static let green = UIColor(red: 76/255, green: 217/255, blue: 100/255, alpha: 1)
  static let orange = UIColor(red: 1, green: 149/255, blue: 0, alpha: 1)
  static let red = UIColor(red: 1, green: 45/255, blue: 85/255, alpha: 1)
  static let blue = UIColor(red: 90/255, green: 200/255, blue: 250/255, alpha: 1)
}

class HapticFeedback {
  class func pop() {
    if #available(iOS 10.0, *) {
      let generator = UIImpactFeedbackGenerator(style: .heavy)
      generator.prepare()
      generator.impactOccurred()
    } else {
      AudioServicesPlaySystemSound(1520)
    }
  }
}
