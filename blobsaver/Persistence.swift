//
//  Persistence.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-11.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit
import CwlUtils

struct DeviceInfo {
  
  let name: String
  let ecid: String // Always stored in decimal format.
  let identifier: String // Device model identifier.
  let boardConfig: String // Device CPU model.
  
  init(name: String, ecid: String, identifier: String, boardConfig: String) {
    self.name = name
    self.ecid = ecid
    self.identifier = identifier
    self.boardConfig = boardConfig
  }
  
  static let `default`: DeviceInfo = {
    #if IOS_SIMULATOR
    return DeviceInfo(name: UIDevice.current.name, ecid: "", identifier: "iPhone10,1", boardConfig: "")
    #else
    return DeviceInfo(name: UIDevice.current.name, ecid: "", identifier: Sysctl.model, boardConfig: Sysctl.machine)
    #endif
  }()
  
  var type: String {
    return identifier.replacingOccurrences(of: "[^a-zA-Z]", with: "", options: .regularExpression)
  }
  
  static func requiresBoardConfig(for identifier: String) -> Bool {
    return ["iPhone8,1", "iPhone8,2", "iPhone8,4", "iPad6,11", "iPad6,12"].contains(identifier)
  }
  
  var requiresBoardConfig: Bool {
    return DeviceInfo.requiresBoardConfig(for: identifier)
  }
  
  var isComplete: Bool {
    return ecid.count > 0 && (!requiresBoardConfig || boardConfig.count > 0)
  }
}

// Allows classes to handle their UI changes in response to cloud changes.
protocol Synchronizable {
  func syncCloudChanges()
}

// Automatically handles persistence and synchronization between local and cloud data.
class Persistence {
  
  private static let submissionTicketExpireInterval: TimeInterval = 60 * 15 // Prevent resubmitting SHSH request for 15 minutes.
  private static let lastSubmissionTicketKey = "lastSubmissionTicket"
  private static let lastSyncDateKey = "lastSyncDate"
  private static let deviceCountKey = "deviceCount"
  
  class func isLastSubmissionTicketActive(for deviceECID: String) -> Bool {
    guard let deviceInfoDict = UserDefaults.standard.dictionary(forKey: deviceECID),
      let lastSubmissionDate = deviceInfoDict[lastSubmissionTicketKey] as? Date
      else { return false }
    
    return Date().timeIntervalSince(lastSubmissionDate) < submissionTicketExpireInterval
  }
  
  class func updateLastSubmissionTicket(for deviceECID: String) {
    var deviceInfoDict = UserDefaults.standard.dictionary(forKey: deviceECID) ?? [:]
    deviceInfoDict[lastSubmissionTicketKey] = Date()
    UserDefaults.standard.set(deviceInfoDict, forKey: deviceECID)
  }
  
  // Determines whether the cloud data is newer than the local data (should be prioritized).
  // NOTE: - returns nil if either date is nil or if both dates are equal.
  private class func checkCloudSyncPriority() -> Bool? {
    guard let lastLocalSyncDate = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date,
      let lastCloudSyncDate = NSUbiquitousKeyValueStore.default.object(forKey: lastSyncDateKey) as? Date,
      lastLocalSyncDate != lastCloudSyncDate
      else { return nil }
    
    return lastLocalSyncDate < lastCloudSyncDate
  }
  
  // Returns the device info list from the latest data source, or the default list if both data sources are empty.
  class func getDeviceInfoList() -> [DeviceInfo] {
    let shouldPrioritizeCloudChanges = checkCloudSyncPriority() == true
    
    let localDeviceCount = UserDefaults.standard.integer(forKey: deviceCountKey)
    let cloudDeviceCount = Int(truncatingIfNeeded: NSUbiquitousKeyValueStore.default.longLong(forKey: deviceCountKey))
    let deviceCount: Int
    
    if shouldPrioritizeCloudChanges {
      deviceCount = cloudDeviceCount == 0 ? localDeviceCount : cloudDeviceCount
    } else {
      deviceCount = localDeviceCount == 0 ? cloudDeviceCount : localDeviceCount
    }
    
    let defaultDeviceInfoList = [DeviceInfo.default]
    guard deviceCount > 0 else { return defaultDeviceInfoList }
    var deviceInfoList: [DeviceInfo] = []
    
    for index in 0 ..< deviceCount {
      let deviceKey = "device" + String(describing: index)
      let localDeviceInfoDict = UserDefaults.standard.dictionary(forKey: deviceKey) as? [String:String]
      let cloudDeviceInfoDict = NSUbiquitousKeyValueStore.default.dictionary(forKey: deviceKey) as? [String:String]
      let deviceInfoDict: [String:String]?
      
      if shouldPrioritizeCloudChanges {
        deviceInfoDict = cloudDeviceInfoDict ?? localDeviceInfoDict
      } else {
        deviceInfoDict = localDeviceInfoDict ?? cloudDeviceInfoDict
      }
      
      guard let deviceName = deviceInfoDict?["name"],
        let deviceECID = deviceInfoDict?["ecid"],
        let deviceIdentifier = deviceInfoDict?["identifier"],
        let deviceBoardConfig = deviceInfoDict?["boardConfig"]
        else { return defaultDeviceInfoList }
      
      let deviceInfo = DeviceInfo(name: deviceName,
                                  ecid: deviceECID,
                                  identifier: deviceIdentifier,
                                  boardConfig: deviceBoardConfig)
      
      deviceInfoList.append(deviceInfo)
    }
    
    return deviceInfoList
  }
  
  // Updates the device info list to local and cloud storage.
  // NOTE: - if locally is enabled, only local data is overwritten.
  class func updateDeviceInfoList(with deviceInfoList: [DeviceInfo], locally: Bool = false) {
    UserDefaults.standard.set(deviceInfoList.count, forKey: deviceCountKey)
    
    if !locally {
      UserDefaults.standard.set(Date(), forKey: lastSyncDateKey)
      NSUbiquitousKeyValueStore.default.set(Date(), forKey: lastSyncDateKey)
      NSUbiquitousKeyValueStore.default.set(deviceInfoList.count, forKey: deviceCountKey)
    } else {
      let cloudSyncDate = NSUbiquitousKeyValueStore.default.object(forKey: lastSyncDateKey) as? Date
      UserDefaults.standard.set(cloudSyncDate, forKey: lastSyncDateKey)
    }
    
    deviceInfoList.enumerated().forEach {
      let deviceInfoDict = ["name": $1.name, "ecid": $1.ecid, "identifier": $1.identifier, "boardConfig": $1.boardConfig]
      let deviceKey = "device" + String(describing: $0)
      UserDefaults.standard.set(deviceInfoDict, forKey: deviceKey)
      
      if !locally {
        NSUbiquitousKeyValueStore.default.set(deviceInfoDict, forKey: deviceKey)
      }
    }
  }
  
  // Synchronizes data changes between local and cloud. Returns true if cloud data is newer than local data.
  @discardableResult class func syncCloudChanges() -> Bool {
    guard UserDefaults.standard.synchronize(),
      NSUbiquitousKeyValueStore.default.synchronize()
      else {
        print("ERROR: cannot synchronize local and cloud data.")
        return false
    }
    
    guard let shouldPrioritizeCloudChanges = checkCloudSyncPriority() else { return false }
    updateDeviceInfoList(with: getDeviceInfoList(), locally: shouldPrioritizeCloudChanges)
    return shouldPrioritizeCloudChanges
  }
}
