
open class AudioDataController: NSObject {
  public weak var delegate: AudioDataControllerDelegate?

  /// A list of `RDMWaveformControllerDelegate`.
  ///
  /// The observers will be notified as same as the `delegate`.
  /// The only difference is that `observers` is only available for internal classes
  /// in this package.
  var observers = Set<WeakDelegateRef<AudioDataControllerDelegate>>()

  /// Audio information.
  public var audioContext: AudioContext? {
    didSet {
      // Skip if there is no update.
      if audioContext != nil {
        observers.forEach({ $0.value?.audioDataControllerDidSetAudioContext?(self)})
        delegate?.audioDataControllerDidSetAudioContext?(self)
        downsampler.startLoading()
      } else {
        observers.forEach({ $0.value?.audioDataControllerDidReset?(self)})
        delegate?.audioDataControllerDidReset?(self)
      }
    }
  }

  /// Determine whether `RDMWaveformController` has loaded
  /// an audio track.
  public var hasAudio: Bool {
    if let audioContext = audioContext {
      return 0 < audioContext.totalSamples
    } else {
      return false
    }
  }

  lazy var _time: AudioDataTime = {
    return AudioDataTime(self)
  }()

  public var time: AudioDataTime {
    return _time
  }

  lazy var _downsampler: Downsampler = {
    return Downsampler(self)
  }()

  public var downsampler: Downsampler {
    return _downsampler
  }
}

extension AudioDataController {
  /// Start observing AudioDataController's events.
  func subscribe(_ delegate: AudioDataControllerDelegate) {
    observers.insert(WeakDelegateRef(value: delegate))
  }

  /// Stop observing AudioDataController's events.
  func unsubscribe(_ delegate: AudioDataControllerDelegate) {
    while let index = observers.firstIndex(where: { (ref) -> Bool in
      guard let val = ref.value else { return true }
      return val.hash == delegate.hash
    }) {
      observers.remove(at: index)
    }
  }
}
