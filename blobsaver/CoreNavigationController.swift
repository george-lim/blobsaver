//
//  CoreNavigationController.swift
//  blobsaver
//
//  Created by George Lim on 2018-11-03.
//  Copyright © 2018 George Lim. All rights reserved.
//

import UIKit

class CoreNavigationController: UINavigationController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupNavigationBar()
  }
  
  private func setupNavigationBar() {
    navigationBar.setBackgroundImage(UIImage(), for: .default)
    navigationBar.shadowImage = UIImage()
    navigationBar.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 17)]
  }
}
