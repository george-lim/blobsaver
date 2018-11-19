//
//  DeviceGridController.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-04.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit

protocol DeviceGridDelegate {
  func updateDeviceInfoList(with deviceInfoList: [DeviceInfo])
}

class DeviceGridController: UIViewController, Synchronizable, UICollectionViewDataSource, UICollectionViewDelegate, DeviceInfoEditDelegate {
  
  static let storyboardID = "DeviceGridController"
  
  private var delegate: DeviceGridDelegate?
  private var deviceInfoList: [DeviceInfo]!
  private var movingCell: DeviceCell? // The cell that is currently being repositioned.
  private var movingCellCenterOffset: CGPoint? // Starting position offset from the center.
  private var isMovingCell = false
  private var selectedItemIndexPath: IndexPath? // The IndexPath of the last selected item.
  
  @IBOutlet private weak var collectionView: UICollectionView!
  
  func configure(delegate: DeviceGridDelegate, deviceInfoList: [DeviceInfo]) {
    self.delegate = delegate
    self.deviceInfoList = deviceInfoList
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupNavigationItem()
    setupLongPressGesture()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    guard self.isMovingFromParent else { return }
    delegate?.updateDeviceInfoList(with: deviceInfoList)
  }
  
  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)
    updateRightButtonBarItem()
    animateWigglingCells()
  }
  
  @objc private func addDevice() {
    deviceInfoList.append(DeviceInfo.default)
    
    let lastIndexPath = IndexPath(item: deviceInfoList.count - 1, section: 0)
    collectionView.insertItems(at: [lastIndexPath])
    collectionView(collectionView, didSelectItemAt: lastIndexPath)
  }
  
  private func updateRightButtonBarItem() {
    let addDeviceItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addDevice))
    navigationItem.rightBarButtonItem = isEditing ? editButtonItem : addDeviceItem
  }
  
  private func setupNavigationItem() {
    title = "My Devices"
    updateRightButtonBarItem()
  }
  
  private func animateMovingCell(to location: CGPoint) {
    movingCell?.stopWiggling()
    
    if let center = movingCell?.center {
      movingCellCenterOffset = CGPoint(x: center.x - location.x, y: center.y - location.y)
    }
    
    UIView.animate(withDuration: 0.15) {
      self.movingCell?.alpha = 0.7
      self.movingCell?.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
      self.movingCell?.center = location
    }
  }
  
  private func animateMovingCell(from location: CGPoint) {
    self.movingCell?.startWiggling()
    
    UIView.animate(withDuration: 0.15) {
      self.movingCell?.alpha = 1
      self.movingCell?.transform = .identity
      self.movingCell?.center.x += self.movingCellCenterOffset?.x ?? 0
      self.movingCell?.center.y += self.movingCellCenterOffset?.y ?? 0
    }
  }
  
  @objc private func longPressed(gesture: UILongPressGestureRecognizer) {
    switch gesture.state {
    case .began:
      let startLocation = gesture.location(in: collectionView)
      guard let movingCellIndexPath = collectionView.indexPathForItem(at: startLocation) else { break }
      
      movingCell = collectionView.cellForItem(at: movingCellIndexPath) as? DeviceCell
      isMovingCell = true
      
      HapticFeedback.pop()
      setEditing(true, animated: true)
      animateMovingCell(to: startLocation)
      
      collectionView.beginInteractiveMovementForItem(at: movingCellIndexPath)
    case .changed:
      collectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view))
    case .ended:
      let endLocation = gesture.location(in: collectionView)
      isMovingCell = false
      
      collectionView.performBatchUpdates({
        animateMovingCell(from: endLocation)
        collectionView.endInteractiveMovement()
      }) { _ in
        self.movingCellCenterOffset = nil
        self.movingCell = nil
      }
    default:
      isMovingCell = false
      collectionView.cancelInteractiveMovement()
    }
  }
  
  private func setupLongPressGesture() {
    let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
    longPressGesture.minimumPressDuration = 0.3
    collectionView.addGestureRecognizer(longPressGesture)
  }
  
  private func animateWigglingCells() {
    guard let visibleCells = collectionView.visibleCells as? [DeviceCell] else { return }
    
    visibleCells.forEach {
      isEditing
        ? $0.startWiggling()
        : $0.stopWiggling()
    }
  }
  
  // MARK: - Synchronizable
  
  func syncCloudChanges() {
    presentedViewController?.dismiss(animated: true)
    deviceInfoList = Persistence.getDeviceInfoList()
    collectionView.reloadData()
  }
  
  // MARK: - UICollectionViewDataSource
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return deviceInfoList.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if let selectedCell = movingCell,
      !isMovingCell {
      return selectedCell
    }
    
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DeviceCell.identifier, for: indexPath) as! DeviceCell
    cell.configure(deviceInfo: deviceInfoList[indexPath.item])
    
    isEditing
      ? cell.startWiggling()
      : cell.stopWiggling()
    
    return cell
  }
  
  func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    deviceInfoList.insert(deviceInfoList.remove(at: sourceIndexPath.item), at: destinationIndexPath.item)
    Persistence.updateDeviceInfoList(with: deviceInfoList)
  }
  
  // MARK: - UICollectionViewDelegate
  
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let deviceInfoEditController = storyboard?.instantiateViewController(withIdentifier: DeviceInfoEditController.storyboardID) as? DeviceInfoEditController else { return }
    
    setEditing(false, animated: true)
    selectedItemIndexPath = indexPath
    
    deviceInfoEditController.modalPresentationStyle = .overCurrentContext
    deviceInfoEditController.configure(delegate: self,
                                       deviceInfo: deviceInfoList[indexPath.item],
                                       isDeleteEnabled: deviceInfoList.count > 1)
    
    present(deviceInfoEditController, animated: true)
  }
  
  // MARK: - DeviceInfoEditDelegate
  
  func didDeleteDevice() {
    guard let selectedItemIndexPath = selectedItemIndexPath else { return }
    deviceInfoList.remove(at: selectedItemIndexPath.item)
    self.selectedItemIndexPath = nil
    collectionView.deleteItems(at: [selectedItemIndexPath])
    Persistence.updateDeviceInfoList(with: deviceInfoList)
  }
  
  func didSave(deviceInfo: DeviceInfo) {
    guard let selectedItemIndexPath = selectedItemIndexPath else { return }
    deviceInfoList[selectedItemIndexPath.item] = deviceInfo
    self.selectedItemIndexPath = nil
    collectionView.reloadItems(at: [selectedItemIndexPath])
    Persistence.updateDeviceInfoList(with: deviceInfoList)
  }
}
