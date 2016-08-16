//
//  Image+CoreDataProperties.swift
//  
//
//  Created by Jeffery Trespalacios on 8/15/16.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Image {

    @NSManaged var url: String?
    @NSManaged var height: NSNumber?
    @NSManaged var width: NSNumber?
    @NSManaged var album: Album?

}
