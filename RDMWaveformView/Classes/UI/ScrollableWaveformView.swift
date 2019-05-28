//
//  ScrollableWaveformView.swift
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
open class ScrollableWaveformView: UIView {
  // MARK: - Types

  /// The placement of the mesurement origin.
  /// In other words, where the user see the current mesurement time.
  public enum WaveformAlignment {
    case left
    case center
  }

  /// The options on rendering waveforms.
  public struct WaveformRenderOptions {
    /// Renderer draws one second amount of waveform With this width, in pixel.
    let widthPerSecond: Int
    let linesPerSecond: Int
    let lineWidth: CGFloat
  }

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

  /// Maximum decibel in a audio track.
  public var decibelMin: CGFloat = -50
  /// Minimum decibel in a audio track.
  public var decibelMax: CGFloat = -10

  // MARK: - Appearance properties

  /// The color of the waveform's lines.
  public var waveformLineColor: UIColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)

  /// The background color of the waveform area.
  public var waveformBackgroundColor = UIColor(red: 26/255, green: 25/255, blue: 31/255, alpha: 1) {
    didSet {
      contentView.backgroundColor = waveformBackgroundColor
    }
  }

  /// The color of the margin areas.
  public var marginBackgroundColor = UIColor(red: 18/255, green: 18/255, blue: 20/255, alpha: 1) {
    didSet {
      scrollView.backgroundColor = marginBackgroundColor
    }
  }

  /// The placement of the mesurement origin.
  /// In other words, where the user see the current mesurement time.
  public var waveformContentAlignment = WaveformAlignment.center {
    didSet {
      setNeedsLayout()
    }
  }

  public var waveformRenderOptions = WaveformRenderOptions(widthPerSecond: 100, linesPerSecond: 25, lineWidth: 1)

  private var resolution: WaveformResolution {
    return .perSecond(width: waveformRenderOptions.widthPerSecond,
                      lines: waveformRenderOptions.linesPerSecond,
                      lineWidth: waveformRenderOptions.lineWidth)
  }

  // MARK: - Subview on/off

  open var showMarker: Bool {
    get { return !markersContainer.isHidden }
    set {
      markersContainer.isHidden = !newValue
      setNeedsLayout()
    }
  }

  open var showAddMarkerButton: Bool {
    get { return markersContainer.showAddMarkerButton }
    set {
      markersContainer.showAddMarkerButton = newValue
      markersContainer.setNeedsLayout()
    }
  }

  open var showGuage: Bool {
    get { return !guageView.isHidden }
    set {
      guageView.isHidden = !newValue
      setNeedsLayout()
    }
  }

  open var showCenterGuide: Bool {
    get { return !centerGuide.isHidden }
    set {
      centerGuide.isHidden = !newValue
      setNeedsLayout()
    }
  }

  // MARK: - helper properties

  private var contentMargin: CGFloat {
    switch waveformContentAlignment{
    case .center:
      return scrollView.frame.width / 2
    case .left:
      return 0
    }
  }

  public var guageHeight: CGFloat = 22 {
    didSet {
      setNeedsLayout()
    }
  }

  /// MARK: - Subviews

  /// `scrollView` contains `contentView`.
  open lazy var scrollView: UIScrollView = {
    let scrollView = WaveformScrollView(frame: bounds)
    scrollView.backgroundColor = UIColor.transparent
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    addSubview(scrollView)
    scrollView.delegate = self
    return scrollView
  }()

  /// `contentView` renders a waveform.
  public lazy var contentView: ScrollableWaveformContentView = {
    let contentView = ScrollableWaveformContentView()
    contentView.backgroundColor = waveformBackgroundColor
    contentView.contentMode = .redraw
    scrollView.addSubview(contentView)
    return contentView
  }()

  /// `contentBackgroundView` renders `marginBackgroundColor`
  public lazy var contentBackgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = marginBackgroundColor
    scrollView.addSubview(view)
    return view
  }()

  /// `guageView` renders a time guage. Used optionally.
  public lazy var guageView: WaveformTimeGuageView = {
    let guageView = WaveformTimeGuageView()
    guageView.backgroundColor = marginBackgroundColor
    guageView.isUserInteractionEnabled = false
    addSubview(guageView)
    return guageView
  }()

  public lazy var centerGuide: CenterGuide = {
    let view = CenterGuide()
    addSubview(view)
    view.backgroundColor = UIColor.transparent
    return view
  }()

  public lazy var markersContainer: MarkersView = {
    let view = MarkersView()
    addSubview(view)
    view.backgroundColor = UIColor.transparent
    return view
  }()

  // MARK: - Private vars

  /// Waveform calculator
  private var calculator: WaveformCalc?

  /// Current audio context to be used for rendering
  private var audioContext: AudioContext? {
    return controller?.audioContext
  }

  private var lastScrollContentOffset: CGFloat = 0

  // MARK: - view lifecycle

  deinit {
    debugPrint("ScrollableWaveformView.deinit")
    controller?.unsubscribe(self)
    downsampler?.cancel()
  }
}

extension ScrollableWaveformView {
  public func setMarkersAtBlanks(decibelLessThan: Double,
                                 blankMomentLongerThan: TimeInterval) {
    guard
      showMarker,
      let downsampler = downsampler,
      let markersController = markersController,
      let audioContext = audioContext
      else { return }
    downsampler.findBlankMoments(decibelLessThan: decibelLessThan,
                                 blankMomentLongerThan: blankMomentLongerThan)
    { [weak self] from, to in
      guard self != nil else { return }
      if 0 < from {
        markersController.add(at: from, skip: true)
      }
      if to < audioContext.asset.duration.seconds {
        markersController.add(at: to)
      }
    }
  }
}

extension ScrollableWaveformView {
  override open func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow == nil {
      downsampler?.cancel()
    }
  }

  override open func layoutSubviews() {
    super.layoutSubviews()

    setupContentView()

    guard
      let calculator = calculator,
      let totalSamples = controller?.audioContext?.totalSamples,
      0 < totalSamples
      else {
        // TODO show empty view
        return
    }

    // Layout markersContainer and scrollView

    if showMarker {
      scrollView.frame = CGRect(x: 0,
                                y: markersContainer.markerTouchSize.height,
                                width: bounds.width,
                                height: bounds.height - markersContainer.markerTouchSize.height)
    } else {
      scrollView.frame = bounds
    }

    if showCenterGuide {
      if showGuage {
        // Cut top `centerGuide.markerDiameter` pixels off.
        // (No need to cut bottom since the bottom marker overlays in the guage area)
        scrollView.frame = scrollView.frame
          .insetBy(dx: 0, dy: centerGuide.markerDiameter)
          .offsetBy(dx: 0, dy: centerGuide.markerDiameter / 2)
      } else {
        // Shrink vertically
        scrollView.frame = scrollView.frame
          .insetBy(dx: 0, dy: centerGuide.markerDiameter)
      }
    }

    // Layout scrollView's subviews

    let waveformWidth = calculator.totalWidth
    scrollView.contentSize = CGSize(width: ceil(waveformWidth + contentMargin * 2),
                                    height: scrollView.frame.height)
    contentView.marginLeft = contentMargin
    contentView.visibleWidth = scrollView.frame.width
    if showGuage {
      contentView.frame = CGRect(x: ceil(contentMargin),
                                 y: 0,
                                 width: waveformWidth,
                                 height: scrollView.contentSize.height - guageHeight)
      guageView.frame = CGRect(x: 0,
                               y: scrollView.frame.maxY - guageHeight,
                               width: frame.width,
                               height: guageHeight)
    } else {
      contentView.frame = CGRect(x: ceil(contentMargin),
                                 y: 0,
                                 width: waveformWidth,
                                 height: scrollView.contentSize.height)
    }
    contentBackgroundView.frame = CGRect(x: -scrollView.frame.width / 2,
                                         y: 0,
                                         width: scrollView.contentSize.width + scrollView.frame.width,
                                         height: contentView.frame.height)

    // Layout centerGuide

    if showCenterGuide {
      centerGuide.frame = CGRect(x: (bounds.width - centerGuide.markerDiameter) / 2,
                                 y: scrollView.frame.minY - centerGuide.markerDiameter,
                                 width: centerGuide.markerDiameter,
                                 height: contentView.frame.height + centerGuide.markerDiameter * 2)
    }

    // Layout makerContainer

    if showMarker {
      markersContainer.markerLineHeight = scrollView.frame.minY + contentView.frame.height
      markersContainer.frame = CGRect(x: contentView.frame.minX,
                                      y: 0,
                                      width: contentView.frame.width,
                                      height: markersContainer.markerTouchSize.height)
    }

    // Reorder subviews

    scrollView.sendSubviewToBack(contentBackgroundView)
    bringSubviewToFront(centerGuide)
    bringSubviewToFront(markersContainer)
    bringSubviewToFront(guageView)

    // Advice subviews to render

    setupContentView()
    guageView.contentOffset = scrollView.contentOffset.x
    contentView.contentOffset = scrollView.contentOffset.x
    if showMarker {
      markersContainer.setNeedsLayout()
    }
  }
}

extension ScrollableWaveformView {
  /// The current time that the waveform points at.
  private func timeFromScrollOffset() -> TimeInterval {
    guard
      let totalSamples = controller?.audioContext?.totalSamples,
      let duration = controller?.audioContext?.asset.duration,
      0 < totalSamples,
      0 < contentView.frame.width
      else { return 0 }
    let progress = scrollView.contentOffset.x / contentView.frame.width
    return max(0, min(duration.seconds, duration.seconds * Double(progress)))
  }

  private func updateScrollOffset() {
    guard
      let duration = controller?.audioContext?.asset.duration,
      let currentTime = controller?.time.currentTime,
      0 < duration.seconds
      else { return }
    let progress = max(0, min(duration.seconds, currentTime)) / duration.seconds
    let x = contentView.frame.width * CGFloat(progress)
    scrollView.contentOffset = CGPoint(x: x, y: 0)
  }
}

// MARK: - Waveform content management

extension ScrollableWaveformView {
  private func refreshWaveform() {
    markersContainer.duration = controller?.audioContext?.asset.duration.seconds ?? 0
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.setNeedsLayout() }
      return
    }
    setNeedsLayout()
  }

  private func setupContentView() {
    guard let audioContext = controller?.audioContext else { return }

    calculator = WaveformCalc(audioContext: audioContext, resolution: resolution)
    if let calculator = calculator, let downsampler = downsampler {
      contentView.setup(calculator, downsampler)
      contentView.rendererParams = WaveformRendererParams(decibelMin: downsampler.decibelMin,
                                                          decibelMax: downsampler.decibelMax,
                                                          resolution: calculator.resolution,
                                                          totalWidth: calculator.totalWidth,
                                                          marginLeft: 0.5,
                                                          lineColor: waveformLineColor)
      guageView.rendererParams = WaveformTimeGuageRendererParams()
    }
  }
}

// MARK: - UIScrollViewDelegate
extension ScrollableWaveformView: UIScrollViewDelegate {
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    if !scrollView.isDecelerating {
      controller?.time.enterSeekMode()
    }
  }

  public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      self.controller?.time.leaveSeekMode()
    }
  }

  // any offset changes
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // markerContainer
    if showMarker {
      let dx = (contentView.frame.minX - scrollView.contentOffset.x) - markersContainer.frame.minX
      markersContainer.frame = markersContainer.frame.offsetBy(dx: dx, dy: 0)
      markersContainer.currentTime = controller?.time.currentTime ?? 0
      markersContainer.contentOffset = scrollView.contentOffset.x
      markersContainer.updateDraggingMarkerPosition(scrollDelta: scrollView.contentOffset.x - lastScrollContentOffset)
    }

    // contentView and guideView

    let contentOffset = max(0, min(scrollView.contentSize.width, scrollView.contentOffset.x))
    lastScrollContentOffset = contentOffset

    guageView.contentOffset = scrollView.contentOffset.x
    contentView.contentOffset = scrollView.contentOffset.x

    // delegate

    let seconds = timeFromScrollOffset()
    self.controller?.time.update(seconds, excludeNotify: self)
  }

  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    self.controller?.time.leaveSeekMode()
  }
}

extension ScrollableWaveformView: AudioDataControllerDelegate {
  public func audioDataControllerDidSetAudioContext(_ controller: AudioDataController) {
    refreshWaveform()
  }

  public func audioDataController(_ controller: AudioDataController, didUpdateTime time: TimeInterval, seekMode: Bool) {
    updateScrollOffset()
  }
}

class WaveformScrollView: UIScrollView {
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  override open func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
    return true
  }
  override open func touchesShouldCancel(in view: UIView) -> Bool {
    return true
  }
}
