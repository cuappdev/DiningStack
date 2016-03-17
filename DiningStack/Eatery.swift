//
//  Eatery.swift
//  Eatery
//
//  Created by Alexander Zielenski on 10/4/15.
//  Copyright © 2015 CUAppDev. All rights reserved.
//

import UIKit
import SwiftyJSON
import CoreLocation

/**
 Different meals served by eateries
 
 - Breakfast: Breakfast
 - Brunch:    Brunch
 - LiteLunch: Lite Lunch
 - Lunch:     Lunch
 - Dinner:    Dinner
 - Other:     Unknown
 */
public enum Meal: String {
    case Breakfast = "Breakfast"
    case Brunch    = "Brunch"
    case LiteLunch = "Lite Lunch"
    case Lunch     = "Lunch"
    case Dinner    = "Dinner"
    case Other     = ""
}

/**
 Assorted types of payment accepted by an Eatery
 
 - BRB:         Big Red Bucks
 - Swipes:      Meal Swipes
 - Cash:        USD
 - CornellCard: CornellCard
 - CreditCard:  Major Credit Cards
 - NFC:         Mobile Payments
 - Other:       Unknown
 */
public enum PaymentType: String {
    case BRB         = "Meal Plan - Debit"
    case Swipes      = "Meal Plan - Swipe"
    case Cash        = "Cash"
    case CornellCard = "Cornell Card"
    case CreditCard  = "Major Credit Cards"
    case NFC         = "Mobile Payments"
    case Other       = ""
}

/**
 Different types of eateries on campus
 
 - Unknown:          Unknown
 - Dining:           All You Care to Eat Dining Halls
 - Cafe:             Cafes
 - Cart:             Carts + Food Trucks
 - FoodCourt:        Food Courts (Variety of Food Selections)
 - ConvenienceStore: Convenience Stores
 - CoffeeShop:       Coffee Shops + Some Food
 */
public enum EateryType: String {
    case Unknown          = ""
    case Dining           = "all you care to eat"
    case Cafe             = "cafe"
    case Cart             = "cart"
    case FoodCourt        = "food court"
    case ConvenienceStore = "convenience store"
    case CoffeeShop       = "coffee shop"
    case Bakery           = "bakery"
}

/**
 Represents a location on Cornell Campus
 
 - Unknown: Unknown
 - West:    West Campus
 - North:   North Campus
 - Central: Central Campus
 */
public enum Area: String {
    case Unknown = ""
    case West    = "West"
    case North   = "North"
    case Central = "Central"
}

private func makeFormatter () -> NSDateFormatter {
    let formatter = NSDateFormatter()
    formatter.dateFormat = "YYYY-MM-dd"
    return formatter
}

/// Represents a Cornell Dining Facility and information about it
/// such as open times, menus, location, etc.
public class Eatery: NSObject {
    private static let dateFormatter = makeFormatter()
    
    /// Campus names and open or closed names for sorting
    public static let campusNames = ["Central", "West", "North"]
    public static let openNames = ["Open", "Closed"]
    
    /// Unique Identifier
    public let id: Int
    
    /// Human Readable name
    public let name: String
    
    /// Human Readable short name
    public let nameShort: String
    
    /// Unique internal name
    public let slug: String
    
    /// Eatery Type
    public let eateryType: EateryType
    
    /// Short description
    public let about: String // actually "aboutshort"
    
    /// String representation of the phone number
    public let phone: String
    
    /// General location on Campus
    public let area: Area
    
    /// Exact Address
    public let address: String
    
    /// Acceptable types of payment
    public let paymentMethods: [PaymentType]
    
    /// A menu of constant dining items. Exists if this eatery's menu
    /// never changes. This should be used if it exists.
    public var diningItems: [String: [MenuItem]]?
    
    /// A constant hardcoded menu if this Eatery has one.
    /// This should be used if it exists yet diningItems does not.
    public let hardcodedMenu: [String: [MenuItem]]?
    
    /// GPS Location
    public let location: CLLocation
    
    // Maps 2015-03-01 to [Event]
    // Thought about using just an array, but
    // for many events, this is much faster for lookups
    /// List of all events for this eatery
    /// Maps the date the event occurs to a list of the event name
    /// to the event itself e.g.:
    /// [ "2015-03-01": ["Lunch": Event]]
    private(set) var events: [String: [String: Event]] = [:]
    
    // Gives a string full of all the menus for this eatery today
    // this is used for searching.
    private var _todaysEventsString: String? = nil
    override public var description: String {
        get {
            if let _todaysEventsString = _todaysEventsString {
                return _todaysEventsString
            }
            let ar = Array(eventsOnDate(NSDate()).values)
            let strings = ar.map { (ev: Event) -> String in
                ev.menu.description
            }
            
            _todaysEventsString = strings.joinWithSeparator("\n")
            return _todaysEventsString!
        }
    }
    
    internal init(json: JSON) {
        id    = json[APIKey.Identifier.rawValue].intValue
        name  = json[APIKey.Name.rawValue].stringValue
        nameShort  = json[APIKey.NameShort.rawValue].stringValue
        slug  = json[APIKey.Slug.rawValue].stringValue
        about = json[APIKey.AboutShort.rawValue].stringValue
        phone = json[APIKey.PhoneNumber.rawValue].stringValue
        
        //TODO: make the below line safe
        area     = Area(rawValue: json[APIKey.CampusArea.rawValue][APIKey.ShortDescription.rawValue].stringValue) ?? .Unknown
        eateryType  = EateryType(rawValue: json[APIKey.EateryTypes.rawValue][0][APIKey.ShortDescription.rawValue].stringValue) ?? .Unknown
        address  = json[APIKey.Address.rawValue].stringValue
        location = CLLocation(latitude: json[APIKey.Latitude.rawValue].doubleValue, longitude: json[APIKey.Longitude.rawValue].doubleValue)
        
        paymentMethods = json[APIKey.Payment.rawValue].arrayValue.map({ (j) in
            return PaymentType(rawValue: j[APIKey.ShortDescription.rawValue].stringValue) ?? PaymentType.Other
        })
        
        if let d = kEateryGeneralMenus[slug] {
            hardcodedMenu = Event.menuFromJSON(d)
        } else {
            hardcodedMenu = nil
        }
        
        let hoursJSON = json[APIKey.Hours.rawValue]
        var menuEmpty = true //will be set to false if any menu item is found in an event
        
        for (_, hour) in hoursJSON {
            let eventsJSON = hour[APIKey.Events.rawValue]
            let key        = hour[APIKey.Date.rawValue].stringValue
            
            var currentEvents: [String: Event] = [:]
            for (_, eventJSON) in eventsJSON {
                var event = Event(json: eventJSON)
                if !event.menu.isEmpty {
                    menuEmpty = false
                }
                //if the description already exists, merge them if possible
                if let oldEvent = currentEvents[event.desc] {
                    if oldEvent.endDate == event.startDate {
                        var newEvent = oldEvent
                        newEvent.endDate = event.endDate
                        event = newEvent
                    } else if oldEvent.startDate == event.endDate {
                        var newEvent = oldEvent
                        newEvent.startDate = event.startDate
                        event = newEvent
                    } else {
                        //can't merge, uniquify descriptions
                        var counter = 1
                        while (currentEvents[event.desc] != nil) {
                            event.desc = event.desc + " " + String(counter)
                            counter += 1
                        }
                    }
                }
                currentEvents[event.desc] = event
                
            }
            
            events[key] = currentEvents
        }
        
        // Create diningItems if menu is empty
        if menuEmpty {
            let key = "General"
            diningItems = [:]
            diningItems![key] = []
            for (_, item) in json[APIKey.DiningItems.rawValue] {
                let menuItem = MenuItem(json: item)
                diningItems![key]!.append(menuItem)
            }
            //Make nil if empty to fall back on hardcoded
            if diningItems![key]!.isEmpty {
                diningItems = nil
            }
        }
        
    }
    
    /**
     Tells if this Eatery is open at a specific time
     
     - parameter date: Specifically the time to check for
     
     - returns: true if this eatery has an event active at the given date and time
     
     - see: `isOpenForDate`
     */
    public func isOpenOnDate(date: NSDate) -> Bool {
        let yesterday = NSDate(timeInterval: -1 * 24 * 60 * 60, sinceDate: date)
        
        for now in [date, yesterday] {
            let events = eventsOnDate(now)
            for (_, event) in events {
                if event.occurringOnDate(date) {
                    return true
                }
            }
        }
        
        return false
    }
    
    //
    /**
     Tells if eatery is open within the calendar date given. This is distinct from `isOpenOnDate` in that it does not check a specific time, just the day, month, and year.
     
     - parameter date: The date to check
     
     - returns: true of there is an event active at some point within the given calendar day
     
     - see: `isOpenOnDate`
     */
    public func isOpenForDate(date: NSDate) -> Bool {
        let events = eventsOnDate(date)
        return events.count != 0
    }
    
    /**
     Is the eatery open now?
     
     - returns: true if the eatery is open at the present date and time
     */
    public func isOpenNow() -> Bool {
        return isOpenOnDate(NSDate())
    }
    
    /**
     Tells if eatery is open at some point today
     
     - returns: true if the eatery will be open at some point today or was already open
     */
    public func isOpenToday() -> Bool {
        return isOpenForDate(NSDate())
    }
    
    /**
     Retrieve event instances for a specific day
     
     - parameter date: The date for which you would like a list of events for
     
     - returns: A mapping from Event Name to Event for the given day.
     */
    public func eventsOnDate(date: NSDate) -> [String: Event] {
        let dateString = Eatery.dateFormatter.stringFromDate(date)
        return events[dateString] ?? [:]
    }
    
    /**
     Retrieve the currently active event or the next event for a day/time
     
     - parameter date: The date you would like the active event for
     
     - returns: The active event on a certain day/time, or nil if there was none.
     For our purposes, "active" means currently running or will run soon. As in, if there
     was no event running at exactly the date given but there will be one 15 minutes afterwards, that event would be returned. If the next event was over a day away, nil would be returned.
     */
    public func activeEventForDate(date: NSDate) -> Event? {
        let yesterday = NSDate(timeInterval: (-24 * 60 * 60), sinceDate: date)
        let tomorrow = NSDate(timeInterval: 24 * 60 * 60, sinceDate: date)
        
        var timeDifference = DBL_MAX
        var next: Event? = nil
        
        for now in [yesterday, date, tomorrow] {
            let events = eventsOnDate(now)
            
            for (_, event) in events {
                let diff = event.startDate.timeIntervalSince1970 - date.timeIntervalSince1970
                if event.occurringOnDate(date) {
                    return event
                } else if diff < timeDifference && diff > 0 {
                    timeDifference = diff
                    next = event
                }
            }
        }
        
        return next
    }
    
    /**
     Returns an iterable form of an entire menu
     
     - returns: a list of tuples in the form (category,[item list]).
     For each category we create a tuple containing the food category name as a string
     and the food items available for the category as a string list. Used to easily iterate
     over all items in the hardcoded menu. Ex: [("Entrees",["Chicken", "Steak", "Fish"]), ("Fruit", ["Apples"])]
     */
    private func getMenuIterable(menuList: [String: [MenuItem]]?) -> [(String,[String])] {
        guard let menu = menuList else { return [] }
        return menu.map({ (name, items) -> (String, [String]) in
            (name, items.map({ ($0.name) }))
        })
    }
    
    public func getHardcodeMenuIterable() -> [(String,[String])] {
        return getMenuIterable(hardcodedMenu)
    }
    
    public func getDiningItemMenuIterable() -> [(String,[String])] {
        return getMenuIterable(diningItems)
    }
  
    public func getAlternateMenuIterable() -> [(String, [String])] {
        if diningItems != nil {
            return getDiningItemMenuIterable()
        } else if hardcodedMenu != nil {
            return getHardcodeMenuIterable()
        } else {
            return []
        }
    }

    public func sortMenu(menu: [String: [MenuItem]]) -> [(String, [MenuItem])] {
        
        let sortedMenu = menu.sort {
            if($0.0 == "Hot Traditional Station - Entrees") {
                return true
            }
            
            if($0.0 == "Hot Traditional Station - Sides" && $1.0 != "Hot Traditional Station - Entrees") {
                return true
            }
            
            return false
        }
        
        return sortedMenu
    }
 }
