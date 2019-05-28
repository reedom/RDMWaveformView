//
//  MarkerViewDelegate.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

import UIKit

@objc public protocol MarkerViewDelegate: NSObjectProtocol {
  @objc optional func markerView(_ markerView: MarkerView, didTap uuid: String)
  @objc optional func markerView(_ markerView: MarkerView, willBeginDrag uuid: String, point: CGPoint)
  @objc optional func markerView(_ markerView: MarkerView, didDrag uuid: String, point: CGPoint)
  @objc optional func markerView(_ markerView: MarkerView, didEndDrag uuid: String, point: CGPoint)
}
