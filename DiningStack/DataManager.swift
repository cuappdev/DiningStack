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
    case Root
    case Eateries
    
    var URLString: String {
        let path: String = {
            switch self {
            case .Root:
                return "/"
            case .Eateries:
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
enum DataError: ErrorType {
    case ServerError
}

/// FileName for JSON data location
let FileName = "/eateryJSON.dat"

/**
 Returns the path for user documents directory
*/
func getDocumentsDirectory() -> String {
    let path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
    return path
}

/// Top-level class to communicate with Cornell Dining
public class DataManager: NSObject {
    
    /// Gives a shared instance of `DataManager`
    public static let sharedInstance = DataManager()
    
    /// List of all the Dining Locations with parsed events and menus
    private (set) public var eateries: [Eatery] = []
    
    /// Timestamp of last fetch from Cornell API
    public var dateLastFetched: NSDate? {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            if let date = defaults.objectForKey("dateLastFetched") as? NSDate {
                return date
            } else {
                return nil
            }
        } set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(newValue, forKey: "dateLastFetched")
        }
    }
    
    /**
     Reads eateries from user documents and stores them in the 'eateries' property.
     
     Returns: Bool whether the operation succeeded
     */
    public func readEateriesFromDisk() -> Bool {
        let path = getDocumentsDirectory().stringByAppendingString(FileName)
        if let data = NSData(contentsOfFile: path) {
            
            let json = JSON(data: data)
            
            let eateryList = json["data"]["eateries"]
            self.eateries = eateryList.map { Eatery(json: $0.1) }
            
            return true
        } else {
            return false
        }
    }
    
    /**
     Sends a GET request to the Cornell API to get the events for all eateries and
     stores them in user documents.
     
     - parameter force:      Boolean indicating that the data should be refreshed even if
     the cache is invalid.
     - parameter completion: Completion block called upon successful receipt and parsing
     of the data or with an error if there was one. Use `-eateries` to get the parsed
     response.
     */
    public func fetchEateries(force: Bool, completion: ((error: ErrorType?) -> (Void))?) {
        if eateries.count > 0 && !force {
            completion?(error: nil)
            return
        }
        
        let req = Alamofire.request(.GET, Router.Eateries)
        
        func processData (data: NSData) {
            
            let json = JSON(data: data)
            
            if (json[APIKey.Status.rawValue].stringValue != Status.Success.rawValue) {
                completion?(error: DataError.ServerError)
                // do something is message
                return
            }
            
            let eateryList = json["data"]["eateries"]
            self.eateries = eateryList.map { Eatery(json: $0.1) }
            
            dateLastFetched = NSDate()
            
            let path = getDocumentsDirectory().stringByAppendingString(FileName)
            
            do {
                try data.writeToFile(path, options: .DataWritingAtomic)
            } catch {
                completion?(error: error)
            }
            
            completion?(error: nil)
        }
        
        if let request = req.request where !force {
            let cached = NSURLCache.sharedURLCache().cachedResponseForRequest(request)
            if let info = cached?.userInfo {
                // This is hacky because the server doesn't support caching really
                // and even if it did it is too slow to respond to make it worthwhile
                // so I'm going to try to screw with the cache policy depending
                // upon the age of the entry in the cache
                if let date = info["date"] as? Double {
                    let maxAge: Double = 24 * 60 * 60
                    let now = NSDate().timeIntervalSince1970
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
                    let cached = NSCachedURLResponse(response: response, data: data, userInfo: ["date": NSDate().timeIntervalSince1970], storagePolicy: .Allowed)
                    NSURLCache.sharedURLCache().storeCachedResponse(cached, forRequest: request)
            }
            
            if let jsonData = data.value {
                processData(jsonData)
                
            } else {
                completion?(error: data.error)
            }
            
        }
    }
}
