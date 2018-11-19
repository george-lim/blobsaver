//
//  AppDelegate.swift
//  blobsaver
//
//  Created by George Lim on 2018-10-14.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Persistence.syncCloudChanges()
    addNotificationObserver()
    return true
  }
  
  // Updates the UI to match the cloud changes.
  @objc func syncCloudChanges() {
    guard Persistence.syncCloudChanges(),
      let navigationController = window?.rootViewController as? UINavigationController,
      let topViewController = navigationController.topViewController as? Synchronizable
      else { return }
    
    topViewController.syncCloudChanges()
  }
  
  private func addNotificationObserver() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(syncCloudChanges),
                                           name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                           object: NSUbiquitousKeyValueStore.default)
  }
}
