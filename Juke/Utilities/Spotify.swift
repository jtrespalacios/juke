//
//  Spotify.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/13/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import Foundation
import SwiftyJSON

public enum Spotify {
  private static let session: NSURLSession = {
    let config = NSURLSessionConfiguration.defaultSessionConfiguration()
    config.timeoutIntervalForRequest = 5
    return NSURLSession(configuration: config)
  }()
  public enum Error {
    case invalidSearch(String)
    case networkFailure
    case networkUnavailable
  }

  private static let rootUrl = "https://api.spotify.com/v1/search"

  public static func searchAlbum(withTitle title: String, resultHandler: (SearchPayload?, Error?) -> ()) -> HTTP {
    let queryParams: [String: String] = [
      "type": "album",
      "limit": "15",
      "q": "album:" + title
    ]
    let http = HTTP.get(Spotify.rootUrl, params: queryParams)
      .withSession(Spotify.session)
      .onError { (error: HTTP.Error) in
        #if DEBUG
          print("Spotify Search Request failed with error: \(error)")
        #endif
        let finalError: Error
        switch error {
        case .badRequest, .clientError(_):
          finalError = .invalidSearch(title)
        case .networkUnavailable:
          finalError = .networkUnavailable
        default:
          finalError = .networkFailure
        }
        HTTP.queueBlock { resultHandler(nil, finalError) }
      }
      .onResult { (payload: SearchPayload) in
        HTTP.queueBlock { resultHandler(payload, nil) }
      }
      .execute()
    return http
  }
}

public struct SpotifyAlbum: Hashable, Equatable {
  let spotifyId: String
  let name: String
  let images: [SpotifyImage]

  public var hashValue: Int {
    return 0
  }
}

public func ==(lhs: SpotifyAlbum, rhs: SpotifyAlbum) -> Bool {
  return lhs.spotifyId == rhs.spotifyId
}

extension SpotifyAlbum: JSONParsable {
  public init?(json: JSON) {
    guard let id = json["id"].string else {
      return nil
    }
    guard let name = json["name"].string else {
      return nil
    }
    var images = [SpotifyImage]()
    if let jsonImages = json["images"].array {
      jsonImages.forEach {
        if let image = SpotifyImage(json: $0) {
          images.append(image)
        }
      }
    }
    self.spotifyId = id
    self.name = name
    self.images = images
  }
}


extension SpotifyAlbum {
  func imageNearestTo(width: Int32) -> SpotifyImage? {
    guard images.count > 0 else {
      return nil
    }
    let actualWidth = width * Int32(UIScreen.mainScreen().nativeScale)
    var smallestDelta = -1
    var indexOfSmallest = 0
    _ = (images.map { abs(actualWidth - $0.width) }).enumerate().forEach { (index: Int, value: Int) in
      guard index != 0 else {
        smallestDelta = value
        return
      }
      if value < smallestDelta {
        smallestDelta = value
        indexOfSmallest = index
      }

    }
    return images[indexOfSmallest]
  }
}

public struct SpotifyImage {
  let url: String
  let height: Int32
  let width: Int32
}

extension SpotifyImage: JSONParsable {
  public init?(json: JSON) {
    guard let url = json["url"].string, height = json["height"].int32, width = json["width"].int32 else {
      return nil
    }
    self.url = url
    self.height = height
    self.width = width
  }
}

public struct SearchPayload {
  let albums: [SpotifyAlbum]
}

extension SearchPayload: JSONParsable {
  public init?(json: JSON) {
    var results = [SpotifyAlbum]()
    guard let albums = json["albums"]["items"].array else {
      return nil
    }
    albums.forEach {
      if let album = SpotifyAlbum(json: $0) {
        results.append(album)
      }
    }
    self.albums = results
  }
}