//
//  LCLaunchpadPro.swift
//  LaunchControl
//
//  Copyright (c) 2025 - Soundform Labs. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

struct LCLaunchpadPro: LCLaunchpadDevice {
    let modelName = "Launchpad Pro"
    let padCount = 64
    let midiChannel: UInt8 = 1
    var supportsVelocity = true
    var supportsRGB = true
    
    func handleMIDIMessage(_ data: [UInt8]) {}
    
    func midiNote(forPad index: Int) -> UInt8? {
        return UInt8(index + 1)
    }
    
    func sendColor(forPad index: Int, red: UInt8, green: UInt8, blue: UInt8) {}
}
