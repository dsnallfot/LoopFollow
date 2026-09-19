//
//  ViewControllerManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-27.

//

import Foundation
import UIKit

class ViewControllerManager {

    static let shared = ViewControllerManager()

    var alarmViewController: AlarmUIRefreshing?

    private init() {
        alarmViewController = ModernAlarmViewController()
    }
}
