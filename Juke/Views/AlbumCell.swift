//
//  AlbumCell.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/15/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import UIKit

class AlbumCell: UICollectionViewCell {
  static let reuseIdentifier = "co.j3p.Juke.AlbumCell"
  weak var albumArtView: RemoteImageView!
  weak var label: UILabel!

  override init(frame: CGRect) {
    let remoteImageView = RemoteImageView(frame: .zero)
    let label = UILabel(frame: .zero)
    self.albumArtView = remoteImageView
    self.label = label
    super.init(frame: frame)
    [remoteImageView, label].forEach {
      self.contentView.addSubview($0)
      $0.translatesAutoresizingMaskIntoConstraints = false
    }
    let viewBindings = [
      "iv": remoteImageView,
      "lb": label
    ]
    self.contentView.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("H:|-[iv]-|", options: [.AlignAllLeading], metrics: nil, views: viewBindings)
    )
    self.contentView.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("H:|-[lb]-|", options: [.AlignAllLeading], metrics: nil, views: viewBindings)
    )
    self.contentView.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("V:|-[iv]-[lb(<=50)]-|", options: [.AlignAllLeading], metrics: nil, views: viewBindings)
    )
    remoteImageView.heightAnchor.constraintEqualToAnchor(remoteImageView.widthAnchor, multiplier: 1).active = true
    self.backgroundColor = UIColor.whiteColor()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  override func prepareForReuse() {
    self.albumArtView.image = nil
    self.label.text = nil
    self.albumArtView.cancelLoading()
  }
}
