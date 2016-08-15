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
      cell.albumArtView.loadImage(image.url)
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
    
    self.searchRequest = Spotify.searchAlbum(withTitle: searchTerm) { (searchResults: SearchPayload?, error: Spotify.Error?) in
      guard error == nil else {
        let e = error!
        dispatchMain { [weak self] in
          self?.alertWithError(e)
        }
        return
      }
      guard let searchResults = searchResults else {
        return
      }
      dispatchMain { [weak self] in
        self?.updateResults(searchResults.albums)
      }
    }
  }
  
  private func alertWithError(error: Spotify.Error) {
    let message: String
    switch error {
    case .invalidSearch:
      message = "I couldn't figure out what you were looking for, please try again."
    case .networkFailure:
      message = "I experienced a network error, please try again later."
    case .networkUnavailable:
      message = "I've lost my connection to the network, can you check it out?"
    }
    
    let alert = UIAlertController(title: "Ooops...", message: message, preferredStyle: .Alert)
    let ok = UIAlertAction(title: "OK", style: .Default) { _ in
      if error == .invalidSearch {
        self.queryInput.becomeFirstResponder()
      }
    }
    alert.addAction(ok)
  }
  
  private func updateResults(albums: [Album]) {
    self.collectionView.performBatchUpdates({ [unowned self] in
      let sectionZero = NSIndexSet(index: 0)
      self.dataSource.items = albums
      self.collectionView.deleteSections(sectionZero)
      self.collectionView.setContentOffset(.zero, animated: false)
      self.collectionView.insertSections(sectionZero)
      }, completion: nil)
  }
}

public class AlbumCell: UICollectionViewCell {
  @IBOutlet public weak var albumArtView: RemoteImageView!
  @IBOutlet public weak var label: UILabel!
  
  public override func prepareForReuse() {
    self.albumArtView.image = nil
    self.label.text = nil
    self.albumArtView.cancelLoading()
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


public func dispatchMain(block: () -> ()) {
  dispatch_async(dispatch_get_main_queue(), block)
}



