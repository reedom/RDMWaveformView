//
//  String+sha256.swift
//  music player
//
//  Created by HANAI Tohru on 2019/05/15.
//  Copyright © 2019 reedom. All rights reserved.
//

import Foundation

extension String {
  func sha256() -> String {
    if let stringData = self.data(using: String.Encoding.utf8) {
      return hexStringFromData(input: digest(input: stringData as NSData))
    }
    return ""
  }

  private func digest(input : NSData) -> NSData {
    let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
    var hash = [UInt8](repeating: 0, count: digestLength)
    CC_SHA256(input.bytes, UInt32(input.length), &hash)
    return NSData(bytes: hash, length: digestLength)
  }

  private  func hexStringFromData(input: NSData) -> String {
    var bytes = [UInt8](repeating: 0, count: input.length)
    input.getBytes(&bytes, length: input.length)

    var hexString = ""
    for byte in bytes {
      hexString += String(format:"%02x", UInt8(byte))
    }

    return hexString
  }
}
