//
//  VersionTimelineController.swift
//  blobsaver
//
//  Created by George Lim on 2018-10-26.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit
import XLPagerTabStrip

private let textCellID = "TextCell"

protocol VersionTimelineDelegate {
  func disableDeviceSetup()
}

class VersionTimelineController: UITableViewController, IndicatorInfoProvider, TSSSaverCellDelegate {
  
  static let storyboardID = "VersionTimelineController"
  
  private var delegate: VersionTimelineDelegate?
  private var deviceInfo: DeviceInfo!
  private var firmwareList: [[[String:Any]]]? // A list of every firmware available to the device, to date.
  private var blobList: [String]? // A list of firmware versions for which the device has SHSH blobs for.
  private var deviceModelOption: Int?
  
  private var isDeviceSetUp = true
  private var isConnectedToInternet = true
  private var isBlobSavingSectionActive = false
  
  private var isToDoSectionActive: Bool {
    return !isDeviceSetUp || !isConnectedToInternet
  }
  
  private var toDoSectionRows: Int {
    var rows = 0
    if !isDeviceSetUp || !isConnectedToInternet { rows += 1 }
    return rows
  }
  
  private var sectionOffset: Int {
    var offset = 0
    if isToDoSectionActive { offset += 1 }
    if isBlobSavingSectionActive { offset += 1 }
    return offset
  }
  
  func configure(delegate: VersionTimelineDelegate, deviceInfo: DeviceInfo) {
    self.delegate = delegate
    self.deviceInfo = deviceInfo
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    loadData()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    fixContentInsets()
  }
  
  // Sets isBlobSavingSectionActive to true if there is a currently signed firmware in firmwareList that is not found in blobList.
  #if DEBUG
  private func checkBlobSavingRequired() {
    isBlobSavingSectionActive = true
  }
  #else
  private func checkBlobSavingRequired() {
    guard !Persistence.isLastSubmissionTicketActive(for: deviceInfo.ecid) else { return }
    
    let signedFirmwareList = firmwareList?
      .reduce([]) { $0 + $1 }
      .filter{ $0["signed"] as? Bool == true }
      .map{ $0["version"] } as? [String] ?? []
    
    signedFirmwareList.forEach {
      if blobList?.contains($0) == false {
        isBlobSavingSectionActive = true
        return
      }
    }
  }
  #endif
  
  private func didReceiveData() {
    guard !isConnectedToInternet || (firmwareList != nil && (!isDeviceSetUp || (blobList != nil && deviceModelOption != nil))) else { return }
    
    if !isConnectedToInternet {
      delegate?.disableDeviceSetup()
    }
    
    if blobList != nil && deviceModelOption != nil {
      checkBlobSavingRequired()
    }
    
    DispatchQueue.main.async {
      self.tableView.reloadData()
    }
  }
  
  private func loadData() {
    isDeviceSetUp = deviceInfo.isComplete
    
    API.getFirmwareList(from: deviceInfo.identifier) {
      if $0 == nil {
        self.isConnectedToInternet = false
      }
      
      self.firmwareList = $0
      self.didReceiveData()
    }
    
    guard isDeviceSetUp else { return }
    
    API.getBlobList(from: deviceInfo.ecid) {
      if $0 == nil {
        self.isConnectedToInternet = false
      }
      
      self.blobList = $0
      self.didReceiveData()
    }
    
    API.getDeviceModelOption(from: deviceInfo.type, and: deviceInfo.identifier) {
      if $0 == nil {
        self.isConnectedToInternet = false
      }
      
      self.deviceModelOption = $0
      self.didReceiveData()
    }
  }
  
  private func fixContentInsets() {
    // iOS 10 has different contentInsetAdjustmentBehavior and safe area behavior.
    // NOTE: safeAreaInsets of UIViews are set incorrectly during UINavigationController transitions on iOS 11. Apple
    //   has addressed the issue on iOS 11.2. Details: http://openradar.appspot.com/34465226
    guard #available(iOS 11.0, *) else {
      tableView.contentInset.top = navigationController?.navigationBar.frame.maxY ?? 0
      return
    }
  }
  
  private func getFirmware(at indexPath: IndexPath) -> [String:Any] {
    return firmwareList?[indexPath.section - sectionOffset][indexPath.item] ?? [:]
  }
  
  // MARK: - IndicatorInfoProvider
  
  func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
    return IndicatorInfo(title: deviceInfo.name)
  }
  
  // MARK: - UITableViewDataSource
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return firmwareList?.count ?? 0 + sectionOffset
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    var sectionOffset = 0
    
    if isToDoSectionActive {
      if section == sectionOffset { return toDoSectionRows }
      sectionOffset += 1
    }
    
    if isBlobSavingSectionActive {
      if section == sectionOffset { return 1 }
      sectionOffset += 1
    }
    
    return firmwareList?[section - sectionOffset].count ?? 0
  }
  
  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    var sectionOffset = 0
    
    if isToDoSectionActive {
      if section == sectionOffset { return "To-Do" }
      sectionOffset += 1
    }
    
    if isBlobSavingSectionActive {
      if section == sectionOffset { return "Save Available Blobs" }
      sectionOffset += 1
    }
    
    guard let firstVersionInSection = firmwareList?[section - sectionOffset].first?["version"] as? String,
      let majorVersion = firstVersionInSection.components(separatedBy: ".").first
      else { return nil }
    
    return (deviceInfo.type == "AppleTV" ? "tvOS " : "iOS ") + majorVersion
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var sectionOffset = 0
    
    if isToDoSectionActive {
      if indexPath.section == sectionOffset {
        let cell = tableView.dequeueReusableCell(withIdentifier: textCellID, for: indexPath)
        cell.textLabel?.textColor = Colors.silver
        var itemOffset = 0
        
        if !isConnectedToInternet {
          if indexPath.item == itemOffset {
            cell.textLabel?.text = " •  Connect to the internet (reload)"
          }
          
          itemOffset += 1
        } else if !isDeviceSetUp {
          if indexPath.item == itemOffset {
            cell.textLabel?.text = " •  Shake to setup device"
          }
          
          itemOffset += 1
        }
        
        return cell
      }
      
      sectionOffset += 1
    }
    
    if isBlobSavingSectionActive {
      if indexPath.section == sectionOffset,
        let deviceModelOption = deviceModelOption {
        let cell = tableView.dequeueReusableCell(withIdentifier: TSSSaverCell.identifier, for: indexPath) as! TSSSaverCell
        cell.configure(delegate: self, deviceInfo: deviceInfo, deviceModelOption: deviceModelOption)
        return cell
      }
      
      sectionOffset += 1
    }
    
    let cell = tableView.dequeueReusableCell(withIdentifier: textCellID, for: indexPath)
    let firmware = getFirmware(at: indexPath)
    cell.textLabel?.textColor = firmware["signed"] as? Bool == true ? Colors.orange : Colors.red
    
    if let version = firmware["version"] as? String,
      let buildID = firmware["buildid"] as? String {
      cell.textLabel?.text = version + " (" + buildID + ")"
      
      if blobList?.contains(version) == true {
        cell.textLabel?.textColor = Colors.green
      }
    }
    
    return cell
  }
  
  // MARK: - TSSSaverCellDelegate
  
  func handleRequestSubmit() {
    Persistence.updateLastSubmissionTicket(for: deviceInfo.ecid)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
      self.isBlobSavingSectionActive = false
      self.tableView.reloadData()
    }
  }
}
