//
//  ViewController.swift
//  RDMWaveformView
//
//  Created by HANAI tohru on 04/16/2019.
//  Copyright (c) 2019 HANAI tohru. All rights reserved.
//

import UIKit
import RDMWaveformView

class ViewController: UIViewController {

  var waveformView: RDMWaveformView!
  var loadingStartTime: Date!
  var downsampleStartTime: Date!
  var renderingStartTime: Date!

  override func viewDidLoad() {
    super.viewDidLoad()

    waveformView = RDMWaveformView()
    waveformView.delegate = self
    view.addSubview(waveformView)

    waveformView.translatesAutoresizingMaskIntoConstraints = false
    waveformView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
    waveformView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
    waveformView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
    waveformView.heightAnchor.constraint(equalToConstant: 175).isActive = true
    waveformView.guageView.backgroundColor = UIColor.black

    let url = Bundle.main.url(forResource: "file_example_MP3_700KB", withExtension: "mp3")
    waveformView.audioURL = url
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

extension ViewController: RDMWaveformViewDelegate {

  /// An audio file will be loaded
  public func waveformViewWillLoad(_ waveformView: RDMWaveformView) {
    loadingStartTime = Date()
  }

  /// An audio file was loaded
  public func waveformViewDidLoad(_ waveformView: RDMWaveformView) {
    let end = Date()
    NSLog("Loading done, took %0.3f seconds", end.timeIntervalSince(loadingStartTime))
  }

  /// Rendering will begin
  public func waveformViewWillDownsample(_ waveformView: RDMWaveformView) {
    downsampleStartTime = Date()
  }

  /// Rendering did complete
  public func waveformViewDidDownsample(_ waveformView: RDMWaveformView) {
    let end = Date()
    NSLog("Downsample done, took %0.3f seconds", end.timeIntervalSince(downsampleStartTime))
  }

  /// Rendering will begin
  public func waveformViewWillRender(_ waveformView: RDMWaveformView?) {
    renderingStartTime = Date()
  }

  /// Rendering did complete
  public func waveformViewDidRender(_ waveformView: RDMWaveformView?) {
    let end = Date()
    NSLog("Rendering done, took %0.3f seconds", end.timeIntervalSince(renderingStartTime))
  }
}
