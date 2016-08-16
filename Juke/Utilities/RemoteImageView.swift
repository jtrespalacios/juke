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
    self.image = image
    self.hidden = true
    UIView.transitionWithView(self,
                              duration: 0.2,
                              options: [.CurveEaseOut, .TransitionCrossDissolve],
                              animations: { self.hidden = false },
                              completion: nil)
  }

  public func displayFromCacheLoad(image: UIImage) {
    self.image = image
  }

  public func cancelLoading() {
    self.imageRequest?.cancel()
  }
}
