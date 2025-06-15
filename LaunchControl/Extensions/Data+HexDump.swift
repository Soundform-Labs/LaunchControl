//
//  Data+HexDump.swift
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

public extension Data {
    
    /// Returns a hexadecimal string representation of the data bytes.
    ///
    /// Each byte is converted to a two-character hex code with no spaces or delimiters.
    ///
    /// - Parameter uppercase: Determines whether the hex digits are uppercase (`true`) or
    ///                        lowercase (`false`). Defaults to `true`.
    /// - Returns: A continuous hex string representing the data bytes, e.g. `"0A1B2C3D"`.
    func hexString(uppercase: Bool = true) -> String {
        let format = uppercase ? "%02X" : "%02x"
        return self.map { String(format: format, $0) }.joined()
    }
    
    /// Generates a formatted multi-line hex dump of the data.
    ///
    /// Each line includes:
    /// - The offset of the first byte in that line, printed as an 8-digit hexadecimal number.
    /// - Hexadecimal byte values grouped in blocks of four bytes for readability.
    /// - An ASCII representation on the right, where printable ASCII characters are shown as-is, and non-printable bytes are replaced by a placeholder (`.`).
    ///
    /// This is similar to the output from common hex dump tools, useful for debugging binary data.
    ///
    /// - Parameter bpl: Bytes per line; determines how many bytes are displayed on each line. Defaults to 16, which is a common convention.
    /// - Returns: A string containing the full formatted hex dump, suitable for printing or logging.
    ///
    /// Example output for `bpl = 16`:
    /// ```
    /// 00000000  48 65 6C 6C  6F 2C 20 57  6F 72 6C 64  21 00 01 02  |Hello, World!...|
    /// 00000010  03 04 05 06  07 08 09 0A  0B 0C 0D 0E  0F 10 11 12  |................|
    /// ```
    func formattedHexDump(bpl: Int = 16) -> String {
        var output = ""
        let asciiPlaceholder: Character = "."
        
        for lineStart in stride(from: 0, to: self.count, by: bpl) {
            let lineEnd = Swift.min(lineStart + bpl, self.count)
            let lineBytes = self[lineStart..<lineEnd]
            
            output += String(format: "%08X  ", lineStart)
            
            for (index, byte) in lineBytes.enumerated() {
                if index > 0 && index % 4 == 0 {
                    output += " "
                }
                output += String(format: "%02X ", byte)
            }
            
            let hexSelectionLength = bpl * 3 + (bpl / 4 - 1)
            if lineBytes.count < bpl {
                let paddingCount = hexSelectionLength - (lineBytes.count * 3 + (lineBytes.count - 1) / 4)
                output += String(repeating: " ", count: paddingCount)
            }
            
            output += " |"
            for byte in lineBytes {
                if byte >= 0x20 && byte <= 0x7E {
                    output.append(Character(UnicodeScalar(byte)))
                } else {
                    output.append(asciiPlaceholder)
                }
            }
            output += "|\n"
        }
        
        return output
    }
}
