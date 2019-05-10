// https://github.com/Quick/Quick

import Quick
import Nimble
@testable import RDMWaveformView

class RDMWaveformControllerSpecs: QuickSpec {
  var gotWillLoadAudio = false
  var gotDidLoadAudio = false
  var gotDidUpdateTime = false
  var gotDidReset = false
  var gotDidEnterSeekMode = false
  var gotDidLeaveSeekMode = false

  func resetEventStatus() {
    self.gotWillLoadAudio = false
    self.gotDidLoadAudio = false
    self.gotDidUpdateTime = false
    self.gotDidReset = false
    self.gotDidEnterSeekMode = false
    self.gotDidLeaveSeekMode = false
  }

  override func spec() {
    describe("audioContext") {
      it("fires events before and after loading") {
        self.resetEventStatus()
        guard let url = Bundle.main.url(forResource: "file_example_MP3_700KB", withExtension: "mp3") else {
          fail("Failed to find resource: file_example_MP3_700KB.mp3")
          return
        }

        let controller = RDMWaveformController()
        controller.subscribe(self)
        controller.load(url) { error in
          expect(error).to(beNil())
          expect(controller.hasAudio).to(beTrue())
        }
        expect(self.gotWillLoadAudio).to(beTrue())
        expect(self.gotDidLoadAudio).toEventually(beTrue())
      }

      it("returns error if the audio URL is invalid") {
        self.resetEventStatus()
        let url = URL(fileURLWithPath: "non-existing-file.mp3")

        let controller = RDMWaveformController()
        controller.subscribe(self)
        controller.load(url) { error in
          expect(error).notTo(beNil())
          expect(controller.hasAudio).to(beFalse())
          expect(self.gotDidLoadAudio).to(beFalse())
        }
        expect(self.gotWillLoadAudio).to(beTrue())
        expect(self.gotDidLoadAudio).toNotEventually(beTrue())
      }
    }

    describe("currentTime") {
      it("ignores to be updated if there is no audio") {
        self.resetEventStatus()

        let controller = RDMWaveformController()
        controller.subscribe(self)
        controller.currentTime = 1
        expect(controller.currentTime) == 0
        expect(self.gotDidUpdateTime).to(beFalse())
      }

      it("tells updates") {
        self.resetEventStatus()

        waitUntil { done in
          self.createController() { controller in
            expect(self.gotDidUpdateTime).to(beFalse())
            expect(controller.currentTime) == 0
            controller.currentTime = 1
            expect(self.gotDidUpdateTime).to(beTrue())
            done()
          }
        }
      }

      it("tells updates even there is no change") {
        self.resetEventStatus()

        waitUntil { done in
          self.createController() { controller in
            controller.currentTime = 0
            expect(self.gotDidUpdateTime).to(beTrue())
            done()
          }
        }
      }
    }

    describe("update") {
      it("skips notification to the caller") {
        self.resetEventStatus()

        waitUntil { done in
          self.createController() { controller in
            let another = AnotherObserver()
            controller.subscribe(another)
            controller.updateTime(1, excludeNotify: self)
            expect(self.gotDidUpdateTime).to(beFalse())
            expect(another.gotDidUpdateTime).to(beTrue())
            done()
          }
        }
      }
    }

    describe("seekMode") {
      it("ignores entring to the mode if there is no audio") {
        let controller = RDMWaveformController()
        controller.enterSeekMode()
        expect(controller.seekMode).to(beFalse())
      }

      it("counts the number of entring and leaving") {
        self.resetEventStatus()

        waitUntil { done in
          self.createController() { controller in
            controller.enterSeekMode()
            expect(controller.seekMode).to(beTrue())
            expect(self.gotDidEnterSeekMode).to(beTrue())
            expect(self.gotDidLeaveSeekMode).to(beFalse())

            self.gotDidEnterSeekMode = false
            controller.enterSeekMode()
            expect(controller.seekMode).to(beTrue())
            expect(self.gotDidEnterSeekMode).to(beFalse())

            controller.leaveSeekMode()
            expect(controller.seekMode).to(beTrue())
            expect(self.gotDidLeaveSeekMode).to(beFalse())
            controller.leaveSeekMode()
            expect(controller.seekMode).to(beFalse())
            expect(self.gotDidLeaveSeekMode).to(beTrue())

            // already out of seekMode
            self.gotDidLeaveSeekMode = false
            controller.leaveSeekMode()
            expect(controller.seekMode).to(beFalse())
            expect(self.gotDidLeaveSeekMode).to(beFalse())

            controller.enterSeekMode()
            expect(controller.seekMode).to(beTrue())

            done()
          }
        }
      }
    }

    describe("clear") {
      it("clear states") {
        self.resetEventStatus()

        waitUntil { done in
          self.createController() { controller in
            controller.enterSeekMode()
            controller.updateTime(1, excludeNotify: self)
            controller.clear()
            expect(controller.currentTime) == 0
            expect(controller.seekMode).to(beFalse())
            done()
          }
        }
      }
    }
  }
}

extension RDMWaveformControllerSpecs {
  func createController(callback: @escaping (_ controller: RDMWaveformController) -> Void) {
    guard let url = Bundle.main.url(forResource: "file_example_MP3_700KB", withExtension: "mp3") else {
      fail("Failed to find resource: file_example_MP3_700KB.mp3")
      return
    }

    let controller = RDMWaveformController()
    controller.subscribe(self)
    controller.load(url) { error in
      expect(error).to(beNil())
      callback(controller)
    }
  }
}

extension RDMWaveformControllerSpecs: RDMWaveformControllerDelegate {
  public func waveformControllerWillLoadAudio(_ controller: RDMWaveformController) {
    debugPrint("gotWillLoadAudio = true")
    gotWillLoadAudio = true
  }
  public func waveformControllerDidLoadAudio(_ controller: RDMWaveformController) {
    debugPrint("gotDidLoadAudio = true")
    gotDidLoadAudio = true
  }
  public func waveformController(_ controller: RDMWaveformController, didUpdateTime time: TimeInterval, seekMode: Bool) {
    gotDidUpdateTime = true
  }
  public func waveformControllerDidReset(_ controller: RDMWaveformController) {
    gotDidReset = true
  }
  public func waveformControllerDidEnterSeekMode(_ controller: RDMWaveformController) {
    gotDidEnterSeekMode = true
  }
  public func waveformControllerDidLeaveSeekMode(_ controller: RDMWaveformController) {
    gotDidLeaveSeekMode = true
  }
}

fileprivate class AnotherObserver: NSObject, RDMWaveformControllerDelegate {
  var gotDidUpdateTime = false

  public func waveformController(_ controller: RDMWaveformController, didUpdateTime time: TimeInterval, seekMode: Bool) {
    gotDidUpdateTime = true
  }
}
