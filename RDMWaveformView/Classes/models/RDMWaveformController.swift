//
//  RDMWaveformController.swift
//  FBSnapshotTestCase
//
//  Created by HANAI Tohru on 2019/04/30.
//

import Foundation

public class RDMWaveformController: NSObject {
  public weak var delegate: RDMWaveformControllerDelegate?
  private var observers = Set<WeakDelegateRef<RDMWaveformControllerDelegate>>()

  public var audioContext: RDMAudioContext? {
    didSet {
      if audioContext != nil {
        observers.forEach({ $0.value?.waveformControllerDidLoadAudio?(self)})
        delegate?.waveformControllerDidLoadAudio?(self)
      } else {
        observers.forEach({ $0.value?.waveformControllerDidReset?(self)})
        delegate?.waveformControllerDidReset?(self)
      }
      seekModeCount = 0
      if 0 < _currentTime {
        currentTime = 0
      }
    }
  }

  public var hasAudio: Bool {
    if let audioContext = audioContext {
      return 0 < audioContext.totalSamples
    } else {
      return false
    }
  }

  // Current time on focus.
  private var _currentTime: TimeInterval = 0
  public var currentTime: TimeInterval {
    get { return _currentTime }
    set {
      _currentTime = newValue
      observers.forEach({ $0.value?.waveformController?(self, didUpdateTime: _currentTime, seekMode: seekMode)})
      delegate?.waveformController?(self, didUpdateTime: _currentTime, seekMode: seekMode)
    }
  }

  func updateTime(_ time: TimeInterval, excludeNotify: RDMWaveformControllerDelegate) {
    _currentTime = time

    observers.forEach({ (observer) in
      guard
        let val = observer.value,
        val.hash != excludeNotify.hash
        else { return }
      val.waveformController?(self, didUpdateTime: _currentTime, seekMode: seekMode)
    })

    guard
      let delegate = delegate,
      delegate.hash != excludeNotify.hash
      else { return }
    delegate.waveformController?(self, didUpdateTime: _currentTime, seekMode: seekMode)
  }

  // Index of the sampling data.
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

  private var seekModeCount: Int = 0
  public var seekMode: Bool {
    return 0 < seekModeCount
  }

  func enterSeekMode() {
    seekModeCount += 1
    if seekModeCount == 1 {
      observers.forEach({ $0.value?.waveformControllerDidEnterSeekMode?(self)})
      delegate?.waveformControllerDidEnterSeekMode?(self)
    }
  }

  func leaveSeekMode() {
    guard 0 < seekModeCount else { return }
    seekModeCount -= 1
    if seekModeCount == 0 {
      observers.forEach({ $0.value?.waveformControllerDidLeaveSeekMode?(self)})
      delegate?.waveformControllerDidLeaveSeekMode?(self)
    }
  }

  /// Load an audio asset.
  public func load(_ url: URL, callback: @escaping (_ error: RDMAudioError?) -> Void) {
    observers.forEach({ $0.value?.waveformControllerWillLoadAudio?(self)})
    delegate?.waveformControllerWillLoadAudio?(self)

    RDMAudioContext.load(fromAudioURL: url) { (result) in
      DispatchQueue.main.async {
        switch result {
        case .success(let audioContext):
          guard audioContext.audioURL == url else { return }
          self.audioContext = audioContext
          callback(nil)
        case .failure(let error):
          callback(error)
        }
      }
    }
  }

  public func clear() {
    if audioContext != nil {
      audioContext = nil
    }
  }

  public func cancel() {

  }
}

extension RDMWaveformController {
  func subscribe(_ delegate: RDMWaveformControllerDelegate) {
    observers.insert(WeakDelegateRef(value: delegate))
  }

  func unsubscribe(_ delegate: RDMWaveformControllerDelegate) {
    observers.remove(WeakDelegateRef(value: delegate))
  }
}

@objc public protocol RDMWaveformControllerDelegate: NSObjectProtocol {
  @objc optional func waveformControllerWillLoadAudio(_ controller: RDMWaveformController)
  @objc optional func waveformControllerDidLoadAudio(_ controller: RDMWaveformController)
  @objc optional func waveformController(_ controller: RDMWaveformController, didUpdateTime time: TimeInterval, seekMode: Bool)
  @objc optional func waveformControllerDidReset(_ controller: RDMWaveformController)
  @objc optional func waveformControllerDidEnterSeekMode(_ controller: RDMWaveformController)
  @objc optional func waveformControllerDidLeaveSeekMode(_ controller: RDMWaveformController)
}
