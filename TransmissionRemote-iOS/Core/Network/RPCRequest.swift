//
//  RPCRequest.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

/// Generic envelope for Transmission RPC requests.
nonisolated public struct RPCRequest<T: Encodable & Sendable>: Encodable, Sendable {
    public let method: String
    public let arguments: T
    public let tag: Int?

    public init(method: String, arguments: T, tag: Int? = nil) {
        self.method = method
        self.arguments = arguments
        self.tag = tag
    }

    enum CodingKeys: String, CodingKey {
        case method
        case arguments
        case tag
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(method, forKey: .method)
        try container.encode(arguments, forKey: .arguments)
        if let tag = tag {
            try container.encode(tag, forKey: .tag)
        }
    }
}

extension RPCRequest where T == EmptyArguments {
    public init(method: String, tag: Int? = nil) {
        self.init(method: method, arguments: EmptyArguments(), tag: tag)
    }
}

/// Empty arguments payload for RPC methods that do not take arguments (e.g. `session-stats`).
nonisolated public struct EmptyArguments: Encodable, Sendable, Equatable {
    public init() {}

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode([String: String]())
    }
}

/// Arguments for the `torrent-get` RPC method.
nonisolated public struct TorrentGetArguments: Encodable, Sendable, Equatable {
    public var fields: [String]
    public var ids: [Int]?

    public static let defaultFields: [String] = [
        "id", "name", "status", "rateDownload", "rateUpload",
        "percentDone", "totalSize", "eta", "errorString",
        "peersConnected", "peersSendingToUs", "peersGettingFromUs",
        "uploadedEver", "downloadedEver", "uploadRatio", "files",
        "hashString", "addedDate"
    ]

    public init(fields: [String] = TorrentGetArguments.defaultFields, ids: [Int]? = nil) {
        self.fields = fields
        self.ids = ids
    }

    enum CodingKeys: String, CodingKey {
        case fields
        case ids
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fields, forKey: .fields)
        if let ids = ids {
            try container.encode(ids, forKey: .ids)
        }
    }
}

/// Arguments for torrent control methods like `torrent-start`, `torrent-stop`.
nonisolated public struct TorrentActionArguments: Encodable, Sendable, Equatable {
    public let ids: [Int]

    public init(ids: [Int]) {
        self.ids = ids
    }

    enum CodingKeys: String, CodingKey {
        case ids
    }
}

/// Arguments for the `torrent-remove` RPC method.
nonisolated public struct TorrentRemoveArguments: Encodable, Sendable, Equatable {
    public let ids: [Int]
    public let deleteLocalData: Bool

    public init(ids: [Int], deleteLocalData: Bool = false) {
        self.ids = ids
        self.deleteLocalData = deleteLocalData
    }

    enum CodingKeys: String, CodingKey {
        case ids
        case deleteLocalData = "delete-local-data"
    }
}

/// Arguments for the `torrent-add` RPC method.
nonisolated public struct TorrentAddArguments: Encodable, Sendable, Equatable {
    public let filename: String?
    public let metainfo: String?
    public let downloadDir: String?
    public let paused: Bool?

    public init(
        filename: String? = nil,
        metainfo: String? = nil,
        downloadDir: String? = nil,
        paused: Bool? = nil
    ) {
        self.filename = filename
        self.metainfo = metainfo
        self.downloadDir = downloadDir
        self.paused = paused
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case metainfo
        case downloadDir = "download-dir"
        case paused
    }
}
