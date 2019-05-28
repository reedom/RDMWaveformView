//
//  AudioDataControllerDelegate.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

import Foundation

@objc public protocol AudioDataControllerDelegate: NSObjectProtocol {
  /// Tells when `AudioDataController` has turned empty.
  @objc optional func audioDataControllerDidReset(_ controller: AudioDataController)
  /// Tells when `AudioDataController` has loaded a new audio track.
  @objc optional func audioDataControllerDidSetAudioContext(_ controller: AudioDataController)
  /// Tells when `AudioDataController.time.currentTime` has been updated.
  @objc optional func audioDataController(_ controller: AudioDataController, didUpdateTime time: TimeInterval, seekMode: Bool)
  /// Tells when `AudioDataController` has entered in seekMode.
  @objc optional func audioDataControllerDidEnterSeekMode(_ controller: AudioDataController)
  /// Tells when `AudioDataController` has got out of seekMode.
  @objc optional func audioDataControllerDidLeaveSeekMode(_ controller: AudioDataController)
}
