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

public struct Album {
  let id: String
  let name: String
  let detailPage: String
  let images: [SpotifyImage]
}

extension Album: JSONParsable {
  public init?(json: JSON) {
    guard let id = json["id"].string else {
      return nil
    }
    guard let name = json["name"].string else {
      return nil
    }
    guard let detailPage = json["href"].string else {
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
    self.id = id
    self.name = name
    self.detailPage = detailPage
    self.images = images
  }
}

extension Album {
  func imageNearestTo(width: Int) -> SpotifyImage? {
    guard images.count > 0 else {
      return nil
    }
    let actualWidth = width * Int(UIScreen.mainScreen().nativeScale)
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
  let height: Int
  let width: Int
}

extension SpotifyImage: JSONParsable {
  public init?(json: JSON) {
    guard let url = json["url"].string, height = json["height"].int, width = json["width"].int else {
      return nil
    }
    self.url = url
    self.height = height
    self.width = width
  }
}

public struct SearchPayload {
  let albums: [Album]
}

extension SearchPayload: JSONParsable {
  public init?(json: JSON) {
    var results = [Album]()
    if let albums = json["albums"]["items"].array {
      albums.forEach {
        if let album = Album(json: $0) {
          results.append(album)
        }
      }
    }
    self.albums = results
  }
}