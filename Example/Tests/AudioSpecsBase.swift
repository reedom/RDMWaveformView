//
//  AudioSpecsBase.swift
//  RDMWaveformView_Tests
//
//  Created by HANAI Tohru on 2019/05/27.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Quick
import Nimble
@testable import RDMWaveformView

class AudioSpecsBase: QuickSpec {
  lazy var validURL: URL = {
    if let url = Bundle.main.url(forResource: "file_example_MP3_700KB", withExtension: "mp3") {
      return url
    } else {
      fail("Failed to find resource: file_example_MP3_700KB.mp3")
      fatalError()
    }
  }()

  let invalidURL = URL(fileURLWithPath: "non-existing-file.mp3")

  func getAudioContext(callback: @escaping (_ audioContext: AudioContext) -> Void) {
    AudioContext.load(fromAudioURL: validURL) { result in
      switch result {
      case .success(let audioContext):
        callback(audioContext)
      case .failure(let error):
        fail(error.localizedDescription)
        return
      }
    }
  }

  func createController(callback: @escaping (_ controller: AudioDataController) -> Void) {
    getAudioContext() { audioContext in
      let controller = AudioDataController()
      controller.audioContext = audioContext
      callback(controller)
    }
  }
}
