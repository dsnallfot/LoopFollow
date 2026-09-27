//
//  Stats.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/23/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation


class StatsData {
    
    var countVeryLow: Int
    var countLow: Int
    var countRange: Int
    var countHigh: Int
    var countVeryHigh: Int
    var percentVeryLow: Float
    var percentLow: Float
    var percentRange: Float
    var percentHigh: Float
    var percentVeryHigh: Float
    var totalGlucose: Int
    var avgBG: Float
    var a1C: Float
    var stdDev: Float
    var bgDataCount: Int
    var pie: [DataStructs.pieData]
    
    init(bgData: [ShareGlucoseData]) {
        
        self.countVeryLow = 0
        self.countLow = 0
        self.countRange = 0
        self.countHigh = 0
        self.countVeryHigh = 0
        self.totalGlucose = 0
        self.a1C = 0.0
        
        for i in 0..<bgData.count {
            // Set low/range/high counts for pie chart and %'s
            if Float(bgData[i].sgv) < 54 {
                self.countVeryLow += 1
            } else if Float(bgData[i].sgv) < UserDefaultsRepository.lowLine.value {
                self.countLow += 1
            } else if Float(bgData[i].sgv) > 250 {
                self.countVeryHigh += 1
            } else if Float(bgData[i].sgv) > UserDefaultsRepository.highLine.value {
                self.countHigh += 1
            } else {
                self.countRange += 1
            }
            
            // set total bg for average
            totalGlucose += bgData[i].sgv
        }
        
        // Set Percents
        percentVeryLow = Float(countVeryLow) / Float(bgData.count) * 100
        percentLow = Float(countLow) / Float(bgData.count) * 100
        percentRange = Float(countRange) / Float(bgData.count) * 100
        percentHigh = Float(countHigh) / Float(bgData.count) * 100
        percentVeryHigh = Float(countVeryHigh) / Float(bgData.count) * 100
        
        pie = [
            DataStructs.pieData(name: "veryLow", value: Double(percentVeryLow)),
            DataStructs.pieData(name: "low", value: Double(percentLow)),
            DataStructs.pieData(name: "range", value: Double(percentRange)),
            DataStructs.pieData(name: "high", value: Double(percentHigh)),
            DataStructs.pieData(name: "veryHigh", value: Double(percentVeryHigh))
        ]

        // Set Average
        bgDataCount = bgData.count
        if bgDataCount < 1 { bgDataCount = 1 }
        avgBG = Float(totalGlucose / bgDataCount)

        // compute std dev (sigma)
        var partialSum: Float = 0;
        for i in 0..<bgData.count {
            partialSum += (Float(bgData[i].sgv) - avgBG) * ( Float(bgData[i].sgv) - avgBG)
        }
        
        stdDev = sqrt(partialSum / Float(bgData.count))
        if UserDefaultsRepository.units.value != "mg/dL" {
            stdDev = stdDev * Float(GlucoseConversion.mgDlToMmolL)
        }
        
        if UserDefaultsRepository.useIFCC.value {
            a1C = (((46.7 + Float(avgBG)) / 28.7) - 2.152) / 0.09148
        } else {
            a1C = (46.7 + Float(avgBG)) / 28.7
        }
    }
}
