//
//  WeakRef.swift
//  FBSnapshotTestCase
//
//  Created by HANAI Tohru on 2019/05/01.
//

// Equatable, Hashable
class WeakDelegateRef<T>: Hashable where T: NSObjectProtocol {
  private(set) weak var value: T?

  init(value: T) {
    self.value = value
  }

  static func == (lhs: WeakDelegateRef<T>, rhs: WeakDelegateRef<T>) -> Bool {
    if let lval = lhs.value {
      if let rval = rhs.value {
        return lval.hash == rval.hash
      } else {
        return false
      }
    } else {
      return rhs.value == nil
    }
  }

  static func == (lhs: WeakDelegateRef, rhs: T) -> Bool {
    if let lval = lhs.value {
      return lval.hash == rhs.hash
    } else {
      return false
    }
  }

  func hash(into hasher: inout Hasher) {
    if let val = value {
      hasher.combine(val.hash)
    } else {
      hasher.combine(0)
    }
  }
}
