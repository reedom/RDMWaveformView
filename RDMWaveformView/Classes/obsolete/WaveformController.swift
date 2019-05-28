//
//  WaveformController.swift
//  FBSnapshotTestCase
//
//  Created by HANAI Tohru on 2019/04/30.
//

import Foundation

/// `WaveformController` holds `audioContenxt` and `currentTime`.
/// More than one views can share this instance so that those views can
/// render information of the same audio track and can sync to the time.
public class WaveformController: NSObject {
  /// The delegate of this object.
  public weak var delegate: WaveformControllerDelegate?

  /// A list of `WaveformControllerDelegate`.
  ///
  /// The observers will be notified as same as the `delegate`.
  /// The only difference is that `observers` is only available for internal classes
  /// in this package.
  private var observers = Set<WeakDelegateRef<WaveformControllerDelegate>>()

  /// Audio information.
  public var audioContext: AudioContext? {
    get { return _audioContext }
    set {
      // Skip if there is no update.
      if let oldValue = _audioContext, let newValue = newValue {
        if oldValue.audioURL == newValue.audioURL {
          return
        }
      } else if audioContext == nil && newValue == nil {
        return
      }

      _audioContext = newValue
      seekModeCount = 0
      _currentTime = 0
      if audioContext != nil {
        observers.forEach({ $0.value?.waveformControllerDidLoadAudio?(self)})
        delegate?.waveformControllerDidLoadAudio?(self)
      } else {
        observers.forEach({ $0.value?.waveformControllerDidReset?(self)})
        delegate?.waveformControllerDidReset?(self)
      }
    }
  }
  private var _audioContext: AudioContext?

  /// Determine whether `WaveformController` has loaded
  /// an audio track.
  public var hasAudio: Bool {
    if let audioContext = audioContext {
      return 0 < audioContext.totalSamples
    } else {
      return false
    }
  }

  /// Current time that `WaveformController` focus on.
  public var currentTime: TimeInterval {
    get { return _currentTime }
    set {
      guard hasAudio else { return }
      _currentTime = newValue
      observers.forEach({ $0.value?.waveformController?(self, didUpdateTime: _currentTime, seekMode: seekMode)})
      delegate?.waveformController?(self, didUpdateTime: _currentTime, seekMode: seekMode)
    }
  }
  private var _currentTime: TimeInterval = 0

  /// `WaveformController` counts every seekMode enter/leave calls
  /// to distinguish first-enter/last-leave timings.
  private var seekModeCount: Int = 0

  /// Determine whether the user is scrubbing the audio track.
  public var seekMode: Bool {
    return 0 < seekModeCount
  }

  deinit {
    debugPrint("WaveformController.deinit")
  }
}

extension WaveformController {
  /// Update `currentTime` from the internal class instances.
  ///
  /// - Parameter time: new value.
  /// - Parameter excludeNotify: `WaveformController` skips the specified delegate(observer) notify.
  func updateTime(_ time: TimeInterval, excludeNotify: WaveformControllerDelegate) {
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

  /// The user starts scrubbing the audio track.
  func enterSeekMode() {
    guard hasAudio else { return }
    seekModeCount += 1
    if seekModeCount == 1 {
      observers.forEach({ $0.value?.waveformControllerDidEnterSeekMode?(self)})
      delegate?.waveformControllerDidEnterSeekMode?(self)
    }
  }

  /// The user stops scrubbing the audio track.
  func leaveSeekMode() {
    guard hasAudio else { return }
    guard 0 < seekModeCount else { return }
    seekModeCount -= 1
    if seekModeCount == 0 {
      observers.forEach({ $0.value?.waveformControllerDidLeaveSeekMode?(self)})
      delegate?.waveformControllerDidLeaveSeekMode?(self)
    }
  }

  /// Load an audio asset.
  public func load(_ url: URL, callback: @escaping (_ error: AudioError?) -> Void) {
    observers.forEach({ $0.value?.waveformControllerWillLoadAudio?(self)})
    delegate?.waveformControllerWillLoadAudio?(self)

    AudioContext.load(fromAudioURL: url) { (result) in
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
    audioContext = nil
  }
}

extension WaveformController {
  /// Start observing WaveformController's events.
  func subscribe(_ delegate: WaveformControllerDelegate) {
    observers.insert(WeakDelegateRef(value: delegate))
  }

  /// Stop observing WaveformController's events.
  func unsubscribe(_ delegate: WaveformControllerDelegate) {
    while let index = observers.firstIndex(where: { (ref) -> Bool in
      guard let val = ref.value else { return true }
      return val.hash == delegate.hash
      }) {
      observers.remove(at: index)
    }
  }
}

@objc public protocol WaveformControllerDelegate: NSObjectProtocol {
  /// Tells when `WaveformController` is about to load a new audio track.
  @objc optional func waveformControllerWillLoadAudio(_ controller: WaveformController)
  /// Tells when `WaveformController` has loaded a new audio track.
  @objc optional func waveformControllerDidLoadAudio(_ controller: WaveformController)
  /// Tells when `WaveformController.currentTime` has been updated.
  @objc optional func waveformController(_ controller: WaveformController, didUpdateTime time: TimeInterval, seekMode: Bool)
  /// Tells when `WaveformController` has turned empty.
  @objc optional func waveformControllerDidReset(_ controller: WaveformController)
  /// Tells when `WaveformController` has entered in seekMode.
  @objc optional func waveformControllerDidEnterSeekMode(_ controller: WaveformController)
  /// Tells when `WaveformController` has got out of seekMode.
  @objc optional func waveformControllerDidLeaveSeekMode(_ controller: WaveformController)
}
