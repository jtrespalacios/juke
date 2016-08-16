//
//  FavoriteRepo.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/15/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import Foundation
import CoreData

protocol FavoriteRepo {
  func isFavorite(album: SpotifyAlbum) -> Bool
  func addFavorite(album: SpotifyAlbum)
  func removeFavorite(album: SpotifyAlbum)
  func save()
  func checkForExistingFavorites(albums: [SpotifyAlbum])
}

class FavoriteAlbumRepo: FavoriteRepo {
  let context: NSManagedObjectContext!
  var favorites = Set<String>()

  init(context: NSManagedObjectContext) {
    self.context = context
  }

  func isFavorite(album: SpotifyAlbum) -> Bool {
    return self.favorites.contains(album.spotifyId)
  }

  func addFavorite(album: SpotifyAlbum) {
    self.favorites.insert(album.spotifyId)
    _ = Album(insertIntoManagedObjectContext: context, fromSpotifyAlbum: album)
  }

  func removeFavorite(album: SpotifyAlbum) {
    Album.deleteItem(withId: album.spotifyId, onContext: context)
    self.favorites.remove(album.spotifyId)
  }

  func save() {
    guard self.context.hasChanges else {
      return
    }
    do {
      try self.context.save()
    } catch {
      fatalError("Error attempting to save context in favorite repo: \(error)")
    }
  }

  func checkForExistingFavorites(albums: [SpotifyAlbum]) {
    guard let favoritedIds = try? Album.filterForFavorites(albums, onContext: context) else {
      return
    }
    self.favorites.removeAll()
    favoritedIds.forEach { self.favorites.insert($0) }
  }
}