//
//  Event.swift
//  Eatery
//
//  Created by Alexander Zielenski on 10/4/15.
//  Copyright © 2015 CUAppDev. All rights reserved.
//

import UIKit
import SwiftyJSON

/**
 *  An Event of an Eatery such as Breakfast, Lunch, or Dinner
 */
public struct Event {
    /// Date and time that this event begins
    public let startDate: NSDate
    
    /// Human-readable representation of `startDate`
    public let startDateFormatted: String
    
    /// Date and time that this event ends
    public let endDate: NSDate
    
    /// Human-readable repersentation of `endDate`
    public let endDateFormatted: String
    
    /// Short description of the Event
    public let desc: String

    /// Summary of the event
    public let summary: String
    
    /// A mapping from "Category"->[Menu Items] where category could be something like
    /// "Ice Cream Flavors" or "Traditional Hot Food"
    public let menu: [String: [MenuItem]]
    
    internal init(json: JSON) {
        desc = json[APIKey.Description.rawValue].stringValue
        summary = json[APIKey.Summary.rawValue].stringValue
        startDate = NSDate(timeIntervalSince1970: json[APIKey.StartTime.rawValue].doubleValue)
        endDate   = NSDate(timeIntervalSince1970: json[APIKey.EndTime.rawValue].doubleValue)
        startDateFormatted = json[APIKey.StartFormat.rawValue].stringValue
        endDateFormatted = json[APIKey.EndFormat.rawValue].stringValue
        
        let menuJSON = json[APIKey.Menu.rawValue]
        menu = Event.menuFromJSON(menuJSON)
    }
    
    internal static func menuFromJSON(menuJSON: JSON) -> [String: [MenuItem]] {
        var items: [String: [MenuItem]] = [:]

        for (_, json) in menuJSON {
            let category = json[APIKey.Category.rawValue].stringValue
            var menuItems: [MenuItem] = []
            
            let itemsJSON = json[APIKey.Items.rawValue]
            for (_, itemJSON) in itemsJSON {
                menuItems.append(MenuItem(json: itemJSON))
            }
            
            items[category] = menuItems
        }
        
        return items
    }
    
    /**
     Tells whether or not this specific event is occurring at some date and time
     
     - parameter date: The date for which to check if this event is active
     
     - returns: true if `date` is between the `startDate` and `endDate` of the event
     */
    public func occurringOnDate(date: NSDate) -> Bool {
        return startDate.compare(date) != .OrderedDescending && endDate.compare(date) != .OrderedAscending
    }
}
