//
//  ImageLoad.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/15/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import UIKit

public class ImageLoad: HTTP {
  private static let imageCache = NSURLCache(memoryCapacity: 20.MB, diskCapacity: 0, diskPath: nil)
  private static let session: NSURLSession = {
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
    self.withSession(ImageLoad.session)
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
