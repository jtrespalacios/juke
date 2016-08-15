//
//  Methods.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/15/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import Foundation

public func dispatchMain(block: () -> ()) {
  dispatch_async(dispatch_get_main_queue(), block)
}
