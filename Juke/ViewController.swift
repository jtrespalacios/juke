//
//  ViewController.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/13/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import UIKit
import SafariServices

@objc protocol AlbumActions {
  func toggleFavorite()
}

@objc class ViewController: UIViewController {
  // Internal Tooling
  private weak var searchButton: UIButton!
  private weak var queryInput: UITextField!
  private weak var collectionView: UICollectionView!
  private var selectedIndexPath: NSIndexPath?
  private weak var searchRequest: HTTP?

  private let dataSource: ArrayDataSource<AlbumCell, Album>
  private let favoriteRepo: FavoriteRepo

  init(repo: FavoriteRepo, dataSource: ArrayDataSource<AlbumCell, Album>) {
    self.favoriteRepo = repo
    self.dataSource = dataSource
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let view = UIView()
    let queryInput = UITextField()
    let searchButton = UIButton(type: .System)
    let layout = UICollectionViewFlowLayout()
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    searchButton.setTitle("Search", forState: .Normal)
    layout.itemSize = CGSize(width: 200, height: 230)
    layout.minimumLineSpacing = 10
    layout.minimumInteritemSpacing = 10
    collectionView.collectionViewLayout = layout
    [queryInput, searchButton, collectionView].forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview($0)
    }
    view.backgroundColor = UIColor.whiteColor()
    collectionView.backgroundColor = UIColor.whiteColor()
    queryInput.borderStyle = .RoundedRect
    queryInput.placeholder = "Album Title"
    self.view = view
    self.queryInput = queryInput
    self.searchButton = searchButton
    self.collectionView = collectionView
  }

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
    let favoriteMenuItem = UIMenuItem(title: "Favorite", action: #selector(AlbumActions.toggleFavorite))
    let unfavoriteMenuItem = UIMenuItem(title: "Unfavorite", action: #selector(AlbumActions.toggleFavorite))
    UIMenuController.sharedMenuController().menuItems = [favoriteMenuItem, unfavoriteMenuItem]
    self.collectionView.registerClass(AlbumCell.self, forCellWithReuseIdentifier: AlbumCell.reuseIdentifier)
    self.collectionView.dataSource = self.dataSource
    self.collectionView.delegate = self

    let viewBindings = [
      "qi": self.queryInput,
      "sb": self.searchButton,
      "cv": self.collectionView,
      "tlg": self.topLayoutGuide as AnyObject
    ]
    view.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("H:|-[qi]-[sb]-|", options: [.AlignAllCenterY], metrics: nil, views: viewBindings)
    )
    view.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("H:|-[cv]-|", options: [.AlignAllCenterY], metrics: nil, views: viewBindings)
    )
    view.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("V:|->=0-[tlg]-[qi]-[cv]-|", options: [], metrics: nil, views: viewBindings)
    )
  }

  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    self.queryInput.text = "Hello Nasty"
    self.executeSearch()
  }

  override func canBecomeFirstResponder() -> Bool {
    return true
  }

  override func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
    guard let selectedIndexPath = self.selectedIndexPath, album = self.dataSource.item(atIndexPath: selectedIndexPath) else {
      return super.canPerformAction(action, withSender: sender)
    }
    switch action {
    case #selector(AlbumActions.toggleFavorite):
      return !favoriteRepo.isFavorite(album)
    case #selector(AlbumActions.toggleFavorite):
      return favoriteRepo.isFavorite(album)
    default:
      return super.canPerformAction(action, withSender: sender)
    }
  }

  @objc func executeSearch() {
    guard let searchTerm = self.queryInput.text where self.searchRequest == nil else {
      return
    }
    self.queryInput.text = nil
    self.queryInput.resignFirstResponder()
    self.searchButton.enabled = false
    let activityIndicatorTag = 957
    weak var activityIndicator: UIActivityIndicatorView?

    if let oldActivityIndicator = self.view.viewWithTag(activityIndicatorTag) as? UIActivityIndicatorView {
      activityIndicator = oldActivityIndicator
    } else {
      let ai = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
      ai.hidesWhenStopped = true
      ai.stopAnimating()
      self.view.addSubview(ai)
      ai.center = self.view.center
      UIView.transitionWithView(ai,
                                duration: 0.2,
                                options: [.CurveEaseOut, .TransitionCrossDissolve],
                                animations: { ai.startAnimating() },
                                completion: nil)
      activityIndicator = ai
    }

    self.searchRequest = Spotify.searchAlbum(withTitle: searchTerm) { (searchResults: SearchPayload?, error: Spotify.Error?) in
      defer {
        dispatchMain {
          if let strongActivityIndicator = activityIndicator {
            UIView.transitionWithView(strongActivityIndicator,
                                      duration: 0.2,
                                      options: [.CurveEaseOut, .TransitionCrossDissolve],
                                      animations: { strongActivityIndicator.removeFromSuperview() },
                                      completion: nil)
          }
        }
      }
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
      switch error {
      case .invalidSearch(_):
        self.queryInput.becomeFirstResponder()
      default:
        break;
      }
    }
    alert.addAction(ok)
    self.presentViewController(alert, animated: true, completion: nil)
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

extension ViewController: UICollectionViewDelegate {
  func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
    guard let cellFrame = collectionView.layoutAttributesForItemAtIndexPath(indexPath)?.frame else {
      return
    }
    self.selectedIndexPath = indexPath
    let controller = UIMenuController.sharedMenuController()
    let cellFrameInView = self.view.convertRect(cellFrame, fromView: collectionView)
    controller.setTargetRect(cellFrameInView, inView: self.view)
    controller.setMenuVisible(true, animated: true)
  }

  func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
    self.selectedIndexPath = nil
    let controller = UIMenuController.sharedMenuController()
    if controller.menuVisible {
      controller.setMenuVisible(false, animated: true)
    }
  }
}

extension ViewController: AlbumActions {
  func toggleFavorite() {
    guard let selectedIndexPath = self.selectedIndexPath,
      let album = self.dataSource.item(atIndexPath: selectedIndexPath) else {
        return
    }
    if self.favoriteRepo.isFavorite(album) {
      self.favoriteRepo.removeFavorite(album)
    }
    else {
      self.favoriteRepo.addFavorite(album)
    }
    self.dataSource.items[selectedIndexPath.item] = album
    self.reloadSelectedItem()
  }

  func reloadSelectedItem() {
    guard let selectedIndexPath = self.selectedIndexPath else {
      return
    }
    self.collectionView.reloadItemsAtIndexPaths([selectedIndexPath])
  }
}
