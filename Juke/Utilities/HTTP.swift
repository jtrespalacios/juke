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
  static let httpQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
  static let defaultSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
  static var ongoingRequests = [Int: HTTP]()
  
  private static func queueBlock(block: () -> Void) {
    dispatch_async(HTTP.httpQueue) {
      block()
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
  }
  
  public enum Verb: String {
    case get = "get"
    case post = "post"
    case delete = "delete"
    case puts = "puts"
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
  public typealias ErrorHandler = (ErrorType) -> ()
  
  public var response: NSHTTPURLResponse?
  public var statusCode: StatusCode? {
    guard let sc = response?.statusCode else {
      return nil
    }
    return StatusCode(fromInt: sc)
  }
  
  private let lookupValue: Int
  private let url: String
  private var finalUrl: NSURL? {
    let finalUrlString: String
    if let params = self.params where self.action == .get {
      let queryCharacterSet = NSCharacterSet.URLQueryAllowedCharacterSet()
      let queryString = (params.flatMap { "\($0)=\($1.stringByAddingPercentEncodingWithAllowedCharacters(queryCharacterSet)!)" }).joinWithSeparator("&")
      finalUrlString = "\(self.url)?\(queryString)"
    } else {
      finalUrlString = self.url
    }
    return NSURL(string: finalUrlString)
  }
  private let action: Verb
  private var params: [String: String]?
  private var handler: ResponseHandler?
  private var error: ErrorType? {
    didSet {
      if let e = error where self.errorHandlers.count > 0 {
        let ehs = errorHandlers
        ehs.forEach { eh in HTTP.queueBlock { eh(e) } }
      }
      self.complete()
    }
  }
  
  private var responseData: NSData?
  private var errorHandlers = Array<ErrorHandler>()
  private var task: NSURLSessionTask?
  private var session: NSURLSession = HTTP.defaultSession
  
  private init(url: String, params: [String: String]? = nil, action: HTTP.Verb = .get) {
    
    var hashValue = url.hashValue ^ action.hashValue
    if let params = params {
      params.forEach { (key: String, value: String) in
        hashValue = hashValue ^ key.hashValue ^ value.hashValue
      }
    }
    self.lookupValue = hashValue
    self.url = url
    self.action = action
    self.params = params
    HTTP.ongoingRequests[hashValue] = self
  }
  
  public static func get(url: String, params: [String: String]? = nil) -> HTTP {
    let http = HTTP(url: url, params: params)
    return http
  }
  
  public static func post(url: String, params: [String: String]) -> HTTP {
    let http = HTTP(url: url, params: params, action: .post)
    return http
  }
  
  public func onSession(session: NSURLSession) -> HTTP {
    self.session = session
    return self
  }
  
  public func then(handler: ResponseHandler) -> HTTP {
    self.handler = handler
    self.queueRequest()
    return self
  }
  
  public func then<T: JSONParsable>(handler: (T) -> ()) -> HTTP {
    self.then { [weak self] (data: NSData?, response: NSHTTPURLResponse) in
      guard let strongSelf = self else {
        return
      }
      guard let data = data else {
        return
      }
      let json = JSON(data: data)
      if let error = json.error {
        strongSelf.error = Error.responseFailedJSONSerialization(error)
      }
      if let result = T(fromJSON: json) {
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
    } else {
      self.errorHandlers.append(handler)
    }
    return self
  }
  
  private func queueRequest() {
    guard let finalUrl = self.finalUrl else {
      self.error = Error.invalidUrl
      return
    }
    let request = NSMutableURLRequest(URL: finalUrl)
    request.HTTPMethod = self.action.rawValue
    if let params = self.params where self.action == .post {
      do {
        request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(params, options: [])
      }
      catch {
        self.error = Error.paramsFailedToSerialize(error)
        return
      }
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
    HTTP.ongoingRequests.removeValueForKey(self.lookupValue)
  }
  
  private func queueHandler() {
    if let handler = self.handler, responseData = self.responseData, response = self.response {
      HTTP.queueBlock { [unowned self] in
        handler(responseData, response)
        self.complete()
      }
    }
  }
  
  private func complete() {
    HTTP.queueBlock { [unowned self] in
      HTTP.ongoingRequests.removeValueForKey(self.lookupValue)
    }
    #if DEBUG
      print("On going http requests: \(HTTP.ongoingRequests.count)")
    #endif
  }
}

public protocol JSONParsable {
  init?(fromJSON: JSON)
}
