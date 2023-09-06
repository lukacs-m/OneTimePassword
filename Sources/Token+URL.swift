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

public extension Token {
    // MARK: Serialization
    
    /// Serializes the token to a URL.
    func toURL() throws -> URL {
        try urlForToken(
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
        self = try Self.token(from: url, secret: secret)
    }
}

private extension Token {
     func urlForToken(name: String, issuer: String, factor: Generator.Factor, algorithm: Generator.Algorithm, digits: Int) throws -> URL {
        var urlComponents = URLComponents()
         urlComponents.scheme = Configuration.kOTPAuthScheme
        urlComponents.path = "/" + name
        
        var queryItems = [
            URLQueryItem(name: Configuration.kQueryAlgorithmKey, value: Self.stringForAlgorithm(algorithm)),
            URLQueryItem(name: Configuration.kQueryDigitsKey, value: String(digits)),
            URLQueryItem(name: Configuration.kQueryIssuerKey, value: issuer)
        ]
        
        switch factor {
        case .timer(let period):
            urlComponents.host = Configuration.kFactorTimerKey
            queryItems.append(URLQueryItem(name: Configuration.kQueryPeriodKey, value: String(Int(period))))
        case .counter(let counter):
            urlComponents.host = Configuration.kFactorCounterKey
            queryItems.append(URLQueryItem(name: Configuration.kQueryCounterKey, value: String(counter)))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw SerializationError.urlGenerationFailure
        }
        return url
    }
    
   static func token(from url: URL, secret externalSecret: Data? = nil) throws -> Token {
        guard url.scheme == Configuration.kOTPAuthScheme else {
            throw DeserializationError.invalidURLScheme
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        let factor: Generator.Factor
        switch url.host {
        case .some(Configuration.kFactorCounterKey):
            let counterValue = try queryItems.value(for: Configuration.kQueryCounterKey).map(Self.parseCounterValue) ?? Configuration.defaultCounter
            factor = .counter(counterValue)
        case .some(Configuration.kFactorTimerKey):
            let period = try queryItems.value(for: Configuration.kQueryPeriodKey).map(Self.parseTimerPeriod) ?? Configuration.defaultPeriod
            factor = .timer(period: period)
        case let .some(rawValue):
            throw DeserializationError.invalidFactor(rawValue)
        case .none:
            throw DeserializationError.missingFactor
        }

       let algorithm = try queryItems.value(for: Configuration.kQueryAlgorithmKey)
           .map(Self.algorithmFromString) ?? Configuration.defaultAlgorithm
       let digits = try queryItems.value(for: Configuration.kQueryDigitsKey).map(Self.parseDigits) ?? Configuration.defaultDigits
       guard let secret = try externalSecret ?? queryItems.value(for: Configuration.kQuerySecretKey).map(Self.parseSecret) else {
            throw DeserializationError.missingSecret
        }
        let generator = try Generator(factor: factor, secret: secret, algorithm: algorithm, digits: digits)

        // Skip the leading "/"
        let fullName = String(url.path.dropFirst())

        let issuer: String
        if let issuerString = try queryItems.value(for: Configuration.kQueryIssuerKey) {
            issuer = issuerString
        } else if let separatorRange = fullName.range(of: ":") {
            // If there is no issuer string, try to extract one from the name
            issuer = String(fullName[..<separatorRange.lowerBound])
        } else {
            // The default value is an empty string
            issuer = ""
        }

        // If the name is prefixed by the issuer string, trim the name
       let name = Self.shortName(byTrimming: issuer, from: fullName)

        return Token(generator: generator, name: name, issuer: issuer)
    }
    
    static func algorithmFromString(_ string: String) throws -> Generator.Algorithm {
        switch string {
        case Configuration.kAlgorithmSHA1:
            return .sha1
        case Configuration.kAlgorithmSHA256:
            return .sha256
        case Configuration.kAlgorithmSHA512:
            return .sha512
        default:
            throw DeserializationError.invalidAlgorithm(string)
        }
    }
    
    static func stringForAlgorithm(_ algorithm: Generator.Algorithm) -> String {
        switch algorithm {
        case .sha1:
            return Configuration.kAlgorithmSHA1
        case .sha256:
            return Configuration.kAlgorithmSHA256
        case .sha512:
            return Configuration.kAlgorithmSHA512
        }
    }
    
    static func parseCounterValue(_ rawValue: String) throws -> UInt64 {
        guard let counterValue = UInt64(rawValue) else {
            throw DeserializationError.invalidCounterValue(rawValue)
        }
        return counterValue
    }
    
    static func parseDigits(_ rawValue: String) throws -> Int {
        guard let digits = Int(rawValue) else {
            throw DeserializationError.invalidDigits(rawValue)
        }
        return digits
    }
    
    static func parseTimerPeriod(_ rawValue: String) throws -> TimeInterval {
        guard let period = TimeInterval(rawValue) else {
            throw DeserializationError.invalidTimerPeriod(rawValue)
        }
        return period
    }
    
    static func parseSecret(_ rawValue: String) throws -> Data {
        guard let secret = Base32Codec.data(from: rawValue) else {
            throw DeserializationError.invalidSecret(rawValue)
        }
        return secret
    }
    
    static func shortName(byTrimming issuer: String, from fullName: String) -> String {
        if !issuer.isEmpty {
            let prefix = issuer + ":"
            if fullName.hasPrefix(prefix), let prefixRange = fullName.range(of: prefix) {
                let substringAfterSeparator = fullName[prefixRange.upperBound...]
                return substringAfterSeparator.trimmingCharacters(in: CharacterSet.whitespaces)
            }
        }
        return String(fullName)
    }
}

public enum SerializationError: Error {
    case urlGenerationFailure
}

public enum DeserializationError: Error {
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
