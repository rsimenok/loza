//
//  ServerConfig.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

nonisolated public enum ServerScheme: String, Codable, Sendable, CaseIterable, Identifiable {
    case http
    case https

    public var id: String { rawValue }

    public var defaultPort: Int {
        switch self {
        case .http:
            return 9091
        case .https:
            return 443
        }
    }
}

nonisolated public struct ServerConfig: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var scheme: ServerScheme
    public var host: String
    public var port: Int
    public var rpcPath: String
    public var trustSelfSignedCertificates: Bool
    public var username: String?

    public init(
        id: UUID = UUID(),
        name: String,
        scheme: ServerScheme = .http,
        host: String,
        port: Int = 9091,
        rpcPath: String = "/transmission/rpc",
        trustSelfSignedCertificates: Bool = false,
        username: String? = nil
    ) {
        self.id = id
        self.name = name
        self.scheme = scheme
        self.host = host
        self.port = port
        self.rpcPath = rpcPath
        self.trustSelfSignedCertificates = trustSelfSignedCertificates
        self.username = username
    }

    /// Full URL to the Transmission RPC endpoint
    public var url: URL? {
        var components = URLComponents()
        components.scheme = scheme.rawValue
        components.host = host
        components.port = port
        let cleanPath = rpcPath.hasPrefix("/") ? rpcPath : "/" + rpcPath
        components.path = cleanPath
        return components.url
    }

    /// User-friendly display string, e.g. "http://192.168.1.50:9091"
    public var displayAddress: String {
        "\(scheme.rawValue)://\(host):\(port)"
    }
}
