//
//  Album.swift
//  
//
//  Created by Jeffery Trespalacios on 8/15/16.
//
//

import Foundation
import CoreData

@objc(Album)
public class Album: NSManagedObject {
  static let entityName = "Album"
  convenience init?(insertIntoManagedObjectContext context: NSManagedObjectContext, fromSpotifyAlbum album: SpotifyAlbum) {
    guard let entityDescription = Album.entityDescription(context) else {
      return nil
    }
    self.init(entity: entityDescription, insertIntoManagedObjectContext: context)
    self.spotifyId = album.spotifyId
    self.name = album.name
    var images = Set<Image>()
    for image in album.images {
      if let i = Image(insertIntoManagedObjectContext: context, fromSpotifyAlbum: image) {
        images.insert(i)
      }
    }
    self.images = images
  }

  public class func deleteItem(withId id: String, onContext context: NSManagedObjectContext) {
    let predicate = NSPredicate(format: "spotifyId == %@", id)
    let request = NSFetchRequest(entityName: Album.entityName)
    request.includesSubentities = false
    request.predicate = predicate
    guard let results = try? context.executeFetchRequest(request),
      let albums = results as? [Album] where albums.count > 0 else {
      return
    }
    albums.forEach { context.deleteObject($0) }
  }

  public class func filterForFavorites(albums: [SpotifyAlbum], onContext context: NSManagedObjectContext) throws -> [String] {
    guard albums.count > 0 else {
      return []
    }
    let albumIds = albums.map { $0.spotifyId }
    let predicateTemplate = NSPredicate(format: "spotifyId in $ALBUM_IDS", argumentArray: nil)
    let request = NSFetchRequest(entityName: Album.entityName)
    request.includesSubentities = false
    request.resultType = .DictionaryResultType
    request.propertiesToFetch = ["spotifyId"]
    request.returnsDistinctResults = true
    request.predicate = predicateTemplate.predicateWithSubstitutionVariables(["ALBUM_IDS": albumIds])
    guard let results = try context.executeFetchRequest(request) as? [[String: String]]   else {
      return []
    }
    return results.map { $0["spotifyId"]! }
  }

  private class func entityDescription(context: NSManagedObjectContext) -> NSEntityDescription? {
    return NSEntityDescription.entityForName(Album.entityName, inManagedObjectContext: context)
  }
}
