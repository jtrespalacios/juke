//
//  RemoteImageView.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/14/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import UIKit

public class RemoteImageView: UIImageView {
  private weak var imageRequest: HTTP?

  public func loadImage(url: String) {
    imageRequest = ImageLoad.get(url)
      .onCacheHit { (image: UIImage) in
        dispatchMain { [weak self] in self?.displayFromCacheLoad(image) }
      }
      .onResult { (image: UIImage) in
        dispatchMain { [weak self] in self?.displayFromRemoateLoad(image) }
      }
      .execute()
  }

  public func displayFromRemoateLoad(image: UIImage) {
    self.transform = CGAffineTransformScale(self.transform, 0.01, 0.01)
    self.image = image
    UIView.animateWithDuration(0.2,
                               delay: 0,
                               options: [.CurveEaseOut],
                               animations: { self.transform = CGAffineTransformIdentity },
                               completion: nil)
  }

  public func displayFromCacheLoad(image: UIImage) {
    self.image = image
  }

  public func cancelLoading() {
    self.imageRequest?.cancel()
  }
}
