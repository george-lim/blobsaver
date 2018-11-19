//
//  DevicePagerController.swift
//  blobsaver
//
//  Created by George Lim on 2018-10-14.
//  Copyright © 2018 George Lim. All rights reserved.
//

import Foundation
import XLPagerTabStrip

class DevicePagerController: ButtonBarPagerTabStripViewController, Synchronizable, VersionTimelineDelegate, DeviceGridDelegate {
  
  private var deviceInfoList: [DeviceInfo]?
  private var isDeviceSetupEnabled = true
  
  override func viewDidLoad() {
    setupButtonBarView()
    super.viewDidLoad()
  }
  
  override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    guard motion == .motionShake && navigationController?.visibleViewController == self && isDeviceSetupEnabled,
      let deviceGridController = storyboard?.instantiateViewController(withIdentifier: DeviceGridController.storyboardID) as? DeviceGridController
      else { return }
    
    let deviceInfoList = self.deviceInfoList ?? Persistence.getDeviceInfoList()
    deviceGridController.configure(delegate: self, deviceInfoList: deviceInfoList)
    navigationController?.pushViewController(deviceGridController, animated: true)
  }
  
  private func setupButtonBarView() {
    settings.style.buttonBarBackgroundColor = .clear
    settings.style.selectedBarHeight = 0
    settings.style.buttonBarItemBackgroundColor = .clear
    settings.style.buttonBarItemFont = .boldSystemFont(ofSize: 17)
    
    changeCurrentIndexProgressive = { (oldCell: ButtonBarViewCell?, newCell: ButtonBarViewCell?,
      progressPercentage: CGFloat, changeCurrentIndex: Bool, animated: Bool) -> Void in
      
      guard changeCurrentIndex == true else { return }
      oldCell?.label.textColor = Colors.silver
      newCell?.label.textColor = .white
    }
  }
  
  // MARK: - Synchronizable
  
  func syncCloudChanges() {
    deviceInfoList = nil
    reloadPagerTabStripView()
  }
  
  // MARK: - PagerTabStripDataSource
  
  override public func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {
    let deviceInfoList = self.deviceInfoList ?? Persistence.getDeviceInfoList()
    return deviceInfoList.compactMap {
      let versionTimelineController = storyboard?.instantiateViewController(withIdentifier: VersionTimelineController.storyboardID) as? VersionTimelineController
      versionTimelineController?.configure(delegate: self, deviceInfo: $0)
      return versionTimelineController
    }
  }
  
  // MARK: -  VersionTimelineDelegate
  
  func disableDeviceSetup() {
    isDeviceSetupEnabled = false
  }
  
  // MARK: - DeviceGridDelegate
  
  func updateDeviceInfoList(with deviceInfoList: [DeviceInfo]) {
    self.deviceInfoList = deviceInfoList
    reloadPagerTabStripView()
  }
}
