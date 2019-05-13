// https://github.com/Quick/Quick

import Quick
import Nimble
@testable import RDMWaveformView

class SampleBufferSpecs: QuickSpec {
  override func spec() {
    describe("SampleBuffer") {
      let source: [UInt8] = [ 1, 2, 3, 4, 5 ]

      it("recycles the inner buffer") {
        var actual1: Data?
        var actual2: Data?
        let buffer = SampleBuffer(bufferSize: 3, onPopulated: { data in
          if actual1 == nil {
            actual1 = data
          } else {
            actual2 = data
          }
        })

        source[0..<2].withUnsafeBufferPointer { buffer.append($0) }
        source.withUnsafeBufferPointer { buffer.append($0) }
        expect(actual1).toNot(beNil())
        expect(actual2).toNot(beNil())
        expect(actual1?.elementsEqual([1, 2, 1])).to(beTrue())
        expect(actual2?.elementsEqual([2, 3, 4])).to(beTrue())

        actual1 = nil
        actual2 = nil
        buffer.flush()
        expect(actual1?.elementsEqual([5])).to(beTrue())
      }
    }
  }
}
