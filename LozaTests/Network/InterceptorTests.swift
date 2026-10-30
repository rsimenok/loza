//
//  InterceptorTests.swift
//  TransmissionRemote-iOSTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import XCTest
import Alamofire
@testable import TransmissionRemote_iOS

final class InterceptorTests: XCTestCase {
    private var testURL: URL {
        URL(string: "http://192.168.1.100:9091/transmission/rpc")!
    }

    func testAdaptAddsSessionIdWhenPresent() {
        let interceptor = TransmissionInterceptor(initialSessionId: "test-token-123")
        let request = URLRequest(url: testURL)
        let expectation = expectation(description: "Adapt completion")

        interceptor.adapt(request, for: Session.default) { result in
            switch result {
            case .success(let adaptedRequest):
                XCTAssertEqual(
                    adaptedRequest.value(forHTTPHeaderField: "X-Transmission-Session-Id"),
                    "test-token-123"
                )
            case .failure(let error):
                XCTFail("Adaptation failed with error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testAdaptDoesNotAddSessionIdWhenNil() {
        let interceptor = TransmissionInterceptor(initialSessionId: nil)
        let request = URLRequest(url: testURL)
        let expectation = expectation(description: "Adapt completion")

        interceptor.adapt(request, for: Session.default) { result in
            switch result {
            case .success(let adaptedRequest):
                XCTAssertNil(adaptedRequest.value(forHTTPHeaderField: "X-Transmission-Session-Id"))
            case .failure(let error):
                XCTFail("Adaptation failed with error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testAdaptAddsBasicAuthorization() {
        let username = "admin"
        let password = "mySecretPassword123!"
        let interceptor = TransmissionInterceptor(username: username, password: password)
        let request = URLRequest(url: testURL)
        let expectation = expectation(description: "Adapt completion")

        let expectedBase64 = Data("\(username):\(password)".utf8).base64EncodedString()
        let expectedHeader = "Basic \(expectedBase64)"

        interceptor.adapt(request, for: Session.default) { result in
            switch result {
            case .success(let adaptedRequest):
                XCTAssertEqual(
                    adaptedRequest.value(forHTTPHeaderField: "Authorization"),
                    expectedHeader
                )
            case .failure(let error):
                XCTFail("Adaptation failed with error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testAdaptDoesNotAddAuthorizationWhenUsernameIsNilOrEmpty() {
        let interceptor1 = TransmissionInterceptor(username: nil, password: "password")
        let interceptor2 = TransmissionInterceptor(username: "", password: "password")
        let request = URLRequest(url: testURL)

        let exp1 = expectation(description: "exp1")
        let exp2 = expectation(description: "exp2")

        interceptor1.adapt(request, for: Session.default) { result in
            if case .success(let adapted) = result {
                XCTAssertNil(adapted.value(forHTTPHeaderField: "Authorization"))
            } else {
                XCTFail("Adapt failed")
            }
            exp1.fulfill()
        }

        interceptor2.adapt(request, for: Session.default) { result in
            if case .success(let adapted) = result {
                XCTAssertNil(adapted.value(forHTTPHeaderField: "Authorization"))
            } else {
                XCTFail("Adapt failed")
            }
            exp2.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testRetryEvaluates409WithNewSessionId() {
        let interceptor = TransmissionInterceptor(initialSessionId: "old-token")
        let headers = ["X-Transmission-Session-Id": "new-token-409-handshake"]

        let result = interceptor.evaluateRetry(statusCode: 409, headers: headers, retryCount: 0)

        XCTAssertTrue(result.shouldRetry)
        XCTAssertEqual(result.newSessionId, "new-token-409-handshake")
        XCTAssertEqual(interceptor.sessionId, "new-token-409-handshake")
    }

    func testRetryCaseInsensitiveHeaderLookup() {
        let interceptor = TransmissionInterceptor()
        let headers = ["x-transmission-session-id": "case-insensitive-token"]

        let result = interceptor.evaluateRetry(statusCode: 409, headers: headers, retryCount: 0)

        XCTAssertTrue(result.shouldRetry)
        XCTAssertEqual(result.newSessionId, "case-insensitive-token")
        XCTAssertEqual(interceptor.sessionId, "case-insensitive-token")
    }

    func testRetryFailsWhenSessionHeaderMissingOn409() {
        let interceptor = TransmissionInterceptor(initialSessionId: "token")
        let headers = ["Content-Type": "text/html"]

        let result = interceptor.evaluateRetry(statusCode: 409, headers: headers, retryCount: 0)

        XCTAssertFalse(result.shouldRetry)
        XCTAssertNil(result.newSessionId)
        XCTAssertEqual(interceptor.sessionId, "token")
    }

    func testDoNotRetryOnOtherStatusCodes() {
        let interceptor = TransmissionInterceptor()
        let headers = ["X-Transmission-Session-Id": "some-token"]

        for statusCode in [200, 401, 403, 404, 500, 502] {
            let result = interceptor.evaluateRetry(statusCode: statusCode, headers: headers, retryCount: 0)
            XCTAssertFalse(result.shouldRetry, "Status \(statusCode) should not trigger retry")
        }
    }

    func testDoNotRetryWhenMaxRetryCountReached() {
        let interceptor = TransmissionInterceptor()
        let headers = ["X-Transmission-Session-Id": "new-token"]

        let result = interceptor.evaluateRetry(statusCode: 409, headers: headers, retryCount: 2)

        XCTAssertFalse(result.shouldRetry)
    }

    func testUpdateCredentials() {
        let interceptor = TransmissionInterceptor(username: "oldUser", password: "oldPassword")
        interceptor.updateCredentials(username: "newUser", password: "newPassword")

        let request = URLRequest(url: testURL)
        let expectation = expectation(description: "Adapt updated credentials")

        let expectedBase64 = Data("newUser:newPassword".utf8).base64EncodedString()

        interceptor.adapt(request, for: Session.default) { result in
            if case .success(let adapted) = result {
                XCTAssertEqual(
                    adapted.value(forHTTPHeaderField: "Authorization"),
                    "Basic \(expectedBase64)"
                )
            } else {
                XCTFail("Adaptation failed")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }
}
