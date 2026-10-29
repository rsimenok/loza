//
//  RPCModelTests.swift
//  TransmissionRemote-iOSTests
//
//  Created by Roman Simenok on 29.10.2026.
//

import XCTest
@testable import TransmissionRemote_iOS

final class RPCModelTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func testRPCRequestEncoding() throws {
        let args = TorrentActionArguments(ids: [1, 2, 3])
        let request = RPCRequest(method: "torrent-start", arguments: args, tag: 42)

        let data = try encoder.encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["method"] as? String, "torrent-start")
        XCTAssertEqual(json["tag"] as? Int, 42)

        let arguments = try XCTUnwrap(json["arguments"] as? [String: Any])
        XCTAssertEqual(arguments["ids"] as? [Int], [1, 2, 3])
    }

    func testRPCResponseDecodingSuccess() throws {
        let json = """
        {
            "result": "success",
            "tag": 100,
            "arguments": {
                "torrents": [
                    {
                        "id": 1,
                        "name": "Test Torrent",
                        "status": 4,
                        "rateDownload": 1000,
                        "rateUpload": 500,
                        "percentDone": 0.5,
                        "totalSize": 2048,
                        "eta": 120,
                        "errorString": "",
                        "peersConnected": 10,
                        "peersSendingToUs": 5,
                        "peersGettingFromUs": 2,
                        "uploadedEver": 1024,
                        "downloadedEver": 1024,
                        "uploadRatio": 1.0,
                        "files": []
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RPCResponse<TorrentGetResponse>.self, from: json)
        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.result, "success")
        XCTAssertEqual(response.tag, 100)

        let torrents = try XCTUnwrap(response.arguments?.torrents)
        XCTAssertEqual(torrents.count, 1)
        XCTAssertEqual(torrents.first?.name, "Test Torrent")
        XCTAssertEqual(torrents.first?.status, .download)
    }

    func testRPCResponseEmptyResponse() throws {
        let json = """
        {
            "result": "success",
            "arguments": {}
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RPCResponse<EmptyResponse>.self, from: json)
        XCTAssertTrue(response.isSuccess)
    }

    func testTorrentRemoveArgumentsEncoding() throws {
        let args = TorrentRemoveArguments(ids: [10], deleteLocalData: true)
        let data = try encoder.encode(args)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["ids"] as? [Int], [10])
        XCTAssertEqual(json["delete-local-data"] as? Bool, true)
    }

    func testTorrentAddArgumentsEncoding() throws {
        let args = TorrentAddArguments(
            filename: "magnet:?xt=urn:btih:123",
            metainfo: "base64data",
            downloadDir: "/downloads"
        )
        let data = try encoder.encode(args)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["filename"] as? String, "magnet:?xt=urn:btih:123")
        XCTAssertEqual(json["metainfo"] as? String, "base64data")
        XCTAssertEqual(json["download-dir"] as? String, "/downloads")
    }

    func testTransmissionErrorDescriptionsAndSuggestions() {
        let errors: [TransmissionError] = [
            .invalidURL,
            .unauthorized,
            .serverUnreachable(underlying: NSError(domain: "test", code: -1)),
            .sslCertificateUntrusted,
            .rpcError(message: "duplicate torrent"),
            .noActiveServer,
            .decodingFailed(underlying: NSError(domain: "test", code: -2))
        ]

        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
            XCTAssertFalse(error.recoverySuggestion?.isEmpty ?? true)
        }
    }
}
