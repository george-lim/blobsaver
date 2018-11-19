//
//  DeviceInfoEditController.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-05.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit

private let ecidHelpURL = "https://www.iclarified.com/66005/how-to-find-your-iphone-ecid-using-itunes"
private let modelIdentifierHelpURL = "https://www.imore.com/how-find-your-iphones-serial-number-udid-or-other-information"

protocol DeviceInfoEditDelegate {
  func didSave(deviceInfo: DeviceInfo)
  func didDeleteDevice()
}

class DeviceInfoEditController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
  
  static let storyboardID = "DeviceInfoEditController"
  
  private var delegate: DeviceInfoEditDelegate?
  private var deviceInfo: DeviceInfo!
  private var deviceIdentifierList: [String]?
  private var isDeleteEnabled = false
  
  @IBOutlet private weak var containerView: UIView!
  @IBOutlet private weak var deviceNameField: UITextField!
  @IBOutlet private weak var deviceECIDField: UITextField!
  @IBOutlet private weak var deviceECIDType: UISegmentedControl!
  @IBOutlet private weak var deviceIdentifierPicker: UIPickerView!
  @IBOutlet private weak var deviceBoardConfigField: UITextField!
  @IBOutlet private weak var deleteButton: UIButton!
  
  func configure(delegate: DeviceInfoEditDelegate, deviceInfo: DeviceInfo, isDeleteEnabled: Bool) {
    self.delegate = delegate
    self.deviceInfo = deviceInfo
    self.isDeleteEnabled = isDeleteEnabled
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupSubviews()
    setupDismissKeyboardGesture()
    loadData()
  }
  
  private func setupSubviews() {
    deviceNameField.delegate = self
    deviceECIDField.delegate = self
    deviceBoardConfigField.delegate = self
    deviceIdentifierPicker.dataSource = self
    deviceIdentifierPicker.delegate = self
  }
  
  @objc private func dismissKeyboard() {
    view.endEditing(true)
  }
  
  private func setupDismissKeyboardGesture() {
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    tapGesture.cancelsTouchesInView = false
    view.addGestureRecognizer(tapGesture)
  }
  
  private func updateDeviceBoardField(with deviceIdentifier: String, clearText: Bool = false) {
    deviceBoardConfigField.isEnabled = DeviceInfo.requiresBoardConfig(for: deviceIdentifier)
    deviceBoardConfigField.text = clearText || deviceInfo.boardConfig == DeviceInfo.default.boardConfig ? "" : deviceInfo.boardConfig
    
    deviceBoardConfigField.placeholder = {
      if !deviceBoardConfigField.isEnabled {
        return "N/A"
      } else if deviceIdentifier == deviceInfo.identifier && deviceInfo.boardConfig.count > 0 {
        return deviceInfo.boardConfig
      } else if deviceIdentifier == DeviceInfo.default.identifier {
        return DeviceInfo.default.boardConfig
      }
      
      return "Missing info"
    }()
  }
  
  private func loadData() {
    deviceNameField.text = deviceInfo.name == DeviceInfo.default.name ? "" : deviceInfo.name
    deviceNameField.placeholder = deviceInfo.name
    
    deviceECIDField.text = deviceInfo.ecid
    
    if deviceInfo.ecid.count > 0 {
      deviceECIDField.placeholder = deviceInfo.ecid
      deviceECIDField.keyboardType = .numberPad
      deviceECIDType.selectedSegmentIndex = 1
    } else {
      deviceECIDField.placeholder = "Missing info"
      deviceECIDField.keyboardType = .namePhonePad
      deviceECIDType.selectedSegmentIndex = 0
    }
    
    updateDeviceBoardField(with: deviceInfo.identifier)
    
    deleteButton.isHidden = !isDeleteEnabled
    
    API.getDeviceIdentifierList {
      self.deviceIdentifierList = $0
      
      DispatchQueue.main.async {
        self.deviceIdentifierPicker.reloadAllComponents()
        
        let deviceIdentifierRow = self.deviceIdentifierList?.firstIndex(of: self.deviceInfo.identifier) ?? 0
        self.deviceIdentifierPicker.selectRow(deviceIdentifierRow, inComponent: 0, animated: false)
      }
    }
  }
  
  @IBAction private func launchHelpURLForECID() {
    Networking.launch(url: ecidHelpURL)
  }
  
  @IBAction private func launchHelpURLForModelIdentifier() {
    Networking.launch(url: modelIdentifierHelpURL)
  }
  
  @IBAction private func changeDeviceECIDFieldKeyboard() {
    deviceECIDField.keyboardType = deviceECIDType.selectedSegmentIndex == 0 ? .namePhonePad : .numberPad
  }
  
  @IBAction private func displayBoardConfigPopup() {
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
    let alertMessage = """
    Some devices like the iPhone 6S, iPhone 6S+, iPhone SE, and iPad 5 have multiple internal CPU board configurations.\n
    \(appName) will auto-detect and complete the "Board Configuration" field for the current device if applicable.
    """
    
    let alertController = UIAlertController(title: "Board Configuration", message: alertMessage, preferredStyle: .alert)
    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
    alertController.addAction(okAction)
    
    present(alertController, animated: true, completion: nil)
  }
  
  @IBAction private func deleteDevice() {
    delegate?.didDeleteDevice()
    dismiss(animated: true)
  }
  
  @IBAction private func save() {
    let deviceName = deviceNameField.text!.count > 0 ? deviceNameField.text! : deviceInfo.name
    
    let deviceECID: String = {
      let ecid = deviceECIDField.text!.count > 0 ? deviceECIDField.text! : deviceInfo.ecid
      
      guard deviceECIDType.selectedSegmentIndex == 0,
        let hexToBin = UInt64(ecid, radix: 16)
        else { return ecid }
      
      return String(describing: hexToBin)
    }()
  
    let deviceIdentifier = deviceIdentifierList?[deviceIdentifierPicker.selectedRow(inComponent: 0)] ?? deviceInfo.identifier
    
    let deviceBoardConfig: String = {
      if !DeviceInfo.requiresBoardConfig(for: deviceIdentifier) {
        return ""
      } else if deviceBoardConfigField.text!.count > 0 {
        return deviceBoardConfigField.text!
      } else if deviceIdentifier == deviceInfo.identifier && deviceInfo.boardConfig.count > 0 {
        return deviceInfo.boardConfig
      } else if deviceIdentifier == DeviceInfo.default.identifier {
        return DeviceInfo.default.boardConfig
      }

      return ""
    }()
    
    delegate?.didSave(deviceInfo: DeviceInfo(name: deviceName,
                                             ecid: deviceECID,
                                             identifier: deviceIdentifier,
                                             boardConfig: deviceBoardConfig))
    
    dismiss(animated: true)
  }
  
  // MARK: - UITextFieldDelegate
  
  func textFieldDidBeginEditing(_ textField: UITextField) {
    let textFieldHeightRatio = textField.convert(textField.frame.origin, to: view).y / view.frame.height
    guard textFieldHeightRatio > 0.5 else { return }
    
    UIView.animate(withDuration: 0.25) {
      self.containerView.center.y -= (textFieldHeightRatio - 0.5) * self.view.frame.height
    }
  }
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if textField == deviceNameField {
      textField.resignFirstResponder()
      deviceECIDField.becomeFirstResponder()
    } else if textField == deviceECIDField {
      deviceECIDField.resignFirstResponder()
      deviceIdentifierPicker.becomeFirstResponder()
    } else {
      deviceBoardConfigField.resignFirstResponder()
    }
    
    return true
  }
  
  func textFieldDidEndEditing(_ textField: UITextField) {
    guard containerView.center.y != view.frame.height / 2 else { return }
    
    UIView.animate(withDuration: 0.25) {
      self.containerView.center.y = self.view.frame.height / 2
    }
  }
  
  // MARK: - UIPickerViewDataSource
  
  func numberOfComponents(in pickerView: UIPickerView) -> Int {
    return 1
  }
  
  func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    return deviceIdentifierList?.count ?? 0
  }
  
  // MARK: - UIPickerViewDelegate
  
  func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
    guard let deviceIdentifier = deviceIdentifierList?[row] else { return nil }
    return NSAttributedString(string: deviceIdentifier, attributes: [.foregroundColor: Colors.blue])
  }
  
  func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    guard pickerView == deviceIdentifierPicker else { return }
    dismissKeyboard()
    
    guard let deviceIdentifier = deviceIdentifierList?[deviceIdentifierPicker.selectedRow(inComponent: 0)] else { return }
    updateDeviceBoardField(with: deviceIdentifier, clearText: true)
  }
}
