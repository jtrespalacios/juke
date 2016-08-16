//
//  ArrayDataSource.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/15/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import UIKit

public class ArrayDataSource<T: UICollectionViewCell, U>: NSObject, UICollectionViewDataSource {
  public typealias CellFormatter = (T, U) -> ()
  var items = [U]()
  let format: CellFormatter
  let reuseKey: String

  public init(reuseKey: String, formatter: CellFormatter) {
    self.reuseKey = reuseKey
    self.format = formatter
  }

  public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    let item = self.items[indexPath.item]
    guard let cell = collectionView.dequeueReusableCellWithReuseIdentifier(self.reuseKey, forIndexPath: indexPath) as? T else {
      fatalError("Could not downcast collection view cell to correct type")
    }
    self.format(cell, item)
    return cell
  }

  public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
    return 1
  }

  public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return items.count
  }

  public func item(atIndexPath indexPath: NSIndexPath) -> U? {
    return items[indexPath.item]
  }
}
