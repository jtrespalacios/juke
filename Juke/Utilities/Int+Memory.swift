//
//  Int+Memory.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/15/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import Foundation

public extension Int {
  public var MB: Int {
    return self * 1024 * 1024
  }
  public var KB: Int {
    return self * 1024
  }
}
