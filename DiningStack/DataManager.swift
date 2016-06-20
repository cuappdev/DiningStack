//
//  DataManager.swift
//  Eatery
//
//  Created by Eric Appel on 10/8/14.
//  Copyright (c) 2014 CUAppDev. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

let separator = ":------------------------------------------"

/**
 Router Endpoints enum
 */
internal enum Router: URLStringConvertible {
    static let baseURLString = "https://now.dining.cornell.edu/api/1.0/dining"
    case root
    case eateries
    
    var urlString: String {
        let path: String = {
            switch self {
            case .root:
                return "/"
            case .eateries:
                return "/eateries.json"
            }
        }()
        return Router.baseURLString + path
    }
}

/**
 Keys for Cornell API
 These will be in the response dictionary
 */
public enum APIKey : String {
    // Top Level
    case Status    = "status"
    case Data      = "data"
    case Meta      = "meta"
    case Message   = "message"
    
    // Data
    case Eateries  = "eateries"
    
    // Eatery
    case Identifier       = "id"
    case Slug             = "slug"
    case Name             = "name"
    case NameShort        = "nameshort"
    case EateryTypes      = "eateryTypes"
    case AboutShort       = "aboutshort"
    case Latitude         = "latitude"
    case Longitude        = "longitude"
    case Hours            = "operatingHours"
    case Payment          = "payMethods"
    case PhoneNumber      = "contactPhone"
    case CampusArea       = "campusArea"
    case Address          = "location"
    case DiningItems      = "diningItems"
    
    // Hours
    case Date             = "date"
    case Events           = "events"
    
    // Events
    case StartTime        = "startTimestamp"
    case EndTime          = "endTimestamp"
    case StartFormat      = "start"
    case EndFormat        = "end"
    case Menu             = "menu"
    case Summary          = "calSummary"
    
    // Events/Payment/CampusArea/EateryTypes
    case Description      = "descr"
    case ShortDescription = "descrshort"
    
    // Menu
    case Items            = "items"
    case Category         = "category"
    case Item             = "item"
    case Healthy          = "healthy"
    
    // Meta
    case Copyright = "copyright"
    case Timestamp = "responseDttm"
  
    // External
    case Weekday  = "weekday"
    case External = "external"
}

/**
 Enumerated Server Response
 
 - Success: String for the status if the request was a success.
 */
enum Status: String {
    case Success = "success"
}

/**
 Error Types
 
 - ServerError: An error arose from the server-side of things
 */
enum DataError: ErrorProtocol {
    case serverError
}

public enum Date: Int {
  case sunday = 1
  case monday
  case tuesday
  case wednesday
  case thursday
  case friday
  case saturday
  
  init?(string: String) {
    switch string.lowercased() {
    case "sunday":
      self = .sunday
    case "monday":
      self = .monday
    case "tuesday":
      self = .tuesday
    case "wednesday":
      self = .wednesday
    case "thursday":
      self = .thursday
    case "friday":
      self = .friday
    case "saturday":
      self = .saturday
    default:
      return nil
    }
  }
  
  static func ofDateSpan(_ string: String) -> [Date]? {
    let partition = string.lowercased().characters.split{ $0 == "-" }.map(String.init)
    switch partition.count {
    case 2:
      guard let start = Date(string: partition[0]) else { return nil }
      guard let end = Date(string: partition[1]) else { return nil }
      var result: [Date] = []
      let endValue = start.rawValue <= end.rawValue ? end.rawValue : end.rawValue + 7
      for dayValue in start.rawValue...endValue {
        guard let day = Date(rawValue: dayValue % 7) else { return nil }
        result.append(day)
      }
      return result
    case 1:
      guard let start = Date(string: partition[0]) else { return nil }
      return [start]
    default:
      return nil
    }
  }
  
  func getDate() -> Foundation.Date {
    let startOfToday = Calendar.current().startOfDay(for: Foundation.Date())
    let weekDay = Calendar.current().components(.weekday, from: Foundation.Date()).weekday
    let daysAway = (rawValue - weekDay! + 7) % 7
    let endDate = Calendar.current().date(byAdding: .weekday, value: daysAway, to: startOfToday, options: []) ?? Foundation.Date()
    return endDate
  }
  
  func getDateString() -> String {
    let date = getDate()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
  
  func getTimeStamp(_ timeString: String) -> Foundation.Date {
    let endDate = getDate()
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mma"
    let timeIntoEndDate = formatter.date(from: timeString) ?? Foundation.Date()
    let components = Calendar.current().components([.hour, .minute], from: timeIntoEndDate)
    return Calendar.current().date(byAdding: components, to: endDate, options: []) ?? Foundation.Date()
  }
}

/// Top-level class to communicate with Cornell Dining
public class DataManager: NSObject {
  
    /// Gives a shared instance of `DataManager`
    public static let sharedInstance = DataManager()
    
    /// List of all the Dining Locations with parsed events and menus
    private (set) public var eateries: [Eatery] = []
    
    /**
     Sends a GET request to the Cornell API to get the events for all eateries and
     stores them in user documents.
     
     - parameter force:      Boolean indicating that the data should be refreshed even if
     the cache is invalid.
     - parameter completion: Completion block called upon successful receipt and parsing
     of the data or with an error if there was one. Use `-eateries` to get the parsed
     response.
     */
    public func fetchEateries(_ force: Bool, completion: ((error: ErrorProtocol?) -> (Void))?) {
        if eateries.count > 0 && !force {
            completion?(error: nil)
            return
        }
        
        let req = Alamofire.request(.GET, Router.eateries)
        
        func processData (_ data: Data) {
            
            let json = JSON(data: data)
            
            if (json[APIKey.Status.rawValue].stringValue != Status.Success.rawValue) {
                completion?(error: DataError.serverError)
                // do something is message
                return
            }
            
            let eateryList = json["data"]["eateries"]
            let externalEateryList = kExternalEateries["eateries"]!
            self.eateries = eateryList.map { Eatery(json: $0.1) }
            let externalEateries = externalEateryList.map { Eatery(json: $0.1) }
            //don't add duplicate external eateries
            //Uncomment after CU Dining Pushes Eatery with marketing
            /*
            for external in externalEateries {
                if !eateries.contains({ $0.slug == external.slug }) {
                    eateries.append(external)
                }
            }
            */
            
            completion?(error: nil)
        }
        
        if let request = req.request where !force {
            let cached = URLCache.shared().cachedResponse(for: request)
            if let info = cached?.userInfo {
                // This is hacky because the server doesn't support caching really
                // and even if it did it is too slow to respond to make it worthwhile
                // so I'm going to try to screw with the cache policy depending
                // upon the age of the entry in the cache
                if let date = info["date"] as? Double {
                    let maxAge: Double = 24 * 60 * 60
                    let now = Foundation.Date().timeIntervalSince1970
                    if now - date <= maxAge {
                        processData(cached!.data)
                        return
                    }
                }
            }
        }
        
        req.responseData { (resp) -> Void in
            let data = resp.result
            let request = resp.request
            let response = resp.response
            
            if let data = data.value,
                response = response,
                request = request {
                    let cached = CachedURLResponse(response: response, data: data, userInfo: ["date": NSDate().timeIntervalSince1970], storagePolicy: .allowed)
                    URLCache.shared().storeCachedResponse(cached, for: request)
            }
            
            if let jsonData = data.value {
                processData(jsonData)
                
            } else {
                completion?(error: data.error)
            }
            
        }
    }
}
