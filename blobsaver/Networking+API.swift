//
//  Networking+API.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-09.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit
import SystemConfiguration

class Networking {
  
  // Determines whether the user has a way to connect to the internet (via Cellular or Wi-Fi).
  private static var isDeviceConnected: Bool {
    var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)
    
    let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        SCNetworkReachabilityCreateWithAddress(nil, $0)
      }
    }
    
    var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
    guard SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == true else { return false }
    
    let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
    let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
    return isReachable && !needsConnection
  }
  
  class func launch(url urlString: String) {
    guard isDeviceConnected else {
      print("ERROR: cannot create connection.")
      return
    }
    
    guard let url = URL(string: urlString) else {
      print("ERROR: cannot create URL.")
      return
    }
    
    if #available(iOS 10.0, *) {
      UIApplication.shared.open(url, options: [:])
    } else {
      UIApplication.shared.openURL(url)
    }
  }
  
  // Performs a HTTP GET request.
  fileprivate class func get(url urlString: String, completion: ((Data?) -> Void)?) {
    guard isDeviceConnected else {
      print("ERROR: cannot create connection.")
      completion?(nil)
      return
    }
    
    guard let url = URL(string: urlString) else {
      print("ERROR: cannot create URL.")
      completion?(nil)
      return
    }
    
    let session = URLSession(configuration: .default)
    let urlRequest = URLRequest(url: url)
    
    session.dataTask(with: urlRequest) {
      if let error = $2 {
        print("ERROR: cannot call GET on URL.\n" + error.localizedDescription)
        completion?(nil)
        return
      }
      
      guard let responseData = $0 else {
        print("ERROR: did not receive data.")
        completion?(nil)
        return
      }
      
      completion?(responseData)
      }.resume()
  }
  
  fileprivate class func parseJSON(from responseData: Data) -> Any {
    do {
      return try JSONSerialization.jsonObject(with: responseData, options: [])
    } catch {
      print("ERROR: cannot parse data to JSON.")
      return [:]
    }
  }
}

class API {
  
  struct TSSSaverURL {
    
    static let root = "https://tsssaver.1conan.com/"
    fileprivate static let deviceModelsJSON = root + "json/deviceModels.json"
    fileprivate static let devicesJSON = root + "json/devices.json"
    
    fileprivate static func shsh(for deviceECID: String) -> String {
      return "https://stor.1conan.com/tsssaver/shsh/" + deviceECID
    }
  }
  
  private struct IPSWURL {
    
    static func firmware(for deviceIdentifier: String) -> String {
      return "https://api.ipsw.me/v4/device/" + deviceIdentifier + "?type=ipsw"
    }
    
    static func deviceThumbnail(for deviceIdentifier: String) -> String {
      return "https://ipsw.me/api/images/320x/assets/images/devices/" + deviceIdentifier + ".png"
    }
  }
  
  // Creates an array partitioning elements in firmwareList by major version number.
  private class func partitionByMajorVersion(_ firmwareList: [[String:Any]]) -> [[[String:Any]]] {
    var majorVersions: [[[String:Any]]] = []
    var currentVersion = ""
    var i = -1
    
    firmwareList.forEach {
      guard let fullVersion = $0["version"] as? String,
        let majorVersion = fullVersion.components(separatedBy: ".").first
        else { return }
      
      if majorVersion != currentVersion {
        majorVersions.append([])
        i += 1
        currentVersion = majorVersion
      }
      
      majorVersions[i].append($0)
    }
    
    return majorVersions
  }
  
  // Returns an array of firmware data on version number, build id, and currently signed status, sorted by major version.
  class func getFirmwareList(from deviceIdentifier: String, completion: (([[[String:Any]]]?) -> Void)?) {
    Networking.get(url: IPSWURL.firmware(for: deviceIdentifier)) {
      guard let responseData = $0,
        let json = Networking.parseJSON(from: responseData) as? [String:Any],
        let firmwareList = json["firmwares"] as? [[String:Any]]
        else {
          print("ERROR: cannot get firmware list from JSON.")
          completion?(nil)
          return
      }
      
      let filteredFirmwareList = firmwareList.map { $0.filter { ["version", "buildid", "signed"].contains($0.key) } }
      let partitionedFirmwareList = partitionByMajorVersion(filteredFirmwareList)
      completion?(partitionedFirmwareList)
    }
  }
  
  // Returns an array of firmware versions whose SHSH blobs have already been saved to TSSSaver.
  class func getBlobList(from deviceECID: String, completion: (([String]?) -> Void)?) {
    Networking.get(url: TSSSaverURL.shsh(for: deviceECID)) {
      guard let responseData = $0,
        let html = String(data: responseData, encoding: .ascii)
        else {
          print("ERROR: cannot parse HTML from response data.")
          completion?(nil)
          return
      }
      
      completion?(html.matches("(?<=<td class=\"link\"><a href=\")\\d(.*?)(?=/\")"))
    }
  }
  
  // Returns the matching device model option from TSSSaver's save SHSH request form.
  class func getDeviceModelOption(from deviceType: String, and deviceIdentifier: String, completion: @escaping (Int?) -> Void) {
    Networking.get(url: TSSSaverURL.deviceModelsJSON) {
      guard let responseData = $0,
        let json = Networking.parseJSON(from: responseData) as? [String:[String]],
        let deviceModelOption = json[deviceType]?.firstIndex(of: deviceIdentifier)
        else {
          print("ERROR: cannot get device model option from JSON.")
          completion(nil)
          return
      }
      
      completion(deviceModelOption)
    }
  }
  
  // Returns an array of device model identifiers.
  class func getDeviceIdentifierList(completion: (([String]?) -> Void)?) {
    Networking.get(url: TSSSaverURL.devicesJSON) {
      guard let responseData = $0,
        let deviceIdentifierList = Networking.parseJSON(from: responseData) as? [String]
        else {
          print("ERROR: cannot get device identifier list from JSON.")
          completion?(nil)
          return
      }
      
      completion?(deviceIdentifierList)
    }
  }
  
  // Returns the data for a device thumbnail to be displayed in a UIImage.
  class func getDeviceThumbnailData(from deviceIdentifier: String, completion: ((Data?) -> Void)?) {
    Networking.get(url: IPSWURL.deviceThumbnail(for: deviceIdentifier)) {
      guard let responseData = $0 else {
        print("ERROR: cannot get device thumbnail data for '" + deviceIdentifier + "'.")
        completion?(nil)
        return
      }
      
      completion?(responseData)
    }
  }
}
