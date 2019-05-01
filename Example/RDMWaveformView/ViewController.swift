//
//  ViewController.swift
//  RDMWaveformView
//
//  Created by HANAI tohru on 04/16/2019.
//  Copyright (c) 2019 HANAI tohru. All rights reserved.
//

import UIKit
import RDMWaveformView
import MediaPlayer

class ViewController: UIViewController {

  var scrollableWaveformView: RDMScrollableWaveformView!
  var waveformView: RDMWaveformView!
  var loadingStartTime: Date!
  var downsampleStartTime: Date!
  var renderingStartTime: Date!
  var player: AVAudioPlayer!
  var playButton: UIButton!
  var stopButton: UIButton!
  var timeLabel: UILabel!
  var timer: Timer?
  var needsToResumeAudio = false

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = UIColor.black

    let controller = RDMWaveformController()
    controller.delegate = self
    let markers = RDMWaveformMarkersController()
    markers.add(at: 6, data: nil)

    scrollableWaveformView = {
      let waveformView = RDMScrollableWaveformView()
      view.addSubview(waveformView)

      waveformView.guageView.backgroundColor = UIColor.black
      waveformView.showMarker = true
      waveformView.controller = controller
      waveformView.markersController = markers
      waveformView.translatesAutoresizingMaskIntoConstraints = false
      waveformView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
      waveformView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
      waveformView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
      waveformView.heightAnchor.constraint(equalToConstant: 175).isActive = true
      return waveformView
    }()

    waveformView = {
      let waveformView = RDMWaveformView()
      view.addSubview(waveformView)

      waveformView.controller = controller
      waveformView.markersController = markers
      waveformView.translatesAutoresizingMaskIntoConstraints = false
      waveformView.topAnchor.constraint(equalTo: scrollableWaveformView.bottomAnchor, constant: 12).isActive = true
      waveformView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
      waveformView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
      waveformView.heightAnchor.constraint(equalToConstant: 50).isActive = true
      return waveformView
    }()

    timeLabel = {
      let label = UILabel()
      view.addSubview(label)
      label.translatesAutoresizingMaskIntoConstraints = false
      label.topAnchor.constraint(equalTo: waveformView.bottomAnchor, constant: 12).isActive = true
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
      label.widthAnchor.constraint(equalToConstant: 100).isActive = true
      label.heightAnchor.constraint(equalToConstant: 20).isActive = true
      label.textAlignment = .center
      label.textColor = UIColor.white
      label.font = UIFont(name: "Courier", size: 18)!
      return label
    }()

    playButton = {
      let button = UIButton(type: .custom)
      view.addSubview(button)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 12).isActive = true
      button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
      button.widthAnchor.constraint(equalToConstant: 35).isActive = true
      button.heightAnchor.constraint(equalToConstant: 25).isActive = true
      button.setTitle("▷", for: .normal)
      button.contentHorizontalAlignment = .center
      button.setTitleColor(UIColor.white, for: .normal)
      button.addTarget(self, action: #selector(handlePlay), for: .touchUpInside)
      return button
    }()

    stopButton = {
      let button = UIButton(type: .custom)
      view.addSubview(button)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.topAnchor.constraint(equalTo: playButton.topAnchor).isActive = true
      button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
      button.widthAnchor.constraint(equalToConstant: 35).isActive = true
      button.heightAnchor.constraint(equalToConstant: 25).isActive = true
      button.setTitle("◼", for: .normal)
      button.contentHorizontalAlignment = .center
      button.setTitleColor(UIColor.white, for: .normal)
      button.addTarget(self, action: #selector(handleStop), for: .touchUpInside)
      button.isHidden = true
      return button
    }()

    _ = { () -> UIButton in
      let button = UIButton(type: .custom)
      self.view.addSubview(button)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.topAnchor.constraint(equalTo: playButton.topAnchor).isActive = true
      button.rightAnchor.constraint(equalTo: playButton.leftAnchor, constant: -8).isActive = true
      button.widthAnchor.constraint(equalToConstant: 35).isActive = true
      button.heightAnchor.constraint(equalToConstant: 25).isActive = true
      button.setTitle("⟸", for: .normal)
      button.contentHorizontalAlignment = .center
      button.setTitleColor(UIColor.white, for: .normal)
      button.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
      return button
    }()

    _ = { () -> UIButton in
      let button = UIButton(type: .custom)
      view.addSubview(button)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.topAnchor.constraint(equalTo: playButton.topAnchor).isActive = true
      button.leftAnchor.constraint(equalTo: playButton.rightAnchor, constant: 8).isActive = true
      button.widthAnchor.constraint(equalToConstant: 35).isActive = true
      button.heightAnchor.constraint(equalToConstant: 25).isActive = true
      button.setTitle("⟹", for: .normal)
      button.contentHorizontalAlignment = .center
      button.setTitleColor(UIColor.white, for: .normal)
      button.addTarget(self, action: #selector(handleForward), for: .touchUpInside)
      return button
    }()

    _ = { () -> UIButton in
      let button = UIButton(type: .custom)
      view.addSubview(button)
      button.translatesAutoresizingMaskIntoConstraints = false
      button.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 12).isActive = true
      button.centerXAnchor.constraint(equalTo: playButton.centerXAnchor).isActive = true
      button.widthAnchor.constraint(equalToConstant: 80).isActive = true
      button.heightAnchor.constraint(equalToConstant: 25).isActive = true
      button.setTitle("reload", for: .normal)
      button.contentHorizontalAlignment = .center
      button.setTitleColor(UIColor.white, for: .normal)
      button.addTarget(self, action: #selector(handleReload), for: .touchUpInside)
      return button
    }()

    // "⟸ ⟹" "■" "◼"
    guard let url = Bundle.main.url(forResource: "file_example_MP3_700KB", withExtension: "mp3") else {
      NSLog("Failed to find resource: file_example_MP3_700KB.mp3")
      return
    }

    controller.load(url) { (error) in
      if let error = error {
        print(error)
      }
    }

    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)

      player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
      guard let player = player else { return }
      player.delegate = self
      timeLabel.text = getTimeString(player.currentTime)
    } catch let error {
      print(error.localizedDescription)
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  @objc public func handleReload() {
    guard let controller = scrollableWaveformView.controller else { return }
    guard let url = Bundle.main.url(forResource: "file_example_MP3_700KB", withExtension: "mp3") else {
      NSLog("Failed to find resource: file_example_MP3_700KB.mp3")
      return
    }

    controller.load(url) { (error) in
      if let error = error {
        print(error)
      }
    }
  }
}

extension ViewController: AVAudioPlayerDelegate {
  /* audioPlayerDidFinishPlaying:successfully: is called when a sound has finished playing. This method is NOT called if the player is stopped due to an interruption. */
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    stopButton.isHidden = true
    playButton.isHidden = false
    timer?.invalidate()
  }

  /* if an error occurs while decoding it will be reported to the delegate. */
  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {

  }

  /* AVAudioPlayer INTERRUPTION NOTIFICATIONS ARE DEPRECATED - Use AVAudioSession instead. */
  /* audioPlayerBeginInterruption: is called when the audio session has been interrupted while the player was playing. The player will have been paused. */
  func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {

  }

  /* audioPlayerEndInterruption:withOptions: is called when the audio session interruption has ended and this player had been interrupted while playing. */
  /* Currently the only flag is AVAudioSessionInterruptionFlags_ShouldResume. */
  func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {

  }
}

extension ViewController: RDMWaveformControllerDelegate {
  public func waveformController(_ controller: RDMWaveformController, didUpdateTime time: TimeInterval, seekMode: Bool) {
    timeLabel.text = getTimeString(time)
    if !player.isPlaying {
      player.currentTime = time
    }
  }

  public func waveformControllerDidEnterSeekMode(_ controller: RDMWaveformController) {
    if player.isPlaying {
      needsToResumeAudio = true
      player.stop()
    }
  }

  public func waveformControllerDidLeaveSeekMode(_ controller: RDMWaveformController) {
    if needsToResumeAudio {
      needsToResumeAudio = false
      handlePlay()
    }
  }
}

extension ViewController {
  @objc func handlePlay() {
    guard let controller = scrollableWaveformView.controller else { return }
    if controller.seekMode {
      needsToResumeAudio = true
    } else {
      player.play()
    }
    playButton.isHidden = true
    stopButton.isHidden = false
    timer = Timer.scheduledTimer(timeInterval: 0.01,
                                 target: self,
                                 selector: #selector(handleTimer),
                                 userInfo: nil,
                                 repeats: true)
  }

  @objc func handleStop() {
    timer?.invalidate()
    needsToResumeAudio = false
    player.stop()
    stopButton.isHidden = true
    playButton.isHidden = false
  }

  @objc func handleBack() {
    guard let controller = scrollableWaveformView.controller else { return }

    player.currentTime = player.currentTime - 6
    if !player.isPlaying {
      controller.currentTime = player.currentTime
    }
  }

  @objc func handleForward() {
    guard let controller = scrollableWaveformView.controller else { return }

    player.currentTime = player.currentTime + 6
    if !player.isPlaying {
      controller.currentTime = player.currentTime
    }
  }

  @objc func handleTimer() {
    guard let controller = scrollableWaveformView.controller else { return }
    controller.currentTime = player.currentTime
  }

  func getTimeString(_ seconds: Double) -> String {
    let sec = Int(seconds)
    let msec = Int((seconds - Double(sec)) * 1000)
    return String(format: "%02d:%03d", sec, msec)
  }
}
