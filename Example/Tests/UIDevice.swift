//
//  UIDevice.swift
//  RDMWaveformView_Tests
//
//  Created by HANAI Tohru on 2019/05/10.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import UIKit

extension UIDevice {
  static var isSimulator: Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }
}
