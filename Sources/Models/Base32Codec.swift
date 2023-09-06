//
//  Base32Codec.swift
//
//
//  Created by martin on 05/09/2023.
//

import Foundation

// swiftlint:disable cyclomatic_complexity fallthrough
public enum Base32Codec {
    private static let decodingTable: [UInt8] = [
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0x00 - 0x0F
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0x10 - 0x1F
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0x20 - 0x2F
        255, 255, 26, 27, 28, 29, 30, 31, 255, 255, 255, 255, 255, 0, 255, 255,  // 0x30 - 0x3F
        255, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,  // 0x40 - 0x4F
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 255, 255, 255, 255, 255,  // 0x50 - 0x5F
        255, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,  // 0x60 - 0x6F
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 255, 255, 255, 255, 255,  // 0x70 - 0x7F
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0x80 - 0x8F
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0x90 - 0x9F
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0xA0 - 0xAF
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0xB0 - 0xBF
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0xC0 - 0xCF
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0xD0 - 0xDF
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,  // 0xE0 - 0xEF
        255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255   // 0xF0 - 0xFF
    ]
    
    private static let paddingAdjustment: [Int] = [0, 1, 1, 1, 2, 3, 3, 4]
    
    public static func data(from base32StringEncoded: String) -> Data? {
        let encoding = base32StringEncoded.replacingOccurrences(of: "=", with: "")
        guard let encodedData = encoding.data(using: .ascii) else {
            return nil
        }
        let encodedBytes = [UInt8](encodedData)
        let encodedLength = encodedData.count
        if encodedLength >= (UInt.max - 7) {
            return nil // NSUInteger overflow check
        }
        let encodedBlocks = (encodedLength + 7) >> 3
        let expectedDataLength = encodedBlocks * 5

        var decodedBytes = [UInt8](repeating: 0, count: expectedDataLength)

        var encodedByte1: UInt8 = 0, encodedByte2: UInt8 = 0, encodedByte3: UInt8 = 0, encodedByte4: UInt8 = 0
        var encodedByte5: UInt8 = 0, encodedByte6: UInt8 = 0, encodedByte7: UInt8 = 0, encodedByte8: UInt8 = 0
        var encodedBytesToProcess = encodedLength
        var encodedBaseIndex = 0
        var decodedBaseIndex = 0
        var encodedBlock = [UInt8](repeating: 0, count: 8)
        var encodedBlockIndex = 0
        var char: UInt8

        while encodedBytesToProcess >= 1 {
            encodedBytesToProcess -= 1

            char = encodedBytes[encodedBaseIndex]

            encodedBaseIndex += 1
            if char == 61 { // ASCII value of '='
                break // padding...
            }
            char = decodingTable[Int(char)]
            if char == 255 {
                continue
            }
            encodedBlock[encodedBlockIndex] = char
            encodedBlockIndex += 1
            if encodedBlockIndex == 8 {
                encodedByte1 = encodedBlock[0]
                encodedByte2 = encodedBlock[1]
                encodedByte3 = encodedBlock[2]
                encodedByte4 = encodedBlock[3]
                encodedByte5 = encodedBlock[4]
                encodedByte6 = encodedBlock[5]
                encodedByte7 = encodedBlock[6]
                encodedByte8 = encodedBlock[7]

                decodedBytes[decodedBaseIndex] = ((encodedByte1 << 3) & 0xF8) | ((encodedByte2 >> 2) & 0x07)
                decodedBytes[decodedBaseIndex + 1] = ((encodedByte2 << 6) & 0xC0) | ((encodedByte3 << 1) & 0x3E) | ((encodedByte4 >> 4) & 0x01)
                decodedBytes[decodedBaseIndex + 2] = ((encodedByte4 << 4) & 0xF0) | ((encodedByte5 >> 1) & 0x0F)
                decodedBytes[decodedBaseIndex + 3] = ((encodedByte5 << 7) & 0x80) | ((encodedByte6 << 2) & 0x7C) | ((encodedByte7 >> 3) & 0x03)
                decodedBytes[decodedBaseIndex + 4] = ((encodedByte7 << 5) & 0xE0) | (encodedByte8 & 0x1F)
                decodedBaseIndex += 5
                encodedBlockIndex = 0
            }
        }

        encodedByte7 = 0
        encodedByte6 = 0
        encodedByte5 = 0
        encodedByte4 = 0
        encodedByte3 = 0
        encodedByte2 = 0

        if encodedBlockIndex == 7 {
            encodedByte7 = encodedBlock[6]
        }
        if encodedBlockIndex >= 6 {
            encodedByte6 = encodedBlock[5]
        }
        if encodedBlockIndex >= 5 {
            encodedByte5 = encodedBlock[4]
        }
        if encodedBlockIndex >= 4 {
            encodedByte4 = encodedBlock[3]
        }

        if encodedBlockIndex >= 3 {
            encodedByte3 = encodedBlock[2]
        }

        if encodedBlockIndex >= 2 {
            encodedByte2 = encodedBlock[1]
        }

        if encodedBlockIndex >= 1 {
            encodedByte1 = encodedBlock[0]
            decodedBytes[decodedBaseIndex] = ((encodedByte1 << 3) & 0xF8) | ((encodedByte2 >> 2) & 0x07)
            decodedBytes[decodedBaseIndex + 1] = ((encodedByte2 << 6) & 0xC0) | ((encodedByte3 << 1) & 0x3E) | ((encodedByte4 >> 4) & 0x01)
            decodedBytes[decodedBaseIndex + 2] = ((encodedByte4 << 4) & 0xF0) | ((encodedByte5 >> 1) & 0x0F)
            decodedBytes[decodedBaseIndex + 3] = ((encodedByte5 << 7) & 0x80) | ((encodedByte6 << 2) & 0x7C) | ((encodedByte7 >> 3) & 0x03)
            decodedBytes[decodedBaseIndex + 4] = ((encodedByte7 << 5) & 0xE0)
        }
        decodedBaseIndex += paddingAdjustment[encodedBlockIndex]

        let data = Data(bytes: decodedBytes, count: decodedBaseIndex)

        return data
    }
    
    public static func base32String(from data: Data) -> String? {
        var encoding: String?
        var encodingBytes: UnsafeMutablePointer<UInt8>?
        
        let encodingTable: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
        let paddingTable: [Int] = [0, 6, 4, 3, 1]
        
        let dataLength = data.count
        let encodedBlocks = dataLength / 5
        if (encodedBlocks + 1) >= (UInt.max / 8) { return nil }
        let padding = paddingTable[dataLength % 5]
        var encodedLength = encodedBlocks * 8
        if padding > 0 { encodedLength += 8 }
        
        encodingBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: encodedLength)
        encodingBytes?.initialize(repeating: 0, count: encodedLength)
        
        if let encodingBytes = encodingBytes {
            var rawBytesToProcess = dataLength
            var rawBaseIndex = 0
            var encodingBaseIndex = 0
            let rawBytes = [UInt8](data)
            var rawByte1, rawByte2, rawByte3, rawByte4, rawByte5: UInt8
            
            while rawBytesToProcess >= 5 {
                rawByte1 = rawBytes[rawBaseIndex]
                rawByte2 = rawBytes[rawBaseIndex + 1]
                rawByte3 = rawBytes[rawBaseIndex + 2]
                rawByte4 = rawBytes[rawBaseIndex + 3]
                rawByte5 = rawBytes[rawBaseIndex + 4]
                encodingBytes[encodingBaseIndex] = encodingTable[Int((rawByte1 >> 3) & 0x1F)]
                encodingBytes[encodingBaseIndex + 1] = encodingTable[Int(((rawByte1 << 2) & 0x1C) | ((rawByte2 >> 6) & 0x03))]
                encodingBytes[encodingBaseIndex + 2] = encodingTable[Int((rawByte2 >> 1) & 0x1F)]
                encodingBytes[encodingBaseIndex + 3] = encodingTable[Int(((rawByte2 << 4) & 0x10) | ((rawByte3 >> 4) & 0x0F))]
                encodingBytes[encodingBaseIndex + 4] = encodingTable[Int(((rawByte3 << 1) & 0x1E) | ((rawByte4 >> 7) & 0x01))]
                encodingBytes[encodingBaseIndex + 5] = encodingTable[Int((rawByte4 >> 2) & 0x1F)]
                encodingBytes[encodingBaseIndex + 6] = encodingTable[Int(((rawByte4 << 3) & 0x18) | ((rawByte5 >> 5) & 0x07))]
                encodingBytes[encodingBaseIndex + 7] = encodingTable[Int(rawByte5 & 0x1F)]
                
                rawBaseIndex += 5
                encodingBaseIndex += 8
                rawBytesToProcess -= 5
            }
            
            rawByte4 = 0
            rawByte3 = 0
            rawByte2 = 0
            
            switch dataLength - rawBaseIndex {
            case 4:
                rawByte4 = rawBytes[rawBaseIndex + 3]
                fallthrough
            case 3:
                rawByte3 = rawBytes[rawBaseIndex + 2]
                fallthrough
            case 2:
                rawByte2 = rawBytes[rawBaseIndex + 1]
                fallthrough
            case 1:
                rawByte1 = rawBytes[rawBaseIndex]
                encodingBytes[encodingBaseIndex] = encodingTable[Int((rawByte1 >> 3) & 0x1F)]
                encodingBytes[encodingBaseIndex + 1] = encodingTable[Int(((rawByte1 << 2) & 0x1C) | ((rawByte2 >> 6) & 0x03))]
                encodingBytes[encodingBaseIndex + 2] = encodingTable[Int((rawByte2 >> 1) & 0x1F)]
                encodingBytes[encodingBaseIndex + 3] = encodingTable[Int(((rawByte2 << 4) & 0x10) | ((rawByte3 >> 4) & 0x0F))]
                encodingBytes[encodingBaseIndex + 4] = encodingTable[Int(((rawByte3 << 1) & 0x1E) | ((rawByte4 >> 7) & 0x01))]
                encodingBytes[encodingBaseIndex + 5] = encodingTable[Int((rawByte4 >> 2) & 0x1F)]
                encodingBytes[encodingBaseIndex + 6] = encodingTable[Int((rawByte4 << 3) & 0x18)]
            default:
                break
            }
            
            encodingBaseIndex = encodedLength - padding
            var currentPadding = padding
            while currentPadding > 0 {
                encodingBytes[encodingBaseIndex] = UInt8(ascii: "=")
                encodingBaseIndex += 1
                currentPadding -= 1
            }
            
            if let encodedString = String(bytesNoCopy: encodingBytes, length: encodedLength, encoding: .ascii, freeWhenDone: false) {
                encoding = String(encodedString)
            }
        }
        
        if let encodingBytes = encodingBytes {
            encodingBytes.deallocate()
        }
        
        return encoding
    }
}
// swiftlint:enable cyclomatic_complexity fallthrough
