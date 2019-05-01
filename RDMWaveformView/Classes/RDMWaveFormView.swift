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

  open var controller: RDMWaveformController? {
    willSet {
      controller?.unsubscribe(self)
    }
    didSet {
      controller?.subscribe(self)
      refreshWaveform()
    }
  }

  open var timeSeekEnabled = true

  public var markersController: RDMWaveformMarkersController? {
    get { return markersContainer.markersController }
    set { markersContainer.markersController = newValue }
  }

  // MARK: - Appearance properties

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

  // MARK: - Subviews

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

  public lazy var markersContainer: RDMWaveformMarkersContainer = {
    let view = RDMWaveformMarkersContainer()
    addSubview(view)
    view.backgroundColor = UIColor.transparent
    return view
  }()

  // MARK: - State properties

  /// Current audio context to be used for rendering
  private var audioContext: RDMAudioContext? {
    return controller?.audioContext
  }

  open private(set) var inTimeSeekMode = false

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
    let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    addGestureRecognizer(panGestureRecognizer)
  }

  deinit {
    controller?.cancel()
    controller?.unsubscribe(self)
    contentView.cancel()
  }

  // MARK: - view lifecycle

  override open func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow == nil {
      contentView.cancel()
    }
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
}

// MARK: - Cursor

extension RDMWaveformView {
  @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
    guard
      timeSeekEnabled,
      let controller = controller,
      let duration = controller.audioContext?.asset.duration
      else { return }
    let progress = recognizer.location(in: self).x / bounds.width
    let time = Double(progress) * duration.seconds
    controller.updateTime(time, excludeNotify: self)
  }

  @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
    guard
      timeSeekEnabled,
      let controller = controller,
      let duration = controller.audioContext?.asset.duration
      else { return }

    switch recognizer.state {
    case .began:
      controller.enterSeekMode()
    case .ended, .cancelled:
      controller.leaveSeekMode()
    case .changed:
      let progress = recognizer.location(in: self).x / bounds.width
      let time = Double(progress) * duration.seconds
      controller.updateTime(time, excludeNotify: self)
    default:
      return
    }
  }

  private func updateCursor() {
    guard
      !cursorView.isHidden,
      let duration = controller?.audioContext?.asset.duration,
      let time = controller?.currentTime
      else { return }
    let progress = time / duration.seconds
    cursorView.frame = CGRect(x: frame.width * CGFloat(progress),
                              y: 0,
                              width: cursorWidth,
                              height: bounds.height)
  }
}

// MARK: - RDMWaveformControllerDelegate

extension RDMWaveformView: RDMWaveformControllerDelegate {
  public func waveformControllerWillLoadAudio(_ controller: RDMWaveformController) {

  }

  public func waveformControllerDidLoadAudio(_ controller: RDMWaveformController) {
    refreshWaveform()
  }

  public func waveformController(_ controller: RDMWaveformController, didUpdateTime time: TimeInterval, seekMode: Bool) {
    updateCursor()
  }

  public func waveformControllerDidReset(_ controller: RDMWaveformController) {

  }
}

// MARK: - Waveform content management

extension RDMWaveformView {
  // Downsample entire track in advance so that it won't show
  // delay in further rendering process.
  public func downsampleAll() {
    contentView.downsampler?.downsampleAll()
  }

  private func refreshWaveform() {
    contentView.audioContext = audioContext
    // contentView.reset()
    markersContainer.duration = audioContext?.asset.duration.seconds ?? 0
    setNeedsLayout()
  }
}
