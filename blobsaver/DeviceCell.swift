//
//  DeviceCell.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-04.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit

class DeviceCell: UICollectionViewCell {
  
  static let identifier = "DeviceCell"
  
  @IBOutlet private weak var deviceThumbnail: UIImageView!
  @IBOutlet private weak var thumbnailLoadingSpinner: UIActivityIndicatorView!
  @IBOutlet private weak var deviceNameLabel: UILabel!
  
  func configure(deviceInfo: DeviceInfo) {
    deviceNameLabel.text = deviceInfo.name
    
    if deviceInfo.identifier.count > 0 {
      downloadDeviceThumbnail(for: deviceInfo.identifier)
    }
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    deviceThumbnail.image = nil
    thumbnailLoadingSpinner.startAnimating()
  }
  
  private func downloadDeviceThumbnail(for deviceIdentifier: String) {
    API.getDeviceThumbnailData(from: deviceIdentifier) {
      guard let thumbnailData = $0 else { return }
      
      DispatchQueue.main.async {
        self.deviceThumbnail.image = UIImage(data: thumbnailData)
        self.thumbnailLoadingSpinner.stopAnimating()
      }
    }
  }
  
  private func random(interval: TimeInterval, variance: Double) -> TimeInterval {
    return interval + variance * Double((Double(arc4random_uniform(1000)) - 500.0) / 500.0)
  }
  
  // Adds 'wiggle' and 'bounce' animations for use when deviceCell is in edit mode.
  func startWiggling() {
    guard contentView.layer.animation(forKey: "wiggle") == nil,
      contentView.layer.animation(forKey: "bounce") == nil
      else { return }
    
    let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
    wiggle.values = [-0.04, 0.04]
    wiggle.autoreverses = true
    wiggle.duration = random(interval: 0.1, variance: 0.025)
    wiggle.repeatCount = .infinity
    contentView.layer.add(wiggle, forKey: "wiggle")
    
    let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
    bounce.values = [4.0, 0.0]
    bounce.autoreverses = true
    bounce.duration = random(interval: 0.12, variance: 0.025)
    bounce.repeatCount = .infinity
    contentView.layer.add(bounce, forKey: "bounce")
  }
  
  func stopWiggling() {
    contentView.layer.removeAllAnimations()
  }
}
