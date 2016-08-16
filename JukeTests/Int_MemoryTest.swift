//
//  JukeTests.swift
//  JukeTests
//
//  Created by Jeffery Trespalacios on 8/13/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import XCTest
@testable import Juke

class Int_MemoryTest: XCTestCase {

  func testMegaBytes() {
    XCTAssertEqual(1.MB, 1_048_576)
    XCTAssertEqual(9.MB, 9_437_184)
  }

  func testKiloBytes() {
    XCTAssertEqual(1.KB, 1024)
    XCTAssertEqual(9.KB, 9216)
  }
}
