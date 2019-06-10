// https://github.com/Quick/Quick

import Quick
import Nimble
@testable import RDMWaveformView

class MarkersControllerSpecs: QuickSpec {

  override func spec() {
    describe("Initial state") {
      let controller = MarkersController()
      it("should be empty") {
        expect(controller.isEmpty).to(beTrue())
        expect(controller.remove(Marker(time: 0))).to(beFalse())
        controller.removeAll()
        controller.replaceWith([])
        expect(controller.find(uuid: "A")).to(beNil())
        expect(controller.findExact(0)).to(beNil())
        expect(controller.findAfter(0, excludeSkip: false)).to(beNil())
        expect(controller.findBefore(0, excludeSkip: false)).to(beNil())
      }
    }

    describe("manipulate") {
      let controller = MarkersController()
      let listener = Listener()
      controller.delegate = listener

      it("should add a marker") {
        listener.reset()
        expect(controller.add(Marker(uuid: "1", time: 200, data: nil, skip: true))).to(beTrue())
        expect(controller.isEmpty).to(beFalse())
        expect(listener.didAdd).notTo(beNil())
      }
      it("should prevent to add a marker with the same uuid") {
        listener.reset()
        expect(controller.add(Marker(uuid: "1", time: 200, data: nil, skip: true))).to(beFalse())
        expect(listener.didAdd).to(beNil())
      }
      it("should append another marker") {
        listener.reset()
        expect(controller.add(Marker(uuid: "2", time: 300, data: nil, skip: true))).to(beTrue())
        expect(listener.didAdd).notTo(beNil())
      }
      it("should prepend another marker") {
        listener.reset()
        expect(controller.add(Marker(uuid: "3", time: 100, data: nil, skip: true))).to(beTrue())
        expect(listener.didAdd).notTo(beNil())
      }
      it("should order markers by time") {
        var actual = [String]()
        for marker in controller.markers {
          actual.append(marker.uuid)
        }
        expect(actual) == ["3", "1", "2"]
      }

      it("should remove a marker by uuid") {
        listener.reset()
        expect(controller.remove(Marker(uuid: "2", time: 400))).to(beTrue())
        expect(controller.isEmpty).to(beFalse())
        expect(listener.didRemove).notTo(beNil())
        expect(listener.didRemoveAll).to(beFalse())
      }

      it("should fail to remove for the already removed uuid") {
        listener.reset()
        expect(controller.remove(Marker(uuid: "2", time: 400))).to(beFalse())
        expect(listener.didRemove).to(beNil())
        expect(listener.didRemoveAll).to(beFalse())
      }

      it("should remove all markers") {
        listener.reset()
        controller.removeAll()
        expect(controller.isEmpty).to(beTrue())
        expect(listener.didRemove).to(beNil())
        expect(listener.didRemoveAll).to(beTrue())
      }
    }

    describe("find") {
      let controller = MarkersController()
      let markers = [
        Marker(uuid: "A", time: 100, data: nil, skip: true),
        Marker(uuid: "B", time: 200, data: nil, skip: false),
        Marker(uuid: "C", time: 300, data: nil, skip: true),
        Marker(uuid: "D", time: 400, data: nil, skip: false),
        Marker(uuid: "E", time: 500, data: nil, skip: true),
      ]
      controller.replaceWith(markers)

      it("find a marker by UUID") {
        expect(controller.find(uuid: "B")) == markers[1]
        expect(controller.find(uuid: "C")) == markers[2]
        expect(controller.find(uuid: "Z")).to(beNil())
      }
      it("find a marker by time") {
        expect(controller.findExact(200)) == markers[1]
        expect(controller.findExact(300)) == markers[2]
        expect(controller.findExact(999)).to(beNil())
      }
      it("find a prior marker by time") {
        expect(controller.findBefore(100, excludeSkip: false)).to(beNil())
        expect(controller.findBefore(101, excludeSkip: false)) == markers[0]
        expect(controller.findBefore(101, excludeSkip: true)).to(beNil())
        expect(controller.findBefore(200, excludeSkip: false)) == markers[0]
        expect(controller.findBefore(201, excludeSkip: false)) == markers[1]
        expect(controller.findBefore(500, excludeSkip: false)) == markers[3]
        expect(controller.findBefore(501, excludeSkip: false)) == markers[4]
        expect(controller.findBefore(501, excludeSkip: true)) == markers[3]
      }
      it("find a following marker by time") {
        expect(controller.findAfter(99, excludeSkip: false)) == markers[0]
        expect(controller.findAfter(99, excludeSkip: true)) == markers[1]
        expect(controller.findAfter(100, excludeSkip: false)) == markers[1]
        expect(controller.findAfter(499, excludeSkip: false)) == markers[4]
        expect(controller.findAfter(499, excludeSkip: true)).to(beNil())
        expect(controller.findAfter(500, excludeSkip: true)).to(beNil())
      }
    }
  }
}

fileprivate class Listener: NSObject, MarkersControllerDelegate {
  var didAdd: Marker?
  var willBeginDrag: Marker?
  var didEndDrag: Marker?
  var didUpdateTime: Marker?
  var didUpdateData: Marker?
  var didRemove: Marker?
  var didRemoveAll = false

  func reset() {
    didAdd = nil
    willBeginDrag = nil
    didEndDrag = nil
    didUpdateTime = nil
    didUpdateData = nil
    didRemove = nil
    didRemoveAll = false

  }

  func markersController(_ controller: MarkersController, didAdd marker: Marker) {
    didAdd = marker
  }
  func markersController(_ controller: MarkersController, willBeginDrag marker: Marker) {
    willBeginDrag = marker
  }
  func markersController(_ controller: MarkersController, didEndDrag marker: Marker, removing: Bool) {
    didEndDrag = marker
  }
  func markersController(_ controller: MarkersController, didUpdateTime marker: Marker) {
    didUpdateTime = marker
  }
  func markersController(_ controller: MarkersController, didUpdateData marker: Marker) {
    didUpdateData = marker
  }
  func markersController(_ controller: MarkersController, didRemove marker: Marker) {
    didRemove = marker
  }
  func markersControllerDidRemoveAllMarkers(_ controller: MarkersController) {
    didRemoveAll = true
  }
}
