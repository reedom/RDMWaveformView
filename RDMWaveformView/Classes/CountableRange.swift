//
//  CountableRange.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/04/22.
//

import Foundation

extension CountableRange where Bound: Strideable {

  // Extend each bound away from midpoint by `factor`, a portion of the distance from begin to end
  func extended(byFactor factor: Double) -> CountableRange<Bound> {
    let theCount: Int = numericCast(count)
    let amountToMove: Bound.Stride = numericCast(Int(Double(theCount) * factor))
    return lowerBound.advanced(by: -amountToMove) ..< upperBound.advanced(by: amountToMove)
  }
}
