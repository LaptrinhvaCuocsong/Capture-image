//
//  DeviceOrientationHelper.swift
//  CapturePhoto
//
//  Created by Apple on 12/15/19.
//  Copyright © 2019 Apple. All rights reserved.
//

import Foundation
import CoreMotion
import UIKit

class DeviceOrientationHelper {
        
    var currentOrientation: UIDeviceOrientation = UIDevice.current.orientation
    
    private var motionManager: CMMotionManager?
    private let motionLimit = 0.65
    private let motionTime = 1.0 / 60.0
    private let queue = OperationQueue()
    
    init() {
        motionManager = CMMotionManager()
        motionManager?.accelerometerUpdateInterval = motionTime
    }
    
    func startObserverMotionUpdate() {
        motionManager?.startDeviceMotionUpdates(to: queue, withHandler: {[weak self] (motion, error) in
            guard let self = self else { return }
            
            guard error == nil else {
                print("Error: \(error!)")
                return
            }
            
            guard let motion = motion else { return }
            
            var newOrientation: UIDeviceOrientation?
            if motion.gravity.x > self.motionLimit {
                newOrientation = .landscapeRight
            }
            else if motion.gravity.x < -self.motionLimit {
                newOrientation = .landscapeLeft
            }
            else if motion.gravity.y > self.motionLimit {
                newOrientation = .portrait
            }
            else if motion.gravity.y < -self.motionLimit {
                newOrientation = .portraitUpsideDown
            }
            else if motion.gravity.z > self.motionLimit {
                newOrientation = .faceUp
            }
            else if motion.gravity.z < -self.motionLimit {
                newOrientation = .faceDown
            }
            else {}
            
            if let newOrientation = newOrientation, newOrientation != self.currentOrientation {
                self.currentOrientation = newOrientation
            }
        })
    }
 
    func stopObserverMotionUpdate() {
        motionManager?.stopDeviceMotionUpdates()
    }
    
}
