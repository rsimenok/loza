//
//  RPCResponse.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

/// Generic envelope for Transmission RPC responses.
nonisolated public struct RPCResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let result: String
    public let arguments: T?
    public let tag: Int?

    public init(result: String, arguments: T? = nil, tag: Int? = nil) {
        self.result = result
        self.arguments = arguments
        self.tag = tag
    }

    enum CodingKeys: String, CodingKey {
        case result
        case arguments
        case tag
    }

    /// Whether the RPC execution reported success
    public var isSuccess: Bool {
        result == "success"
    }
}

/// Generic empty response for RPC methods that do not return arguments or whose arguments are not needed.
nonisolated public struct EmptyResponse: Decodable, Sendable, Equatable {
    public init() {}

    public init(from decoder: Decoder) throws {
        // Accepts any payload (empty dict, null, or unknown fields)
    }
}

/// Response arguments payload for `torrent-get`.
nonisolated public struct TorrentGetResponse: Decodable, Sendable, Equatable {
    public let torrents: [Torrent]

    public init(torrents: [Torrent] = []) {
        self.torrents = torrents
    }

    enum CodingKeys: String, CodingKey {
        case torrents
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.torrents = try container.decodeIfPresent([Torrent].self, forKey: .torrents) ?? []
    }
}
