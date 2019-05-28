//
//  DownsamplerSpecs.swift
//  RDMWaveformView_Tests
//
//  Created by HANAI Tohru on 2019/05/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import SparseRanges
@testable import RDMWaveformView

class DownsamplerSpecs: AudioSpecsBase {
  var downsampler: Downsampler!

  override func spec() {
    guard !UIDevice.isSimulator else {
      print("Downsampler doesn't run on a simulator")
      return
    }

    describe("downsample") {
      it("downsamples") {
        waitUntil(timeout: 1000) { done in
          self.createController { controller in
            self.downsampler = Downsampler(controller)

            let handler1 = DownsampledHandler1() { (handler, downsampleRange, downsamples) in
              expect(handler.downsamples.count) == downsampleRange.lowerBound
            }

            let handler2 = DownsampledHandler1() { (handler, downsampleRange, downsamples) in
              expect(handler.downsamples.count) == downsampleRange.lowerBound
            }

            self.downsampler.addHandler(downsampleRate: 32000/25, handler: handler1)
            self.downsampler.addHandler(downsampleRate: 32000, handler: handler2)


            self.downsampler.startLoading(completionHandler: { result in
              switch result {
              case .success():
                expect(handler1.downsamples.count) <= handler2.downsamples.count * 25
                expect(handler1.downsamples.count) >= (handler2.downsamples.count - 1) * 25
                break
              case .failure(let error):
                fail(error.localizedDescription)
                break
              }
              done()
            })
          }
        }
      }
    }
  }

  class DownsampledHandler1: DownsampledHandler {
    var downsampleRange: DownsampleRange?
    var downsamples = [CGFloat]()

    typealias Callback = (
      _ handler: DownsampledHandler1,
      _ downsampleRange: DownsampleRange,
      _ downsamples: ArraySlice<CGFloat>
      ) -> Void
    var callback: Callback

    init(callback: @escaping Callback) {
      self.callback = callback
    }

    func downsamplerDidDownsample(downsampleRange: DownsampleRange, downsamples: ArraySlice<CGFloat>) {
      callback(self, downsampleRange, downsamples)
      self.downsampleRange = downsampleRange
      self.downsamples.append(contentsOf: downsamples)
    }
  }
}
