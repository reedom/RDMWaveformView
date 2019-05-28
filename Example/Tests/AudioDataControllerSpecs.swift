// https://github.com/Quick/Quick

import Quick
import Nimble
@testable import RDMWaveformView

class AudioDataControllerSpecs: AudioSpecsBase {
  override func spec() {
    describe("audioContext") {
      it("fires events when it gets or resets audioContext") {
        let controller = AudioDataController()
        let handler = Handler()
        controller.subscribe(handler)

        waitUntil { done in
          AudioContext.load(fromAudioURL: self.validURL) { result in
            switch result {
            case .success(let audioContext):
              controller.audioContext = audioContext
              expect(controller.hasAudio).to(beTrue())
              expect(handler.gotAudioContext).to(beTrue())
              expect(handler.gotDidReset).to(beFalse())

              // set same instance
              handler.gotAudioContext = false
              controller.audioContext = audioContext
              expect(handler.gotAudioContext).to(beTrue())
              expect(handler.gotDidReset).to(beFalse())

              // reset
              handler.gotAudioContext = false
              controller.audioContext = nil
              expect(handler.gotAudioContext).to(beFalse())
              expect(handler.gotDidReset).to(beTrue())

              done()
            case .failure(let error):
              fail(error.message)
            }
          }
        }
      }
    }

    describe("currentTime") {
      it("ignores to be updated if there is no audio") {
        let controller = AudioDataController()
        let handler = Handler()
        controller.subscribe(handler)
        controller.time.currentTime = 1
        expect(controller.time.currentTime) == 0
        expect(handler.gotDidUpdateTime).to(beFalse())
      }

      it("tells updates") {
        waitUntil { done in
          self.createController() { controller in
            let handler = Handler()
            controller.subscribe(handler)
            expect(handler.gotDidUpdateTime).to(beFalse())
            expect(controller.time.currentTime) == 0
            controller.time.currentTime = 1
            expect(handler.gotDidUpdateTime).to(beTrue())
            done()
          }
        }
      }

      it("tells updates even there is no change") {
        waitUntil { done in
          self.createController() { controller in
            let handler = Handler()
            controller.subscribe(handler)
            controller.time.currentTime = 0
            expect(handler.gotDidUpdateTime).to(beTrue())
            done()
          }
        }
      }
    }

    describe("update") {
      it("skips notification to the caller") {
        waitUntil { done in
          self.createController() { controller in
            let handler = Handler()
            controller.subscribe(handler)
            let another = Handler()
            controller.subscribe(another)
            controller.time.update(1, excludeNotify: handler)
            expect(handler.gotDidUpdateTime).to(beFalse())
            expect(another.gotDidUpdateTime).to(beTrue())
            done()
          }
        }
      }
    }

    describe("seekMode") {
      it("ignores entring to the mode if there is no audio") {
        let controller = AudioDataController()
        controller.time.enterSeekMode()
        expect(controller.time.seeking).to(beFalse())
      }

      it("counts the number of entring and leaving") {
        waitUntil { done in
          self.createController() { controller in
            let handler = Handler()
            controller.subscribe(handler)
            controller.time.enterSeekMode()
            expect(controller.time.seeking).to(beTrue())
            expect(handler.gotDidEnterSeekMode).to(beTrue())
            expect(handler.gotDidLeaveSeekMode).to(beFalse())

            handler.gotDidEnterSeekMode = false
            controller.time.enterSeekMode()
            expect(controller.time.seeking).to(beTrue())
            expect(handler.gotDidEnterSeekMode).to(beFalse())

            controller.time.leaveSeekMode()
            expect(controller.time.seeking).to(beTrue())
            expect(handler.gotDidLeaveSeekMode).to(beFalse())
            controller.time.leaveSeekMode()
            expect(controller.time.seeking).to(beFalse())
            expect(handler.gotDidLeaveSeekMode).to(beTrue())

            // already out of seekMode
            handler.gotDidLeaveSeekMode = false
            controller.time.leaveSeekMode()
            expect(controller.time.seeking).to(beFalse())
            expect(handler.gotDidLeaveSeekMode).to(beFalse())

            controller.time.enterSeekMode()
            expect(controller.time.seeking).to(beTrue())

            done()
          }
        }
      }
    }
  }

  class Handler: NSObject, AudioDataControllerDelegate {
    var gotAudioContext = false
    var gotDidUpdateTime = false
    var gotDidReset = false
    var gotDidEnterSeekMode = false
    var gotDidLeaveSeekMode = false

    public func audioDataControllerDidSetAudioContext(_ controller: AudioDataController) {
      gotAudioContext = true
    }
    public func audioDataController(_ controller: AudioDataController, didUpdateTime time: TimeInterval, seekMode: Bool) {
      gotDidUpdateTime = true
    }
    public func audioDataControllerDidReset(_ controller: AudioDataController) {
      gotDidReset = true
    }
    public func audioDataControllerDidEnterSeekMode(_ controller: AudioDataController) {
      gotDidEnterSeekMode = true
    }
    public func audioDataControllerDidLeaveSeekMode(_ controller: AudioDataController) {
      gotDidLeaveSeekMode = true
    }
  }
}
