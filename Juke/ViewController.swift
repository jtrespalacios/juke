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
  func favorite()
  func unFavorite()
}

@objc class ViewController: UIViewController {
  // Internal Tooling
  private weak var searchButton: UIButton!
  private weak var queryInput: UITextField!
  private weak var collectionView: UICollectionView!
  private weak var noContentLabel: UILabel!
  private var selectedIndexPath: NSIndexPath?
  private weak var searchRequest: HTTP?

  private let dataSource: ArrayDataSource<AlbumCell, SpotifyAlbum>
  private let favoriteRepo: FavoriteRepo

  init(repo: FavoriteRepo, dataSource: ArrayDataSource<AlbumCell, SpotifyAlbum>) {
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
    queryInput.borderStyle = .RoundedRect
    queryInput.placeholder = "Album Title"
    let searchButton = UIButton(type: .System)
    searchButton.setTitle("Search", forState: .Normal)
    let layout = UICollectionViewFlowLayout()
    layout.itemSize = CGSize(width: 360, height: 400)
    layout.minimumLineSpacing = 5
    layout.minimumInteritemSpacing = 5
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.backgroundColor = nil
    collectionView.backgroundView = nil
    collectionView.contentInset = UIEdgeInsetsMake(0, 0, 20, 0)
    let noContentLabel = UILabel(frame: .zero)
    noContentLabel.numberOfLines = 0
    noContentLabel.allowsDefaultTighteningForTruncation = true
    noContentLabel.hidden = true
    [queryInput, searchButton, collectionView, noContentLabel].forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview($0)
    }
    view.backgroundColor = UIColor.whiteColor()
    self.view = view
    self.queryInput = queryInput
    self.searchButton = searchButton
    self.collectionView = collectionView
    self.noContentLabel = noContentLabel
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
    let favoriteMenuItem = UIMenuItem(title: "Favorite", action: #selector(AlbumActions.favorite))
    let unfavoriteMenuItem = UIMenuItem(title: "Unfavorite", action: #selector(AlbumActions.unFavorite))
    UIMenuController.sharedMenuController().menuItems = [favoriteMenuItem, unfavoriteMenuItem]
    self.collectionView.registerClass(AlbumCell.self, forCellWithReuseIdentifier: AlbumCell.reuseIdentifier)
    self.collectionView.dataSource = self.dataSource
    self.collectionView.delegate = self

    let viewBindings = [
      "qi": self.queryInput,
      "sb": self.searchButton,
      "cv": self.collectionView,
      "nl": self.noContentLabel,
      "tlg": self.topLayoutGuide as AnyObject
    ]
    self.view.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("H:|-[qi]-[sb]-|", options: [.AlignAllCenterY], metrics: nil, views: viewBindings)
    )
    self.view.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("H:|-[cv]-|", options: [.AlignAllCenterY], metrics: nil, views: viewBindings)
    )
    self.view.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("V:[tlg]-[qi]-[cv]-|", options: [], metrics: nil, views: viewBindings)
    )
    self.view.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("H:|-(>=8)-[nl]-(>=8)-|", options: [], metrics: nil, views: viewBindings)
    )
    self.noContentLabel.topAnchor.constraintEqualToAnchor(self.queryInput.bottomAnchor, constant: 10).active = true
    self.noContentLabel.centerXAnchor.constraintEqualToAnchor(self.view.centerXAnchor).active = true
    self.noContentLabel.heightAnchor.constraintLessThanOrEqualToConstant(100).active = true
  }

  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    self.queryInput.becomeFirstResponder()
  }

  override func viewDidDisappear(animated: Bool) {
    super.viewDidDisappear(animated)
    self.favoriteRepo.save()
  }

  override func canBecomeFirstResponder() -> Bool {
    return true
  }

  override func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
    guard let selectedIndexPath = self.selectedIndexPath, album = self.dataSource.item(atIndexPath: selectedIndexPath) else {
      return super.canPerformAction(action, withSender: sender)
    }
    switch action {
    case #selector(AlbumActions.favorite):
      return !favoriteRepo.isFavorite(album)
    case #selector(AlbumActions.unFavorite):
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
    weak var activityIndicator: UIView? = getActivityIndicator()
    self.searchRequest = Spotify.searchAlbum(withTitle: searchTerm) { (searchResults: SearchPayload?, error: Spotify.Error?) in
      let update: () -> ()
      guard error == nil else {
        let e = error!
        update = { [weak self] in
          self?.alertWithError(e)
        }
        return
      }
      guard let searchResults = searchResults else {
        return
      }

      update = { [weak self] in
        self?.updateResults(searchResults.albums)
      }

      dispatchMain {
        if let strongActivityIndicator = activityIndicator {
          UIView.transitionWithView(strongActivityIndicator,
            duration: 0.2,
            options: [.CurveEaseOut, .TransitionCrossDissolve],
            animations: { strongActivityIndicator.removeFromSuperview() },
            completion: { _ in update() })
        } else {
          update()
        }
      }
    }
  }

  private func getActivityIndicator() -> UIView {
    let view = UIView(frame: .zero)
    let ai = UIActivityIndicatorView()
    ai.translatesAutoresizingMaskIntoConstraints = false
    view.translatesAutoresizingMaskIntoConstraints = false
    ai.hidesWhenStopped = true
    view.addSubview(ai)
    view.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.5)
    view.layer.cornerRadius = 20
    ai.centerYAnchor.constraintEqualToAnchor(view.centerYAnchor).active = true
    ai.centerXAnchor.constraintEqualToAnchor(view.centerXAnchor).active = true
    ai.widthAnchor.constraintEqualToConstant(80).active = true
    ai.heightAnchor.constraintEqualToAnchor(ai.widthAnchor).active = true
    view.widthAnchor.constraintEqualToAnchor(ai.widthAnchor, constant: 25).active = true
    view.heightAnchor.constraintEqualToAnchor(view.widthAnchor).active = true
    view.hidden = true
    ai.activityIndicatorViewStyle = .WhiteLarge
    self.view.addSubview(view)
    self.view.centerXAnchor.constraintEqualToAnchor(view.centerXAnchor, constant: 0).active = true
    self.view.centerYAnchor.constraintEqualToAnchor(view.centerYAnchor, constant: 0).active = true
    UIView.transitionWithView(view,
                              duration: 0.2,
                              options: [.CurveEaseOut, .TransitionCrossDissolve],
                              animations: {
                                ai.startAnimating()
                                view.hidden = false },
                              completion: nil)
    return view
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

  private func updateResults(albums: [SpotifyAlbum]) {
    self.favoriteRepo.checkForExistingFavorites(albums)
    self.selectedIndexPath = nil

    if albums.count > 0 {
      self.hideNoContentMessage()
    }

    self.collectionView.performBatchUpdates({ [unowned self] in
      let sectionZero = NSIndexSet(index: 0)
      self.dataSource.items = albums
      self.collectionView.deleteSections(sectionZero)
      self.collectionView.setContentOffset(.zero, animated: false)
      self.collectionView.insertSections(sectionZero)
      }, completion: { _ in
        if albums.count == 0 {
          self.showNoContentMessage("No results found for your search.")
        }
    })
  }

  private func showNoContentMessage(text: String) {
    guard self.noContentLabel.hidden else {
      return
    }
    self.noContentLabel.text = text
    UIView.transitionWithView(self.noContentLabel,
                              duration: 0.2,
                              options: [.CurveEaseOut, .TransitionCrossDissolve],
                              animations: { self.noContentLabel.hidden = false },
                              completion: nil)
  }

  private func hideNoContentMessage() {
    guard !self.noContentLabel.hidden else {
      return
    }
    UIView.transitionWithView(self.noContentLabel,
                              duration: 0.2,
                              options: [.CurveEaseOut, .TransitionCrossDissolve],
                              animations: { self.noContentLabel.hidden = true },
                              completion: nil)
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
  func favorite() {
    toggleFavorite()
  }

  func unFavorite() {
    toggleFavorite()
  }

  private func toggleFavorite() {
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
