//
//  JSONFixture.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/16/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import Foundation
import SwiftyJSON

class JSONLoader {
  static func data(withName name: String) -> NSData? {
    guard let filePath = fixturePath(forName: name) else {
      return nil
    }
    return NSData(contentsOfFile: filePath)
  }

  static func jsonObject(withName name: String) -> JSON? {
    guard let data = data(withName: name) else {
      return nil
    }
    return JSON(data: data)
  }

  private static func fixturePath(forName name: String) -> String? {
    let testBundle = NSBundle(forClass: JSONLoader.self)
    return testBundle.pathForResource(name, ofType: "json")
  }
}
