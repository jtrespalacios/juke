//
//  Image.swift
//  
//
//  Created by Jeffery Trespalacios on 8/15/16.
//
//

import Foundation
import CoreData

@objc(Image)
public class Image: NSManagedObject {
  static let entityName = "Image"
// Insert code here to add functionality to your managed object subclass
  convenience init?(insertIntoManagedObjectContext context: NSManagedObjectContext, fromSpotifyAlbum image: SpotifyImage) {
    guard let ed = Image.entityDescription(inManagedContext: context) else {
      return nil
    }
    self.init(entity: ed, insertIntoManagedObjectContext: context)
    self.url = image.url
    self.width = NSNumber(int: image.width)
    self.height = NSNumber(int: image.height)
  }

  public class func entityDescription(inManagedContext context: NSManagedObjectContext) -> NSEntityDescription? {
    return NSEntityDescription.entityForName(Image.entityName, inManagedObjectContext: context)
  }
}
