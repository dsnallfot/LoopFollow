import Foundation

/// Updated Treatment model includes the documentId (_id from the database)
struct Treatment {
    let documentId: String?
    let eventType: String
    let amount: String?
    let timestamp: Date
    let rawData: [String: AnyObject]
    
    // For override entries, we store additional info.
    let overrideNotes: String?
    let overrideDuration: Double? // in minutes
    
    // For Sensor Start entries, store notes
    let sensorStartNotes: String?
    
    // For Temp Basal entries
    let tempBasalDuration: Double?
    
    /// Failable initializer that creates a Treatment from a dictionary.
    init?(dictionary: [String: AnyObject]) {
        guard let eventType = dictionary["eventType"] as? String else { return nil }
        
        // Parse date from "timestamp" or "created_at".
        var dateString: String?
        if let ts = dictionary["timestamp"] as? String {
            dateString = ts
        } else if let ts = dictionary["created_at"] as? String {
            dateString = ts
        }
        guard let ds = dateString, let date = NightscoutUtils.parseDate(ds) else { return nil }
        self.init(dictionary: dictionary, eventType: eventType, timestamp: date)
    }

    init(cached: TreatmentJSON, dateFormatter: ISO8601DateFormatter) {
        // Keep rawData compatible with existing detail/edit/delete actions.
        let dictionary: [String: AnyObject] = [
            "_id": cached._id as AnyObject,
            "eventType": cached.eventType as AnyObject,
            "created_at": dateFormatter.string(from: cached.created_at) as AnyObject,
            "enteredBy": cached.enteredBy as AnyObject,
            "rate": cached.rate as AnyObject,
            "absolute": cached.absolute as AnyObject,
            "insulin": cached.insulin as AnyObject,
            "carbs": cached.carbs as AnyObject,
            "fat": cached.fat as AnyObject,
            "protein": cached.protein as AnyObject,
            "amount": cached.amount as AnyObject,
            "foodType": cached.foodType as AnyObject,
            "notes": cached.notes as AnyObject,
            "glucose": cached.glucose as AnyObject,
            "units": cached.units as AnyObject,
            "duration": cached.tempBasalDuration as AnyObject
        ]
        self.init(dictionary: dictionary, eventType: cached.eventType, timestamp: cached.created_at)
    }

    var category: TreatmentCategory {
        TreatmentCategory(eventType: eventType, foodType: rawData["foodType"] as? String,
                          notes: rawData["notes"] as? String)
    }

    private init(dictionary: [String: AnyObject], eventType: String, timestamp: Date) {
        self.documentId = dictionary["_id"] as? String
        self.eventType = eventType
        self.timestamp = timestamp
        self.rawData = dictionary
        
        // Fetch the note if the event type is Sensor Start
        if eventType == "Sensor Start" || eventType == "Sensor Change" || eventType == "Sensorbyte" || eventType == "Sensorstart" {
            self.sensorStartNotes = dictionary["notes"] as? String
        } else {
            self.sensorStartNotes = nil
        }
        
        // Create a number formatter that trims trailing zeros.
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        
        var computedAmount: String? = nil
        var computedTempBasalDuration: Double? = nil
        
        if let insulin = dictionary["insulin"] as? Double {
            let insulinString = formatter.string(from: NSNumber(value: insulin)) ?? "\(insulin)"
            computedAmount = "\(insulinString) E"
        } else if let carbs = dictionary["carbs"] as? Double {
            let carbsString = formatter.string(from: NSNumber(value: carbs)) ?? "\(carbs)"
            computedAmount = "\(carbsString) g"
        } else if eventType == "Temp Basal", let absolute = dictionary["absolute"] as? Double {
            let absoluteString = formatter.string(from: NSNumber(value: absolute)) ?? "\(absolute)"
            computedAmount = "\(absoluteString) E/h"
            // Capture the duration (in minutes) for temp basal events
            computedTempBasalDuration = dictionary["duration"] as? Double
        }
        
        self.amount = computedAmount
        self.tempBasalDuration = computedTempBasalDuration
        // For override treatments, capture the notes and duration.
        if eventType == "Temporary Override" || eventType == "Exercise" || eventType == "Override" {
            self.overrideNotes = dictionary["notes"] as? String
            // Assume the "duration" field is in minutes.
            self.overrideDuration = dictionary["duration"] as? Double
        } else {
            self.overrideNotes = nil
            self.overrideDuration = nil
        }
    }
}
