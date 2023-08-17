//
//  Token+URL.swift
//  OneTimePassword
//
//  Copyright (c) 2014-2018 Matt Rubin and the OneTimePassword authors
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
//import Base32

public extension Token {
    // MARK: Serialization

    /// Serializes the token to a URL.
    func toURL() throws -> URL {
        return try urlForToken(
            name: name,
            issuer: issuer,
            factor: generator.factor,
            algorithm: generator.algorithm,
            digits: generator.digits
        )
    }

    /// Attempts to initialize a token represented by the given URL.
    ///
    /// - throws: A `DeserializationError` if a token could not be built from the given parameters.
    /// - returns: A `Token` built from the given URL and secret.
    init(url: URL, secret: Data? = nil) throws {
        self = try token(from: url, secret: secret)
    }
}

internal enum SerializationError: Swift.Error {
    case urlGenerationFailure
}

internal enum DeserializationError: Swift.Error {
    case invalidURLScheme
    case duplicateQueryItem(String)
    case missingFactor
    case invalidFactor(String)
    case invalidCounterValue(String)
    case invalidTimerPeriod(String)
    case missingSecret
    case invalidSecret(String)
    case invalidAlgorithm(String)
    case invalidDigits(String)
}

private let defaultAlgorithm: Generator.Algorithm = .sha1
private let defaultDigits: Int = 6
private let defaultCounter: UInt64 = 0
private let defaultPeriod: TimeInterval = 30

private let kOTPAuthScheme = "otpauth"
private let kQueryAlgorithmKey = "algorithm"
private let kQuerySecretKey = "secret"
private let kQueryCounterKey = "counter"
private let kQueryDigitsKey = "digits"
private let kQueryPeriodKey = "period"
private let kQueryIssuerKey = "issuer"

private let kFactorCounterKey = "hotp"
private let kFactorTimerKey = "totp"

private let kAlgorithmSHA1   = "SHA1"
private let kAlgorithmSHA256 = "SHA256"
private let kAlgorithmSHA512 = "SHA512"

private func stringForAlgorithm(_ algorithm: Generator.Algorithm) -> String {
    switch algorithm {
    case .sha1:
        return kAlgorithmSHA1
    case .sha256:
        return kAlgorithmSHA256
    case .sha512:
        return kAlgorithmSHA512
    }
}

private func algorithmFromString(_ string: String) throws -> Generator.Algorithm {
    switch string {
    case kAlgorithmSHA1:
        return .sha1
    case kAlgorithmSHA256:
        return .sha256
    case kAlgorithmSHA512:
        return .sha512
    default:
        throw DeserializationError.invalidAlgorithm(string)
    }
}

private func urlForToken(name: String, issuer: String, factor: Generator.Factor, algorithm: Generator.Algorithm, digits: Int) throws -> URL {
    var urlComponents = URLComponents()
    urlComponents.scheme = kOTPAuthScheme
    urlComponents.path = "/" + name

    var queryItems = [
        URLQueryItem(name: kQueryAlgorithmKey, value: stringForAlgorithm(algorithm)),
        URLQueryItem(name: kQueryDigitsKey, value: String(digits)),
        URLQueryItem(name: kQueryIssuerKey, value: issuer),
    ]

    switch factor {
    case .timer(let period):
        urlComponents.host = kFactorTimerKey
        queryItems.append(URLQueryItem(name: kQueryPeriodKey, value: String(Int(period))))
    case .counter(let counter):
        urlComponents.host = kFactorCounterKey
        queryItems.append(URLQueryItem(name: kQueryCounterKey, value: String(counter)))
    }

    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
        throw SerializationError.urlGenerationFailure
    }
    return url
}

private func token(from url: URL, secret externalSecret: Data? = nil) throws -> Token {
    guard url.scheme == kOTPAuthScheme else {
        throw DeserializationError.invalidURLScheme
    }

    let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

    let factor: Generator.Factor
    switch url.host {
    case .some(kFactorCounterKey):
        let counterValue = try queryItems.value(for: kQueryCounterKey).map(parseCounterValue) ?? defaultCounter
        factor = .counter(counterValue)
    case .some(kFactorTimerKey):
        let period = try queryItems.value(for: kQueryPeriodKey).map(parseTimerPeriod) ?? defaultPeriod
        factor = .timer(period: period)
    case let .some(rawValue):
        throw DeserializationError.invalidFactor(rawValue)
    case .none:
        throw DeserializationError.missingFactor
    }

    let algorithm = try queryItems.value(for: kQueryAlgorithmKey).map(algorithmFromString) ?? defaultAlgorithm
    let digits = try queryItems.value(for: kQueryDigitsKey).map(parseDigits) ?? defaultDigits
    guard let secret = try externalSecret ?? queryItems.value(for: kQuerySecretKey).map(parseSecret) else {
        throw DeserializationError.missingSecret
    }
    let generator = try Generator(factor: factor, secret: secret, algorithm: algorithm, digits: digits)

    // Skip the leading "/"
    let fullName = String(url.path.dropFirst())

    let issuer: String
    if let issuerString = try queryItems.value(for: kQueryIssuerKey) {
        issuer = issuerString
    } else if let separatorRange = fullName.range(of: ":") {
        // If there is no issuer string, try to extract one from the name
        issuer = String(fullName[..<separatorRange.lowerBound])
    } else {
        // The default value is an empty string
        issuer = ""
    }

    // If the name is prefixed by the issuer string, trim the name
    let name = shortName(byTrimming: issuer, from: fullName)

    return Token(name: name, issuer: issuer, generator: generator)
}

private func parseCounterValue(_ rawValue: String) throws -> UInt64 {
    guard let counterValue = UInt64(rawValue) else {
        throw DeserializationError.invalidCounterValue(rawValue)
    }
    return counterValue
}

private func parseTimerPeriod(_ rawValue: String) throws -> TimeInterval {
    guard let period = TimeInterval(rawValue) else {
        throw DeserializationError.invalidTimerPeriod(rawValue)
    }
    return period
}

private func parseSecret(_ rawValue: String) throws -> Data {
    guard let secret = PTNBase32Codec.data(from: rawValue) else {
        throw DeserializationError.invalidSecret(rawValue)
    } //try Base32.decode(rawValue)
    return secret
//    do {
//        let secret = PTNBase32Codec.data(from: rawValue) //try Base32.decode(rawValue)
//        return secret
//    } catch {
//        throw DeserializationError.invalidSecret(rawValue)
//    }
}

private func parseDigits(_ rawValue: String) throws -> Int {
    guard let digits = Int(rawValue) else {
        throw DeserializationError.invalidDigits(rawValue)
    }
    return digits
}

private func shortName(byTrimming issuer: String, from fullName: String) -> String {
    if !issuer.isEmpty {
        let prefix = issuer + ":"
        if fullName.hasPrefix(prefix), let prefixRange = fullName.range(of: prefix) {
            let substringAfterSeparator = fullName[prefixRange.upperBound...]
            return substringAfterSeparator.trimmingCharacters(in: CharacterSet.whitespaces)
        }
    }
    return String(fullName)
}

extension Array where Element == URLQueryItem {
    func value(for name: String) throws -> String? {
        let matchingQueryItems = self.filter({
            $0.name == name
        })
        guard matchingQueryItems.count <= 1 else {
            throw DeserializationError.duplicateQueryItem(name)
        }
        return matchingQueryItems.first?.value
    }
}


public final class PTNBase32Codec {
   public static func data(from base32StringEncoded: String) -> Data? {
        let decodingTable: [UInt8] = [
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0x00 - 0x0F
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0x10 - 0x1F
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0x20 - 0x2F
            255,255,26,27,28,29,30,31,255,255,255,255,255,0,255,255,  // 0x30 - 0x3F
            255,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,  // 0x40 - 0x4F
            15,16,17,18,19,20,21,22,23,24,25,255,255,255,255,255,  // 0x50 - 0x5F
            255,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,  // 0x60 - 0x6F
            15,16,17,18,19,20,21,22,23,24,25,255,255,255,255,255,  // 0x70 - 0x7F
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0x80 - 0x8F
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0x90 - 0x9F
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0xA0 - 0xAF
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0xB0 - 0xBF
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0xC0 - 0xCF
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0xD0 - 0xDF
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,  // 0xE0 - 0xEF
            255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255   // 0xF0 - 0xFF
        ]
        
        let paddingAdjustment: [Int] = [0, 1, 1, 1, 2, 3, 3, 4]

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
       print("debug | before decodedBytes:\(decodedBytes)")
        print("debug | expectedDataLength:\(expectedDataLength)")

        var encodedByte1: UInt8 = 0, encodedByte2: UInt8 = 0, encodedByte3: UInt8 = 0, encodedByte4: UInt8 = 0
        var encodedByte5: UInt8 = 0, encodedByte6: UInt8 = 0, encodedByte7: UInt8 = 0, encodedByte8: UInt8 = 0
        var encodedBytesToProcess = encodedLength
        var encodedBaseIndex = 0
        var decodedBaseIndex = 0
        var encodedBlock: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
        var encodedBlockIndex = 0
        var c: UInt8
        print("debug | encodedBytesToProcess:\(encodedBytesToProcess)")


        while encodedBytesToProcess >= 1 {
            encodedBytesToProcess -= 1

            print("debug | encodedBytesToProcess in the loop:\(encodedBytesToProcess)")

            c = encodedBytes[encodedBaseIndex]
            print("debug | c in the loop:\(c)")

            encodedBaseIndex += 1
            if c == 61 { // ASCII value of '='
                break // padding...
            }
            c = decodingTable[Int(c)]
            if c == 255 {
                continue
            }
            encodedBlock[encodedBlockIndex] = c
            encodedBlockIndex += 1
            if encodedBlockIndex == 8 {
                print("debug | encodedBlock in the loop:\(encodedBlock)")
                let se = String(bytes: encodedBlock, encoding: .ascii)
                print("debug|  encodedBlock decoded: \(se)")
                encodedByte1 = encodedBlock[0]
                encodedByte2 = encodedBlock[1]
                encodedByte3 = encodedBlock[2]
                encodedByte4 = encodedBlock[3]
                encodedByte5 = encodedBlock[4]
                encodedByte6 = encodedBlock[5]
                encodedByte7 = encodedBlock[6]
                encodedByte8 = encodedBlock[7]
                
                
                
                decodedBytes[decodedBaseIndex] = ((encodedByte1 << 3) & 0xF8) | ((encodedByte2 >> 2) & 0x07)
                decodedBytes[decodedBaseIndex+1] = ((encodedByte2 << 6) & 0xC0) | ((encodedByte3 << 1) & 0x3E) | ((encodedByte4 >> 4) & 0x01)
                decodedBytes[decodedBaseIndex+2] = ((encodedByte4 << 4) & 0xF0) | ((encodedByte5 >> 1) & 0x0F)
                decodedBytes[decodedBaseIndex+3] = ((encodedByte5 << 7) & 0x80) | ((encodedByte6 << 2) & 0x7C) | ((encodedByte7 >> 3) & 0x03)
                decodedBytes[decodedBaseIndex+4] = ((encodedByte7 << 5) & 0xE0) | (encodedByte8 & 0x1F)
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
        print("debug |  encodedBlockIndex before switch \(encodedBlockIndex)")

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
            decodedBytes[decodedBaseIndex+1] = ((encodedByte2 << 6) & 0xC0) | ((encodedByte3 << 1) & 0x3E) | ((encodedByte4 >> 4) & 0x01)
            decodedBytes[decodedBaseIndex+2] = ((encodedByte4 << 4) & 0xF0) | ((encodedByte5 >> 1) & 0x0F)
            decodedBytes[decodedBaseIndex+3] = ((encodedByte5 << 7) & 0x80) | ((encodedByte6 << 2) & 0x7C) | ((encodedByte7 >> 3) & 0x03)
            decodedBytes[decodedBaseIndex+4] = ((encodedByte7 << 5) & 0xE0)
        }
        decodedBaseIndex += paddingAdjustment[encodedBlockIndex]
        
        print("debug|  decodedBaseIndex: \(decodedBaseIndex)")
        let s = String(bytes: decodedBytes, encoding: .ascii)
        print("debug|  decodedBytes: \(s)")

        let data = Data(bytes: decodedBytes, count: decodedBaseIndex)
        
        return data
    }
    
//   public static func base32String(from data: Data) -> String? {
//        let encodingTable: [UInt8] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
//        let paddingTable: [UInt] = [0, 6, 4, 3, 1]
//        let dataLength = data.count
//        var encodedBlocks = dataLength / 5
//        if (encodedBlocks + 1) >= (UInt.max / 8) {
//            return nil // NSUInteger overflow check
//        }
//
//        var padding = paddingTable[dataLength % 5]
//        if padding > 0 {
//            encodedBlocks += 1
//        }
//       let encodedLength = encodedBlocks * 8
//
//        var encodingBytes = [UInt8](repeating: 0, count: encodedLength)
//        var rawBytesToProcess = dataLength
//        var rawBaseIndex = 0
//        var encodingBaseIndex = 0
//        let rawBytes = [UInt8](data)
//        var rawByte1: UInt8 = 0, rawByte2: UInt8 = 0, rawByte3: UInt8 = 0, rawByte4: UInt8 = 0, rawByte5: UInt8 = 0
//
//        while( rawBytesToProcess >= 5 ) {
//            rawByte1 = rawBytes[rawBaseIndex];
//            rawByte2 = rawBytes[rawBaseIndex+1];
//            rawByte3 = rawBytes[rawBaseIndex+2];
//            rawByte4 = rawBytes[rawBaseIndex+3];
//            rawByte5 = rawBytes[rawBaseIndex+4];
//            encodingBytes[encodingBaseIndex] = encodingTable[Int((rawByte1 >> 3) & 0x1F)];
//            encodingBytes[encodingBaseIndex+1] = encodingTable[Int((rawByte1 << 2) & 0x1C) | Int((rawByte2 >> 6) & 0x03) ];
//            encodingBytes[encodingBaseIndex+2] = encodingTable[Int((rawByte2 >> 1) & 0x1F)];
//            encodingBytes[encodingBaseIndex+3] = encodingTable[Int((rawByte2 << 4) & 0x10) | Int((rawByte3 >> 4) & 0x0F)];
//            encodingBytes[encodingBaseIndex+4] = encodingTable[Int((rawByte3 << 1) & 0x1E) | Int((rawByte4 >> 7) & 0x01)];
//            encodingBytes[encodingBaseIndex+5] = encodingTable[Int((rawByte4 >> 2) & 0x1F)];
//            encodingBytes[encodingBaseIndex+6] = encodingTable[Int((rawByte4 << 3) & 0x18) | Int((rawByte5 >> 5) & 0x07)];
//            encodingBytes[encodingBaseIndex+7] = encodingTable[Int(rawByte5 & 0x1F)];
//
//            rawBaseIndex += 5;
//            encodingBaseIndex += 8;
//            rawBytesToProcess -= 5;
//        }
//
//        rawByte4 = 0
//        rawByte3 = 0
//        rawByte2 = 0
//
//        switch (dataLength-rawBaseIndex) {
//            case 4:
//                rawByte4 = rawBytes[rawBaseIndex+3];
//            case 3:
//                rawByte3 = rawBytes[rawBaseIndex+2];
//            case 2:
//                rawByte2 = rawBytes[rawBaseIndex+1];
//            case 1:
//                rawByte1 = rawBytes[rawBaseIndex];
//                encodingBytes[encodingBaseIndex] = encodingTable[Int((rawByte1 >> 3) & 0x1F)];
//                encodingBytes[encodingBaseIndex+1] = encodingTable[Int((rawByte1 << 2) & 0x1C) | Int((rawByte2 >> 6) & 0x03) ];
//                encodingBytes[encodingBaseIndex+2] = encodingTable[Int((rawByte2 >> 1) & 0x1F)];
//                encodingBytes[encodingBaseIndex+3] = encodingTable[Int((rawByte2 << 4) & 0x10) | Int((rawByte3 >> 4) & 0x0F)];
//                encodingBytes[encodingBaseIndex+4] = encodingTable[Int((rawByte3 << 1) & 0x1E) | Int((rawByte4 >> 7) & 0x01)];
//                encodingBytes[encodingBaseIndex+5] = encodingTable[Int((rawByte4 >> 2) & 0x1F)];
//                encodingBytes[encodingBaseIndex+6] = encodingTable[Int((rawByte4 << 3) & 0x18)];
//                // we can skip rawByte5 since we have a partial block it would always be 0
//                break;
//        default:
//            break
//        }
//
//        encodingBaseIndex = encodedLength - Int(padding);
//        while( padding > 0 ) {
//            padding -= 1
//            encodingBytes[encodingBaseIndex] = UInt8(ascii: "=");
//            encodingBaseIndex += 1
//        }
//
//        return String(bytes: encodingBytes, encoding: String.Encoding.ascii)
//    }
//
    
   public static func base32String(from data: Data) -> String? {
       var encoding: String? = nil
       var encodingBytes: UnsafeMutablePointer<UInt8>? = nil
       
//       do {
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
//       } catch {
//           encoding = nil
//           print("WARNING: error occurred while trying to encode base 32 data: \(error)")
//       }
       
       if let encodingBytes = encodingBytes {
           encodingBytes.deallocate()
       }
       
       return encoding
   }


}
