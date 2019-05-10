// https://github.com/Quick/Quick

import Quick
import Nimble
@testable import RDMWaveformView

class RDMWaveformMarkerSpecs: QuickSpec {
  override func spec() {
    describe("Equality") {
      it("can compare") {
        let val1 = RDMWaveformMarker(uuid: "abc", time: 1, data: Data())
        let val2 = RDMWaveformMarker(uuid: "abc", time: 2, data: Data())
        let val3 = RDMWaveformMarker(uuid: "abcd", time: 1, data: Data())

        expect(val1 == val2).to(beTrue())
        expect(val1 == val3).to(beFalse())

        expect(val1 != val2).to(beFalse())
        expect(val1 != val3).to(beTrue())
      }
    }
  }
}
