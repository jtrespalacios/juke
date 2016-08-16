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
  func isFavorite(album: Album) -> Bool
  func addFavorite(album: Album)
  func removeFavorite(album: Album)
  func save()
  func load()
}

class FavoriteAlbumRepo: FavoriteRepo {
  let context: NSManagedObjectContext!
  var favorites = Set<Album>()

  init(context: NSManagedObjectContext) {
    self.context = context
  }
  func isFavorite(album: Album) -> Bool {
    return self.favorites.contains(album)
  }

  func addFavorite(album: Album) {
    self.favorites.insert(album)
  }

  func removeFavorite(album: Album) {
    self.favorites.remove(album)
  }

  func save() {

  }

  func load() {
    
  }
}