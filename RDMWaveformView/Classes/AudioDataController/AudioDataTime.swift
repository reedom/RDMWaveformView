//
//  AudioDataTime.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

import Foundation

public class AudioDataTime {
  private let controller: AudioDataController

  /// Audio information.
  var audioContext: AudioContext? {
    return controller.audioContext
  }

  private var updatingTime = false

  /// Current time that `RDMWaveformController` focus on.
  public var currentTime: TimeInterval {
    get { return _currentTime }
    set {
      guard controller.hasAudio else { return }
      _currentTime = newValue
      guard !updatingTime else { return }
      updatingTime = true
      defer { updatingTime = false }
      controller.observers.forEach({ $0.value?.audioDataController?(controller, didUpdateTime: _currentTime, seekMode: seeking)})
      controller.delegate?.audioDataController?(controller, didUpdateTime: _currentTime, seekMode: seeking)
    }
  }
  private var _currentTime: TimeInterval = 0

  /// Couting every seekMode enter/leave calls to distinguish first-enter/last-leave calls.
  private var seekModeCount: Int = 0

  /// Determine whether the user is scrubbing the audio track.
  public var seeking: Bool {
    return 0 < seekModeCount
  }

  init(_ controller: AudioDataController) {
    self.controller = controller
  }
}

extension AudioDataTime {
  /// Update `currentTime` from the internal class instances.
  ///
  /// - Parameter time: new value.
  /// - Parameter excludeNotify: `RDMWaveformController` skips the specified delegate(observer) notify.
  func update(_ time: TimeInterval, excludeNotify: AudioDataControllerDelegate) {
    _currentTime = time
    guard !updatingTime else { return }
    updatingTime = true
    defer { updatingTime = false }

    controller.observers.forEach({ (observer) in
      guard
        let val = observer.value,
        val.hash != excludeNotify.hash
        else { return }
      val.audioDataController?(controller, didUpdateTime: _currentTime, seekMode: seeking)
    })

    guard
      let delegate = controller.delegate,
      delegate.hash != excludeNotify.hash
      else { return }
    delegate.audioDataController?(controller, didUpdateTime: _currentTime, seekMode: seeking)
  }

  /// Index of the sampling data.
  public var position: Int {
    get {
      guard
        let totalSamples = audioContext?.totalSamples,
        let seconds = audioContext?.asset.duration.seconds
        else { return 0 }
      let progress = _currentTime / seconds
      return Int(Double(totalSamples) * progress)
    }
    set {
      guard
        let totalSamples = audioContext?.totalSamples,
        let seconds = audioContext?.asset.duration.seconds
        else { return }
      let progress = Double(seconds) / Double(totalSamples)
      return _currentTime = seconds * progress
    }
  }

  public func seek(to time: TimeInterval) {
    enterSeekMode()
    currentTime = time
    leaveSeekMode()
  }

  /// The user starts scrubbing the audio track.
  func enterSeekMode() {
    guard controller.hasAudio else { return }
    seekModeCount += 1
    if seekModeCount == 1 {
      controller.observers.forEach({ $0.value?.audioDataControllerDidEnterSeekMode?(controller)})
      controller.delegate?.audioDataControllerDidEnterSeekMode?(controller)
    }
  }

  /// The user stops scrubbing the audio track.
  func leaveSeekMode() {
    guard controller.hasAudio else { return }
    guard 0 < seekModeCount else { return }
    seekModeCount -= 1
    if seekModeCount == 0 {
      controller.observers.forEach({ $0.value?.audioDataControllerDidLeaveSeekMode?(controller)})
      controller.delegate?.audioDataControllerDidLeaveSeekMode?(controller)
    }
  }

  func reset() {
    _currentTime = 0
    seekModeCount = 0
  }
}
