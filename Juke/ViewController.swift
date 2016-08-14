//
//  ViewController.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/13/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  @IBOutlet weak var searchButton: UIButton!
  @IBOutlet weak var queryInput: UITextField!
  @IBOutlet weak var collectionView: UICollectionView!
  private let dataSource: ArrayDataSource = {
    return ArrayDataSource(reuseKey: "AlbumCell") { (cell: AlbumCell, album: Album) in
      cell.label.text = album.name
      guard let image = album.images.first else {
        return
      }
      cell.imageLoadRequest = HTTP.get(image.url)
        .then { (data: NSData?, response: NSHTTPURLResponse) in
          guard let data = data else {
            return
          }
          guard let image = UIImage(data: data) else {
            return
          }
          dispatch_async(dispatch_get_main_queue()) {
            cell.imageView.image = image
          }
        }
        .onError { (error: ErrorType) in
          print("Error (\(error)) loading image from url \(image.url)")
        }
        .execute()
    }
  }()
  private weak var searchRequest: HTTP?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.queryInput.text = nil
    self.searchButton.enabled = false
    self.searchButton.addTarget(self,
                                action: #selector(executeSearch),
                                forControlEvents: .TouchUpInside)
    let queryFieldBlock = { (note: NSNotification) in
      self.searchButton.enabled = self.queryInput.text?.characters.count > 0
    }
    NSNotificationCenter.defaultCenter()
      .addObserverForName(UITextFieldTextDidChangeNotification,
                          object: self.queryInput,
                          queue: nil,
                          usingBlock: queryFieldBlock)
    self.collectionView.dataSource = self.dataSource
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  @objc func executeSearch() {
    guard let searchTerm = self.queryInput.text where self.searchRequest == nil else {
      return
    }
    self.queryInput.text = nil
    self.queryInput.resignFirstResponder()
    
    self.searchRequest = Spotify.searchAlbum(withTitle: searchTerm)
      .then { (searchResult: SearchPayload) in
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
          self?.updateResults(searchResult.albums)
        }
      }
      .onError { (error: ErrorType) in
        print("Error fetching albums: \(error)")
      }
      .execute()
  }
  
  private func updateResults(albums: [Album]) {
    self.collectionView.performBatchUpdates({
      let sectionZero = NSIndexSet(index: 0)
      self.dataSource.items = albums
      self.collectionView.deleteSections(sectionZero)
      self.collectionView.insertSections(sectionZero)
    }, completion: nil)
  }
}

public class AlbumCell: UICollectionViewCell {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var label: UILabel!
  public weak var imageLoadRequest: HTTP?
  
  public override func prepareForReuse() {
    self.imageView.image = nil
    self.label.text = nil
    self.imageLoadRequest?.cancel()
  }
}

class ArrayDataSource<T: UICollectionViewCell, U>: NSObject, UICollectionViewDataSource {
  typealias CellFormatter = (T, U) -> ()
  var items = [U]()
  let format: CellFormatter
  let reuseKey: String
  
  init(reuseKey: String, formatter: CellFormatter) {
    self.reuseKey = reuseKey
    self.format = formatter
  }
  
  func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    let item = self.items[indexPath.item]
    guard let cell = collectionView.dequeueReusableCellWithReuseIdentifier(self.reuseKey, forIndexPath: indexPath) as? T else {
      fatalError("Could not downcast to correct type")
    }
    self.format(cell, item)
    return cell
  }
  
  func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
    return 1
  }
  
  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return items.count
  }
}

