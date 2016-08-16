//
//  HTTP.swift
//  Juke
//
//  Created by Jeffery Trespalacios on 8/13/16.
//  Copyright © 2016 Jeffery Trespalacios. All rights reserved.
//

import Foundation
import SwiftyJSON

public class HTTP {
  // Internal Tooling
  private static let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
  private static let httpQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
  private static let managementQueue = dispatch_queue_create("co.j3p.http.management", DISPATCH_QUEUE_SERIAL)
  private static var ongoingRequests: Set<HTTP> = Set<HTTP>()

  public static func queueBlock(block: () -> Void) {
    dispatch_async(HTTP.httpQueue) {
      block()
    }
  }

  private static func addRequest(request: HTTP) {
    dispatch_async(HTTP.managementQueue) {
      HTTP.ongoingRequests.insert(request)
    }
  }

  private static func removeRequest(request: HTTP) {
    dispatch_async(HTTP.managementQueue) {
      HTTP.ongoingRequests.remove(request)
    }
  }

  public enum Error: ErrorType {
    case invalidUrl
    case networkUnavailable
    case connectionTimedOut
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case clientError(Int)
    case serverError(Int)
    case unexpectedResponse(NSURLResponse?)
    case paramsFailedToSerialize(ErrorType)
    case responseFailedJSONSerialization(ErrorType)
    case framework(NSError)
    case failedToCreateObjectFromJson(JSON)
    case failedToCreateObjectFromData(NSData)
    case noDataAvailable
  }

  public enum Action: String {
    case get
    case post
    case delete
    case puts
  }

  public enum StatusCode {
    case ok
    case created
    case noContent
    case success(Int)
    case notModified
    case redirected(Int)
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case clientError(Int)
    case serverError(Int)
    case unknown(Int)

    init(fromInt i: Int) {
      switch i {
      case 200:
        self = .ok
      case 201:
        self = .created
      case 204:
        self = .noContent
      case 200..<300:
        self = .success(i)
      case 304:
        self = .notModified
      case 300..<400:
        self = .redirected(i)
      case 400:
        self = .badRequest
      case 401:
        self = .unauthorized
      case 403:
        self = .forbidden
      case 404:
        self = .notFound
      case 400..<500:
        self = .clientError(i)
      case 500..<600:
        self = .serverError(i)
      default:
        self = .unknown(i)
      }
    }

    var error: Error? {
      switch self {
      case .ok, .created, .noContent, .success(_), .notModified, .redirected(_), .unknown(_):
        return nil
      case .badRequest:
        return Error.badRequest
      case .forbidden:
        return Error.forbidden
      case .notFound:
        return Error.notFound
      case .unauthorized:
        return Error.unauthorized
      case .clientError(let i):
        return Error.clientError(i)
      case .serverError(let i):
        return Error.serverError(i)
      }
    }
  }

  public typealias ResponseHandler = (NSData?, NSHTTPURLResponse) -> ()
  public typealias ErrorHandler = (Error) -> ()

  public var request: NSURLRequest? {
    guard let finalUrl = self.finalUrl else {
      self.error = Error.invalidUrl
      return nil
    }
    let request = NSMutableURLRequest(URL: finalUrl)
    request.HTTPMethod = self.action.rawValue
    if let params = self.params where self.action == .post {
      do {
        request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(params, options: [])
      }
      catch {
        self.error = Error.paramsFailedToSerialize(error)
        return nil
      }
    }
    return request
  }
  public var response: NSHTTPURLResponse?
  public var statusCode: StatusCode? {
    guard let sc = response?.statusCode else {
      return nil
    }
    return StatusCode(fromInt: sc)
  }

  private let url: String
  private var finalUrl: NSURL? {
    if let params = self.params where self.action == .get {
      guard let urlParts = NSURLComponents(string: url) else {
        return nil
      }
      urlParts.queryItems = params.map { NSURLQueryItem(name: $0, value: $1) }
      return urlParts.URL
    }
    else {
      return NSURL(string: self.url)
    }
  }
  private let action: Action
  private var params: [String: String]?
  private var handler: ResponseHandler?
  private var error: Error? {
    didSet {
      if let e = error where self.errorHandlers.count > 0 {
        self.errorHandlers.forEach { eh in HTTP.queueBlock { eh(e) } }
      }
      self.complete()
    }
  }

  private var responseData: NSData?
  private var errorHandlers = Array<ErrorHandler>()
  private var task: NSURLSessionTask?
  private var session: NSURLSession = HTTP.defaultSession

  public init(url: String, params: [String: String]? = nil, action: HTTP.Action = .get) {
    self.url = url
    self.action = action
    self.params = params
    HTTP.addRequest(self)
  }

  public class func get(url: String, params: [String: String]? = nil) -> HTTP {
    let http = HTTP(url: url, params: params)
    return http
  }

  public class func post(url: String, params: [String: String]) -> HTTP {
    let http = HTTP(url: url, params: params, action: .post)
    return http
  }

  public func withSession(session: NSURLSession) -> HTTP {
    self.session = session
    return self
  }

  public func onResult(handler: ResponseHandler) -> HTTP {
    self.handler = handler
    self.queueRequest()
    return self
  }

  public func onResult<T: DataCreatable>(handler: (T) -> ()) -> HTTP {
    self.onResult { [weak self] (data: NSData?, response: NSHTTPURLResponse) in
      guard let strongSelf = self else {
        return
      }
      guard let data = data else {
        strongSelf.error = Error.noDataAvailable
        return
      }
      guard let item = T(data: data) else {
        strongSelf.error = Error.failedToCreateObjectFromData(data)
        return
      }
      HTTP.queueBlock { handler(item) }
    }
    return self
  }

  public func onResult<T: JSONParsable>(handler: (T) -> ()) -> HTTP {
    self.onResult { [weak self] (json: JSON) in
      guard let strongSelf = self else {
        return
      }
      if let error = json.error {
        strongSelf.error = Error.responseFailedJSONSerialization(error)
        return
      }
      if let result = T(json: json) {
        HTTP.queueBlock { handler(result) }
      }
      else {
        strongSelf.error = Error.failedToCreateObjectFromJson(json)
      }
    }
    return self
  }

  public func onError(handler: ErrorHandler) -> HTTP {
    if let e = self.error {
      handler(e)
    }
    else {
      self.errorHandlers.append(handler)
    }
    return self
  }

  internal func queueRequest() {
    guard let request = request else {
      return
    }
    self.task = self.session.dataTaskWithRequest(request) { [weak self] (data: NSData?, response: NSURLResponse?, error: NSError?) in
      guard let strongSelf = self else {
        return
      }
      if let e = error {
        let errorCode = e.code
        switch errorCode {
        case NSURLError.NotConnectedToInternet.rawValue,
             NSURLError.NetworkConnectionLost.rawValue:
          strongSelf.error = Error.networkUnavailable
        case NSURLError.TimedOut.rawValue:
          strongSelf.error = Error.connectionTimedOut
        default:
          strongSelf.error = Error.framework(e)
        }
        return
      }
      strongSelf.responseData = data
      guard let httpResponse = response as? NSHTTPURLResponse else {
        strongSelf.error = Error.unexpectedResponse(response)
        return
      }
      strongSelf.response = httpResponse
      guard let sc = strongSelf.statusCode else {
        return
      }
      switch sc {
      case .ok, .success(_):
        strongSelf.queueHandler()
      default:
        strongSelf.error = sc.error
      }
    }
  }

  public func execute() -> HTTP {
    self.task?.resume()
    return self
  }

  public func cancel() {
    self.task?.cancel()
    self.complete()
  }

  private func queueHandler() {
    if let handler = self.handler, responseData = self.responseData, response = self.response {
      HTTP.queueBlock { [unowned self] in
        handler(responseData, response)
        self.complete()
      }
    }
  }

  internal func complete() {
    HTTP.removeRequest(self)
  }
}

extension HTTP: Hashable, Equatable {
  public var hashValue: Int {
    var hash = self.url.hashValue ^ self.action.hashValue
    if let params = params {
      params.keys.sort().forEach { (key: String) in
        guard let value = params[key] else {
          hash = hash ^ key.hashValue
          return
        }
        hash = hash ^ key.hashValue ^ value.hashValue
      }
    }
    return hash
  }
}

public func ==(lhs: HTTP, rhs: HTTP) -> Bool {
  func paramsEqual() -> Bool {
    switch (lhs.params, rhs.params) {
    case (nil, nil):
      return true
    case(nil, .Some(_)), (.Some(_), nil):
      return false
    case(.Some(let lp), .Some(let rp)):
      var result = lp.count == rp.count
      if  result {
        for key in lp.keys {
          if lp[key] != rp[key] {
            result = false
            break;
          }
        }
      }
      return result
    }
  }
  return lhs.url == rhs.url && lhs.action == rhs.action && paramsEqual()
}

public protocol DataCreatable {
  init?(data: NSData)
}

extension UIImage: DataCreatable {}

extension JSON: DataCreatable {
  public init?(data: NSData) {
    let error: NSErrorPointer = nil
    self.init(data: data, options: .AllowFragments, error: error)
    if error != nil {
      return nil
    }
  }
}

public protocol JSONParsable {
  init?(json: JSON)
}
