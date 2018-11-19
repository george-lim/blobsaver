//
//  DeviceGridLayout.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-04.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit

class DeviceGridLayout: UICollectionViewFlowLayout {
  
  private let cellsPerRow = 2
  
  // Creates a 2-column UICollectionViewFlowLayout, until itemSize exceeds 320px width.
  override func prepare() {
    super.prepare()
    
    guard let collectionView = collectionView else { return }
    
    let marginsAndInsets: CGFloat = {
      let value = self.sectionInset.left + self.sectionInset.right + self.minimumInteritemSpacing * CGFloat(self.cellsPerRow - 1)
      guard #available(iOS 11.0, *) else { return value }
      return value + collectionView.safeAreaInsets.left + collectionView.safeAreaInsets.right
    }()
    
    let itemWidth = min(320, ((collectionView.bounds.size.width - marginsAndInsets) / CGFloat(cellsPerRow)).rounded(.down))
    itemSize = CGSize(width: itemWidth, height: itemWidth * 4 / 3)
  }
  
  override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
    let context = super.invalidationContext(forBoundsChange: newBounds) as! UICollectionViewFlowLayoutInvalidationContext
    context.invalidateFlowLayoutDelegateMetrics = newBounds.size != collectionView?.bounds.size
    return context
  }
  
  // Makes deviceCells that are being repositioned bigger and less opaque to mimic Apple homescreen reposition design.
  override func layoutAttributesForInteractivelyMovingItem(at indexPath: IndexPath, withTargetPosition position: CGPoint) -> UICollectionViewLayoutAttributes {
    let attributes = super.layoutAttributesForInteractivelyMovingItem(at: indexPath, withTargetPosition: position)
    attributes.alpha = 0.7
    attributes.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
    return attributes
  }
}
