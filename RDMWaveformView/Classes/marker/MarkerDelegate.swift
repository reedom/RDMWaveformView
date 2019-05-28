//
//  MarkerDelegate.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

protocol MarkerDelegate: class {
  /// Tells when the user update `Marker.time`.
  func markerDidUpdateTime(_ marker: Marker)
  /// Tells when the user update `Marker.data`.
  func markerDidUpdateData(_ marker: Marker)
}
