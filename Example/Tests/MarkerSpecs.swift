// https://github.com/Quick/Quick

import Quick
import Nimble
@testable import RDMWaveformView

class MarkerSpecs: QuickSpec {
  override func spec() {
    describe("Equality") {
      it("can compare") {
        let val1 = Marker(uuid: "abc", time: 1, data: Data())
        let val2 = Marker(uuid: "abc", time: 2, data: Data())
        let val3 = Marker(uuid: "abcd", time: 1, data: Data())

        expect(val1 == val2).to(beTrue())
        expect(val1 == val3).to(beFalse())

        expect(val1 != val2).to(beFalse())
        expect(val1 != val3).to(beTrue())
      }
    }
  }
}
