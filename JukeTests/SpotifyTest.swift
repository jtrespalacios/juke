//
//  SpotifyAlbumTest.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/16/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import XCTest
@testable import Juke
import SwiftyJSON

class SpotifyTest: XCTestCase {
  let searchPayload = JSONLoader.jsonObject(withName: "TestAlbums")

  func testImageParsing() {
    guard let jsonAlbum = searchPayload?["albums"]["items"].array?.first else {
      XCTFail("Could not get album from test payload")
      return
    }
    guard let image = jsonAlbum["images"].array?.first else {
      XCTFail("Could not get image from test payload")
      return
    }

    let testImage = SpotifyImage(json: image)
    XCTAssertNotNil(testImage, "Test Image should not be nil")
    XCTAssertNotNil(testImage, "Test Image should not be nil")
    XCTAssertEqual(testImage!.url, "https://i.scdn.co/image/191a71b149c951e18592a6bd0f9ccfe760a35749", "Test image did not get the correct url")
    XCTAssertEqual(testImage!.height, 640, "Test image did not get the correct height")
    XCTAssertEqual(testImage!.width, 640, "Test Image did not get the correct width")
  }

  func testImageParsingBadData() {
    let invalidJson = JSON(dictionaryLiteral: ("url", 1234), ("width", "help"))
    let invalidImage = SpotifyImage(json: invalidJson)
    XCTAssertNil(invalidImage, "Invalid image json should not result in a spotify image being created")
  }

  func testAlbumParsing() {
    guard let jsonAlbum = searchPayload?["albums"]["items"].array?.first else {
      XCTFail("Could not get album from test payload")
      return
    }

    let testAlbum = SpotifyAlbum(json: jsonAlbum)
    XCTAssertNotNil(testAlbum, "Test album should not be nil")
    XCTAssertEqual(testAlbum!.name, "Reality Testing", "Test album did not get the correct name")
    XCTAssertEqual(testAlbum!.spotifyId, "4BqbonMPCLJIZ9Txo866l9", "Test album did not get the corret spotify ID")
    XCTAssertEqual(testAlbum!.images.count, 3, "Test album should have three images")
  }

  func testAlbumParsingBadData() {
    let invalidJson = JSON(dictionaryLiteral: ("url", 1234), ("width", "help"))
    let invalidAlbum = SpotifyAlbum(json: invalidJson)
    XCTAssertNil(invalidAlbum, "Invalid album json should not result in a spotify album being created")
  }

  func testSearchPayloadParsing() {
    guard let searchPayload = searchPayload else {
      XCTFail("Could not get search payload")
      return
    }

    let testPayload = SearchPayload(json: searchPayload)
    XCTAssertNotNil(testPayload, "Test payload should not be nil")
    XCTAssertEqual(testPayload!.albums.count, 1, "Test payload should contain one ablum")
  }

  func testSearchPayloadParsingBadData() {
    let invalidJSON = JSON(dictionaryLiteral: ("", ""), ("woo", 100))
    let invalidPayload = SearchPayload(json: invalidJSON)
    XCTAssertNil(invalidPayload, "Invalid search json should not result in a search payload being created")
  }
}
