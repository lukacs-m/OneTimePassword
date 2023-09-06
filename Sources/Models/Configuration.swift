//
//  Configuration.swift
//
//
//  Created by martin on 06/09/2023.
//

import Foundation

enum Configuration {
    static let defaultAlgorithm: Generator.Algorithm = .sha1
    static let defaultDigits: Int = 6
    static let defaultCounter: UInt64 = 0
    static let defaultPeriod: TimeInterval = 30
    
    static let kOTPAuthScheme = "otpauth"
    static let kQueryAlgorithmKey = "algorithm"
    static let kQuerySecretKey = "secret"
    static let kQueryCounterKey = "counter"
    static let kQueryDigitsKey = "digits"
    static let kQueryPeriodKey = "period"
    static let kQueryIssuerKey = "issuer"
    
    static let kFactorCounterKey = "hotp"
    static let kFactorTimerKey = "totp"
    
    static let kAlgorithmSHA1   = "SHA1"
    static let kAlgorithmSHA256 = "SHA256"
    static let kAlgorithmSHA512 = "SHA512"
    
    static let urlStringEncoding = String.Encoding.utf8
    static let kOTPService = "me.mattrubin.onetimepassword.token"

//    static func stringForAlgorithm(_ algorithm: Generator.Algorithm) -> String {
//        switch algorithm {
//        case .sha1:
//            return kAlgorithmSHA1
//        case .sha256:
//            return kAlgorithmSHA256
//        case .sha512:
//            return kAlgorithmSHA512
//        }
//    }
}
