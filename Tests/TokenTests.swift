//
//  TokenTests.swift
//  OneTimePassword
//
//  Copyright (c) 2014-2019 Matt Rubin and the OneTimePassword authors
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

import XCTest
import OneTimePassword

class TokenTests: XCTestCase {
    let secretData = "12345678901234567890".data(using: String.Encoding.ascii)!
    let otherSecretData = "09876543210987654321".data(using: String.Encoding.ascii)!

    func testInit() throws {
        // Create a token
        let name = "Test Name"
        let issuer = "Test Issuer"
        let generator = try Generator(
            factor: .counter(111),
            secret: secretData,
            algorithm: .sha1,
            digits: 6
        )

        let token = Token(
            generator: generator,
            name: name,
            issuer: issuer
        )

        XCTAssertEqual(token.name, name)
        XCTAssertEqual(token.issuer, issuer)
        XCTAssertEqual(token.generator, generator)

        // Create another token
        let otherName = "Other Test Name"
        let otherIssuer = "Other Test Issuer"
        let otherGenerator = try Generator(
            factor: .timer(period: 123),
            secret: otherSecretData,
            algorithm: .sha512,
            digits: 8
        )

        let otherToken = Token(
            generator: otherGenerator,
            name: otherName,
            issuer: otherIssuer
        )

        XCTAssertEqual(otherToken.name, otherName)
        XCTAssertEqual(otherToken.issuer, otherIssuer)
        XCTAssertEqual(otherToken.generator, otherGenerator)

        // Ensure the tokens are different
        XCTAssertNotEqual(token.name, otherToken.name)
        XCTAssertNotEqual(token.issuer, otherToken.issuer)
        XCTAssertNotEqual(token.generator, otherToken.generator)
    }

    func testDefaults() throws {
        let generator = try Generator(
            factor: .counter(0),
            secret: Data(),
            algorithm: .sha1,
            digits: 6
        )
        let name = "Test Name"
        let issuer = "Test Issuer"

        let tokenWithDefaultName = Token(generator: generator, issuer: issuer)
        XCTAssertEqual(tokenWithDefaultName.name, "")
        XCTAssertEqual(tokenWithDefaultName.issuer, issuer)

        let tokenWithDefaultIssuer = Token(generator: generator, name: name)
        XCTAssertEqual(tokenWithDefaultIssuer.name, name)
        XCTAssertEqual(tokenWithDefaultIssuer.issuer, "")

        let tokenWithAllDefaults = Token(generator: generator)
        XCTAssertEqual(tokenWithAllDefaults.name, "")
        XCTAssertEqual(tokenWithAllDefaults.issuer, "")
    }

    func testCurrentPassword() throws {
        let timerGenerator = try Generator(
            factor: .timer(period: 30),
            secret: secretData,
            algorithm: .sha1,
            digits: 6
        )
        let timerToken = Token(generator: timerGenerator)

        do {
            let password = try timerToken.generator.password(at: Date())
            XCTAssertEqual(timerToken.currentPassword, password)

            let oldPassword = try timerToken.generator.password(at: Date(timeIntervalSince1970: 0))
            XCTAssertNotEqual(timerToken.currentPassword, oldPassword)
        } catch {
            XCTFail("Failed to generate password with error: \(error)")
            return
        }

        let counterGenerator = try Generator(
            factor: .counter(12345),
            secret: otherSecretData,
            algorithm: .sha1,
            digits: 6
        )
        let counterToken = Token(generator: counterGenerator)

        do {
            let password = try counterToken.generator.password(at: Date())
            XCTAssertEqual(counterToken.currentPassword, password)

            let oldPassword = try counterToken.generator.password(at: Date(timeIntervalSince1970: 0))
            XCTAssertEqual(counterToken.currentPassword, oldPassword)
        } catch {
            XCTFail("Failed to generate password with error: \(error)")
            return
        }
    }

    func testUpdatedToken() throws {
        let timerGenerator = try Generator(
            factor: .timer(period: 30),
            secret: secretData,
            algorithm: .sha1,
            digits: 6
        )
        let timerToken = Token(generator: timerGenerator)

        let updatedTimerToken = timerToken.updatedToken()
        XCTAssertEqual(updatedTimerToken, timerToken)

        let count: UInt64 = 12345
        let counterGenerator = try Generator(
            factor: .counter(count),
            secret: otherSecretData,
            algorithm: .sha1,
            digits: 6
        )
        let counterToken = Token(generator: counterGenerator)

        let updatedCounterToken = counterToken.updatedToken()
        XCTAssertNotEqual(updatedCounterToken, counterToken)

        XCTAssertEqual(updatedCounterToken.name, counterToken.name)
        XCTAssertEqual(updatedCounterToken.issuer, counterToken.issuer)
        XCTAssertEqual(updatedCounterToken.generator.secret, counterToken.generator.secret)
        XCTAssertEqual(updatedCounterToken.generator.algorithm, counterToken.generator.algorithm)
        XCTAssertEqual(updatedCounterToken.generator.digits, counterToken.generator.digits)

        let updatedFactor = Generator.Factor.counter(count + 1)
        XCTAssertEqual(updatedCounterToken.generator.factor, updatedFactor)
    }
}
