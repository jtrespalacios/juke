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
    remoteImageView.contentMode = .ScaleAspectFit
    remoteImageView.layer.cornerRadius = 5
    let label = UILabel(frame: .zero)
    label.numberOfLines = 0
    label.allowsDefaultTighteningForTruncation = true
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.75
    label.textAlignment = .Center
    label.translatesAutoresizingMaskIntoConstraints = false
    label.backgroundColor = UIColor.whiteColor()

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
      NSLayoutConstraint.constraintsWithVisualFormat("H:|-(>=8)-[iv]-(>=8)-|", options: [], metrics: nil, views: viewBindings)
    )
    self.contentView.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("H:|-(>=8)-[lb]-(>=8)-|", options: [], metrics: nil, views: viewBindings)
    )
    self.contentView.addConstraints(
      NSLayoutConstraint.constraintsWithVisualFormat("V:|-[iv]-[lb(>=60)]-|", options: [.AlignAllCenterX], metrics: nil, views: viewBindings)
    )
    remoteImageView.centerXAnchor.constraintEqualToAnchor(self.contentView.centerXAnchor).active = true
    remoteImageView.widthAnchor.constraintEqualToAnchor(remoteImageView.heightAnchor, multiplier: 1).active = true
    self.backgroundColor = UIColor.whiteColor()
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  override func prepareForReuse() {
    self.albumArtView.cancelLoading()
    self.albumArtView.image = nil
    self.label.text = nil
  }
}
