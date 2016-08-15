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
    UIView.transitionWithView(self,
                              duration: 0.2,
                              options: [.CurveEaseOut],
                              animations: { self.image = image },
                              completion: nil)
  }
  
  public func displayFromCacheLoad(image: UIImage) {
    self.transform = CGAffineTransformScale(self.transform, 0.01, 0.01)
    self.image = image
    UIView.animateWithDuration(0.2,
                               delay: 0,
                               options: [.CurveEaseOut],
                               animations: { self.transform = CGAffineTransformIdentity },
                               completion: nil)
  }
  
  public func cancelLoading() {
    self.imageRequest?.cancel()
  }
}

extension Int {
  var MB: Int {
    return self * 1024 * 1024
  }
  var KB: Int {
    return self * 1024
  }
}

public class ImageLoad: HTTP {
  static let imageCache = NSURLCache(memoryCapacity: 20.MB, diskCapacity: 0, diskPath: nil)
  static let session: NSURLSession = {
    let config = NSURLSessionConfiguration.defaultSessionConfiguration()
    config.URLCache = ImageLoad.imageCache
    return NSURLSession(configuration: config)
  }()
  
  private var cachedImage: UIImage?
  private var cacheHandler: ((UIImage) -> ())?
  
  public override class func get(url: String, params: [String: String]? = nil) -> ImageLoad {
    return  ImageLoad(url: url, params: params, action: .get)
  }
  
  override init(url: String, params: [String : String]?, action: HTTP.Action) {
    super.init(url: url, params: params, action: action)
    withSession(ImageLoad.session)
  }
  
  override func queueRequest() {
    guard let request = request, handler = cacheHandler, cachedResposne = ImageLoad.imageCache.cachedResponseForRequest(request),
      let image = UIImage(data: cachedResposne.data) else {
        super.queueRequest()
        return
    }
    handler(image)
    print("Cache hit for \(request.URL)")
    self.complete()
  }
  
  public func onCacheHit(handler: (UIImage) -> ()) -> ImageLoad {
    self.cacheHandler = handler
    return self
  }
}