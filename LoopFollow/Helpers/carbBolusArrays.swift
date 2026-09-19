//
//  carbBolusArrays.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/17/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation


extension MainViewController {
    
    func findNearestBGbyTime(needle: TimeInterval, haystack: [ShareGlucoseData], startingIndex: Int) -> (sgv: Double, foundIndex: Int) {
        
        guard let first = haystack.first, let last = haystack.last else {
            return (100.00, 0)
        }
        // Outside the measured interval, anchor to the closest real reading.
        if needle <= first.date { return (Double(first.sgv), 0) }
        if needle >= last.date { return (Double(last.sgv), haystack.count - 1) }

        // A shifted treatment or an out-of-order response may precede the hint.
        let hint = min(max(startingIndex, 0), haystack.count - 1)
        let start = haystack[hint].date <= needle ? hint : 0
        for i in start..<(haystack.count - 1) {
            let left = haystack[i]
            let right = haystack[i + 1]
            if needle >= left.date && needle < right.date {
                // Follow the line between BG readings, not just its left endpoint.
                let fraction = (needle - left.date) / (right.date - left.date)
                let value = Double(left.sgv) + fraction * (Double(right.sgv) - Double(left.sgv))
                return (value, i)
            }
        }
        return (Double(last.sgv), haystack.count - 1)
    }
    

    func findNearestBolusbyTime(timeWithin: Int, needle: TimeInterval, haystack: [bolusGraphStruct], startingIndex: Int) -> (offset: Bool, foundIndex: Int) {
        
        // If we can't find a match or things fail, put it at 100 BG
        for i in startingIndex..<haystack.count {
            // i has reached the end without a result. return 0
            let timeDiff = needle - haystack[i].date
            if timeDiff <= Double(timeWithin) && timeDiff >= Double(-timeWithin) { return (true, i)}
            
            if i == haystack.count - 1 { return (false, 0) }
            if timeDiff < Double(-timeWithin) { return (false, 0)}
            
        }
        
        return (false, 0 )
    }
    
    func findNextCarbTime(timeWithin: Int, needle: TimeInterval, haystack: [carbGraphStruct], startingIndex: Int) -> Bool {
        
        if startingIndex > haystack.count - 2 { return false }
        if haystack[startingIndex + 1].date -  needle < Double(timeWithin) {
            return true
        }

        return false
    }
    
    func findNextBolusTime(timeWithin: Int, needle: TimeInterval, haystack: [bolusGraphStruct], startingIndex: Int) -> Bool {
        
        var last = false
        var next = true
        if startingIndex > haystack.count - 2 { return false }
        if startingIndex == 0 { return false }
        
        // Nothing to right that requires shift
        if haystack[startingIndex + 1].date -  needle > Double(timeWithin) {
            return false
        } else {
            // Nothing to left preventing shift
            if needle - haystack[startingIndex - 1].date > Double(timeWithin) {
                return true
            }
        }
        
        return false
    }
    
}
