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

  override func viewDidLoad() {
    super.viewDidLoad()

    waveformView = RDMWaveformView()
    view.addSubview(waveformView)

    waveformView.translatesAutoresizingMaskIntoConstraints = false
    waveformView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
    waveformView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
    waveformView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
    waveformView.heightAnchor.constraint(equalToConstant: 100).isActive = true
    waveformView.backgroundColor = UIColor.red

    let url = Bundle.main.url(forResource: "file_example_MP3_700KB", withExtension: "mp3")
    waveformView.audioURL = url
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

}
