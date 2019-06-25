//
//  MarkersControllerDelegate.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

import Foundation

@objc public protocol MarkersControllerDelegate: NSObjectProtocol {
  /// Tells the delegate when a new marker is added to the controller.
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func markersController(_ controller: MarkersController, didAdd marker: Marker)
  /// Tells the delegate when the user starts dragging a marker.
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func markersController(_ controller: MarkersController, willBeginDrag marker: Marker)
  /// Tells the delegate when dragging ends.
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  /// - Parameter removing: True if the marker is about to be removing.
  @objc optional func markersController(_ controller: MarkersController, didEndDrag marker: Marker, removing: Bool)
  /// Tells the delegate when the user changed the time of a marker, by dragging or tapping.
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func markersController(_ controller: MarkersController, didUpdateTime marker: Marker)
  /// Tells the delegate when the user changed `Marker.data`
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func markersController(_ controller: MarkersController, didUpdateData marker: Marker)
  /// Tells the delegate when the user removed a `Marker`
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func markersController(_ controller: MarkersController, didRemove marker: Marker)
  /// Tells the delegate when the user removed all of `Marker`
  ///
  /// - Parameter controller: The event source.
  @objc optional func markersControllerDidRemoveAllMarkers(_ controller: MarkersController)
}
