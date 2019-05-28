//
//  AudioContextSpecs.swift
//  RDMWaveformView_Tests
//
//  Created by HANAI Tohru on 2019/05/27.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

// https://github.com/Quick/Quick

import Quick
import Nimble
import AVFoundation
@testable import RDMWaveformView

class AudioContextSpecs: QuickSpec {
  lazy var validURL: URL = {
    if let url = Bundle.main.url(forResource: "file_example_MP3_700KB", withExtension: "mp3") {
      return url
    } else {
      fail("Failed to find resource: file_example_MP3_700KB.mp3")
      fatalError()
    }
  }()

  let invalidURL = URL(fileURLWithPath: "non-existing-file.mp3")

  override func spec() {
    describe("load") {
      it("loads a valid audio file") {
        waitUntil { done in
          AudioContext.load(fromAudioURL: self.validURL) { result in
            switch result {
            case .success(let audioContext):
              expect(audioContext.audioURL) == self.validURL
              expect(audioContext.sampleRate) == 32000
              expect(audioContext.totalSamples) == 872064
              expect(audioContext.channelCount) == 2
              expect(audioContext.asset).notTo(beNil())
              expect(audioContext.assetTrack).notTo(beNil())
              done()
            case .failure(let error):
              fail(error.message)
              done()
            }
          }
        }
      }

      it("returns error if the audio URL is invalid") {
        waitUntil { done in
          AudioContext.load(fromAudioURL: self.invalidURL) { result in
            switch result {
            case .success(_):
              fail()
              done()
            case .failure(let error):
              expect(error.localizedDescription.isEmpty).to(beFalse())
              done()
            }
          }
        }
      }
    }
    describe("iterateSampleData") {
      it("iterates only specified duration") {
        var callTimes = 0

        AudioContext.load(fromAudioURL: self.validURL) { result in
          switch result {
          case .success(let audioContext):
            let twoSecs = CMTimeRange(start: CMTimeMakeWithSeconds(0, 1), duration: CMTimeMakeWithSeconds(1, 1))
            let downsampleRate = 10000
            let downsampleUnit = audioContext.channelCount * downsampleRate
            let readUnit = downsampleUnit * MemoryLayout<Int16>.size
            audioContext.iterateSampleData(duration: twoSecs, unitLength: readUnit) { (sampleData, lastCall) in
              callTimes += 1
              if lastCall {
                expect(sampleData.count) == 8000
                expect(callTimes) == 4
              } else {
                expect(sampleData.count) == readUnit
              }
              return true
            }
          case .failure(let error):
            fail(error.message)
          }
        }
        expect(callTimes).toEventually(equal(4))
        expect(callTimes).toEventuallyNot(equal(5))
      }

      it("is cancellable") {
        var callTimes = 0

        AudioContext.load(fromAudioURL: self.validURL) { result in
          switch result {
          case .success(let audioContext):
            let twoSecs = CMTimeRange(start: CMTimeMakeWithSeconds(0, 1), duration: CMTimeMakeWithSeconds(2, 1))
            audioContext.iterateSampleData(duration: twoSecs, unitLength: 10000) { (sampleData, lastCall) in
              callTimes += 1
              if callTimes == 2 {
                return false
              }
              return true
            }
          case .failure(let error):
            fail(error.message)
          }
        }
        expect(callTimes).toEventually(equal(2))
        expect(callTimes).toEventuallyNot(equal(3))
      }
    }
  }
}
