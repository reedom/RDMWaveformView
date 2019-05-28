//
//  WaveformView.swift
//  WaveformView
//
//  Created by HANAI Tohru on 4/14/19.
//  Copyright © 2019 reedom. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

/// A view for rendering audio waveforms
open class WaveformView: UIView {

  // MARK: - Properties

  /// `AudioDataController` holds `audioContenxt` and `currentTime`.
  open var controller: AudioDataController? {
    willSet {
      controller?.unsubscribe(self)
    }
    didSet {
      controller?.subscribe(self)
      refreshWaveform()
    }
  }

  /// `MarkersController` manages markers.
  public var markersController: MarkersController? {
    get { return markersContainer.markersController }
    set { markersContainer.markersController = newValue }
  }

  /// Downsampler.
  public var downsampler: Downsampler? {
    get { return controller?.downsampler }
  }

  /// Specifies whether the user can change the "currentTime" by tapping or scrubbing.
  open var timeSeekEnabled = true

  // MARK: - Appearance properties

  /// The color of the waveform's lines
  public var waveformLineColor: UIColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)

  /// The background color of the waveform area.
  public var waveformBackgroundColor = UIColor(red: 26/255, green: 25/255, blue: 31/255, alpha: 1) {
    didSet {
      contentView.backgroundColor = waveformBackgroundColor
    }
  }

  public struct WaveformRenderOptions {
    let stride: CGFloat
    let lineWidth: CGFloat
  }

  public var waveformRenderOptions = WaveformRenderOptions(stride: 1, lineWidth: 1)

  private var resolution: WaveformResolution {
    return .byViewWidth(stride: waveformRenderOptions.stride,
                        lineWidth: waveformRenderOptions.lineWidth)
  }

  /// Indicates whether to show the cursor.
  public var showCursor = true {
    didSet {
      guard oldValue != showCursor else { return }
      cursorView.isHidden = !showCursor
      setNeedsLayout()
    }
  }

  /// Width of the cursor.
  public var cursorWidth: CGFloat = 3

  // MARK: - Subviews

  /// `contentView` renders a waveform.
  public lazy var contentView: WaveformContentView = {
    let view = WaveformContentView()
    view.backgroundColor = waveformBackgroundColor
    view.contentMode = .redraw
    addSubview(view)
    return view
  }()

  public lazy var cursorView: WaveformCursorView = {
    let view = WaveformCursorView()
    addSubview(view)
    view.isHidden = !showCursor
    return view
  }()

  public lazy var markersContainer: MarkersView = {
    let view = MarkersView()
    addSubview(view)
    view.backgroundColor = UIColor.transparent
    view.markerSize = CGSize(width: 4, height: 4)
    view.markerTouchSize = view.markerSize
    view.markerLineColor = UIColor.transparent
    view.draggable = false
    return view
  }()

  // MARK: - Subview on/off

  open var showMarker: Bool {
    get { return !markersContainer.isHidden }
    set {
      guard showMarker != newValue else { return }
      markersContainer.isHidden = !newValue
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

  deinit {
    debugPrint("WaveformView.deinit")
    controller?.unsubscribe(self)
  }
}

// MARK: - setup

extension WaveformView {
  private func setup() {
    contentView.isHidden = false
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    addGestureRecognizer(tapGestureRecognizer)
    let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    addGestureRecognizer(panGestureRecognizer)
  }

  override open func layoutSubviews() {
    super.layoutSubviews()

    setupContentView()

    // contentView

    if showMarker {
      contentView.frame = CGRect(x: 0,
                                 y: markersContainer.markerSize.height,
                                 width: bounds.width,
                                 height: bounds.height - markersContainer.markerSize.height)
    } else {
      contentView.frame = bounds
    }

    if !cursorView.isHidden {
      contentView.frame = contentView.frame.insetBy(dx: cursorWidth / 2, dy: 0)
      updateCursor()
      bringSubviewToFront(cursorView)
      cursorView.setNeedsDisplay()
    }
    if showMarker {
      markersContainer.markerLineHeight = contentView.frame.height
      markersContainer.frame = CGRect(x: contentView.frame.minX,
                                      y: 0,
                                      width: contentView.frame.width,
                                      height: markersContainer.markerSize.height)
    }
    contentView.setNeedsLayout()
  }

  private func refreshWaveform() {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.setNeedsLayout() }
      return
    }
    setNeedsLayout()
  }

  private func setupContentView() {
    guard
      let audioContext = controller?.audioContext,
      let downsampler = downsampler
      else { return }

    let calculator = WaveformCalc(audioContext: audioContext, resolution: resolution, totalWidth: frame.width)
    contentView.setup(calculator, downsampler)
    contentView.rendererParams = WaveformRendererParams(decibelMin: downsampler.decibelMin,
                                                        decibelMax: downsampler.decibelMax,
                                                        resolution: calculator.resolution,
                                                        totalWidth: calculator.totalWidth,
                                                        marginLeft: 0,
                                                        lineColor: waveformLineColor)
  }
}

// MARK: - Cursor

extension WaveformView {
  @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
    guard
      timeSeekEnabled,
      let controller = controller,
      let duration = controller.audioContext?.asset.duration
      else { return }
    let progress = recognizer.location(in: self).x / bounds.width
    let time = Double(progress) * duration.seconds
    controller.time.enterSeekMode()
    controller.time.update(time, excludeNotify: self)
    updateCursor()
    controller.time.leaveSeekMode()
  }

  @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
    guard
      timeSeekEnabled,
      let controller = controller,
      let duration = controller.audioContext?.asset.duration
      else { return }

    switch recognizer.state {
    case .began:
      controller.time.enterSeekMode()
    case .ended, .cancelled:
      controller.time.leaveSeekMode()
    case .changed:
      let progress = recognizer.location(in: self).x / bounds.width
      let time = Double(progress) * duration.seconds
      controller.time.update(time, excludeNotify: self)
      updateCursor()
    default:
      return
    }
  }

  private func updateCursor() {
    guard
      !cursorView.isHidden,
      let duration = controller?.audioContext?.asset.duration,
      let time = controller?.time.currentTime
      else { return }
    let progress = time / duration.seconds
    cursorView.frame = CGRect(x: frame.width * CGFloat(progress),
                              y: 0,
                              width: cursorWidth,
                              height: bounds.height)
  }
}

// MARK: - WaveformControllerDelegate

extension WaveformView: AudioDataControllerDelegate {
  public func audioDataControllerDidSetAudioContext(_ controller: AudioDataController) {
    refreshWaveform()
  }

  public func audioDataController(_ controller: AudioDataController, didUpdateTime time: TimeInterval, seekMode: Bool) {
    updateCursor()
  }
}
