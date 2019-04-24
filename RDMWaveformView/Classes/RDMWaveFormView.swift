//
//  RDMWaveformView.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 4/14/19.
//  Copyright © 2019 reedom. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

/// A view for rendering audio waveforms
// IBDesignable support in XCode is so broken it's sad
open class RDMWaveformView: UIView {
  // MARK: - Types

  public struct WaveformRenderOptions {
    let stride: CGFloat
    let lineWidth: CGFloat
  }

  // MARK: - Properties

  /// A delegate to accept progress reporting
  open weak var delegate: RDMWaveformViewDelegate?

  /// The audio URL to render
  open var audioURL: URL? {
    didSet {
      guard let audioURL = audioURL else {
        NSLog("RDMWaveformView received nil audioURL")
        audioContext = nil
        return
      }

      // Start downloading
      _loadingInProgress = true
      delegate?.waveformViewWillLoad?(self)

      NSLog("loading audio track from \(audioURL)")
      RDMAudioContext.load(fromAudioURL: audioURL) { audioContext in
        DispatchQueue.main.async {
          guard self.audioURL == audioContext?.audioURL else { return }

          if audioContext == nil {
            NSLog("RDMWaveformView failed to load URL: \(audioURL)")
          } else {
            NSLog("loaded audio track from \(audioURL)")
            NSLog("audio track duration: \(audioContext!.asset.duration.seconds)secs")
          }

          self.audioContext = audioContext // This will reset the view and kick off a layout
          self._loadingInProgress = false
          self.delegate?.waveformViewDidLoad?(self)
        }
      }
    }
  }

  // MARK: - View properties

  public var waveformBackgroundColor = UIColor(red: 26/255, green: 25/255, blue: 31/255, alpha: 1) {
    didSet {
      contentView.backgroundColor = waveformBackgroundColor
    }
  }

  public var waveformRenderOptions = WaveformRenderOptions(stride: 1, lineWidth: 1) {
    didSet {
      contentView.resolution = resolution
    }
  }

  public var showCursor = true {
    didSet {
      cursorView.isHidden = !showCursor
      setNeedsLayout()
    }
  }

  public var cursorWidth: CGFloat = 3

  private var resolution: RDMWaveformResolution {
    return .byViewWidth(stride: waveformRenderOptions.stride,
                        lineWidth: waveformRenderOptions.lineWidth)
  }


  /// `contentView` renders a waveform.
  public lazy var contentView: RDMWaveformContentView = {
    let view = RDMWaveformContentView()
    view.resolution = resolution
    view.backgroundColor = waveformBackgroundColor
    view.contentMode = .redraw
    addSubview(view)
    return view
  }()

  public lazy var cursorView: RDMWaveformCursor = {
    let view = RDMWaveformCursor()
    addSubview(view)
    view.isHidden = !showCursor
    return view
  }()

  // MARK: - State properties

  private var _isScrubbing = false
  public var isScrubbing: Bool {
    return _isScrubbing
  }

  /// Whether loading is happening asynchronously
  private var _loadingInProgress = false
  open var loadingInProgress: Bool {
    return _loadingInProgress
  }

  /// The total number of audio samples in the current track.
  public var totalSamples: Int {
    return audioContext?.totalSamples ?? 0
  }

  /// The total duration of the current track.
  public var duration: CMTime {
    return audioContext?.asset.duration ?? CMTime.zero
  }

  /// The current time that the waveform points at.
  public var time: TimeInterval {
    get {
      guard 0 < totalSamples else { return 0 }
      let progress = _position / totalSamples
      return duration.seconds * Double(progress)
    }
    set {
      guard 0 < totalSamples else { return }
      let progress = newValue / duration.seconds
      position = Int(Double(totalSamples) * progress)
    }
  }

  /// The current position in the sampling data that the waveform points at.
  private var _position: Int = 0
  public var position: Int {
    get {
      return _position
    }
    set {
      _position = max(0, min(totalSamples, newValue))
      updateCursor()
    }
  }

  private func updateCursor() {
    guard !cursorView.isHidden, 0 < totalSamples else { return }
    let progress = CGFloat(_position) / CGFloat(totalSamples)
    cursorView.frame = CGRect(x: frame.width * progress, y: 0, width: cursorWidth, height: bounds.height)
  }

  /// The samples to be highlighted in a different color
  open var markers = [RDMMarker]() {
    didSet {
      guard audioContext != nil else { return }
      setNeedsLayout()
    }
  }

  // MARK: - Private vars

  /// Current audio context to be used for rendering
  private var audioContext: RDMAudioContext? {
    didSet {
      contentView.audioContext = audioContext
      reset()
      setNeedsLayout()
    }
  }

  // MARK: - initialization

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  private func setup() {
    contentView.isHidden = false
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    addGestureRecognizer(tapGestureRecognizer)
    let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleScrubbing))
    addGestureRecognizer(panGestureRecognizer)
  }

  @objc func handleScrubbing(_ recognizer: UIPinchGestureRecognizer) {
    guard scrubbingEnabled, 0 < totalSamples else { return }
    let progress = recognizer.location(in: self).x / bounds.width
    position = Int(CGFloat(totalSamples) * progress)
  }

  var scrubbingEnabled = true

  @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
    guard scrubbingEnabled, 0 < totalSamples else { return }
    let progress = recognizer.location(in: self).x / bounds.width
    position = Int(CGFloat(totalSamples) * progress)
    // delegate?.waveformDidEndScrubbing?(self)
  }

  override open func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow == nil {
      contentView.cancel()
    }
  }

  deinit {
    contentView.cancel()
  }

  override open func layoutSubviews() {
    super.layoutSubviews()

    if cursorView.isHidden {
      contentView.frame = bounds
    } else {
      contentView.frame = bounds.insetBy(dx: cursorWidth / 2, dy: 0)
      updateCursor()
      bringSubviewToFront(cursorView)
      cursorView.setNeedsDisplay()
    }
    contentView.visibleWidth = contentView.frame.width
    contentView.setNeedsDisplay()
  }

  // MARK: - Waveform content management

  // Downsample entire track in advance so that it won't show
  // delay in further rendering process.
  public func downsampleAll() {
    contentView.downsampler?.downsampleAll()
  }

  public func reset() {
    contentView.reset()
  }
}

/// To receive progress updates from RDMWaveformView
@objc public protocol RDMWaveformViewDelegate: NSObjectProtocol {
  /// An audio file will be loaded
  @objc optional func waveformViewWillLoad(_ waveformView: RDMWaveformView)

  /// An audio file was loaded
  @objc optional func waveformViewDidLoad(_ waveformView: RDMWaveformView)

  /// The scrubbing gesture will start
  @objc optional func waveformWillStartScrubbing(_ waveformView: RDMWaveformView)

  /// The scrubbing gesture did end
  @objc optional func waveformDidEndScrubbing(_ waveformView: RDMWaveformView)

  /// Scroll position was changed
  @objc optional func waveformDidScroll(_ waveformView: RDMWaveformView)
}

public class RDMWaveformCursor: UIView {
  public static let defaultCursorColor = UIColor(red: 52/255, green: 120/255, blue: 245/255, alpha: 1)

  open var cursorColor = defaultCursorColor

  override open func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else {
      NSLog("RDMCenterGuide failed to get graphics context")
      return
    }

    context.setFillColor(cursorColor.cgColor)
    context.setStrokeColor(cursorColor.cgColor)

    context.fillEllipse(in: CGRect(x: 0, y: 0, width: frame.width, height: 4))
    context.fillEllipse(in: CGRect(x: 0, y: frame.height - 4, width: rect.width, height: 4))
    context.fill(CGRect(x: 0, y: 2, width: frame.width, height: frame.height - 4))
  }
}
