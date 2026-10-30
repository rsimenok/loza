//
//  TransmissionError.swift
//  TransmissionRemote-iOS
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

/// Errors encountered when communicating with a Transmission RPC server.
nonisolated public enum TransmissionError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case unauthorized
    case serverUnreachable(underlying: any Error & Sendable)
    case sslCertificateUntrusted
    case rpcError(message: String)
    case noActiveServer
    case decodingFailed(underlying: any Error & Sendable)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Invalid server URL.")
        case .unauthorized:
            return String(localized: "Authentication failed (401 Unauthorized).")
        case .serverUnreachable(let underlying):
            return String(localized: "Cannot reach server: \(underlying.localizedDescription)")
        case .sslCertificateUntrusted:
            return String(localized: "SSL certificate untrusted.")
        case .rpcError(let message):
            return String(localized: "Transmission RPC error: \(message)")
        case .noActiveServer:
            return String(localized: "No active server configured.")
        case .decodingFailed(let underlying):
            return String(localized: "Failed to parse server response: \(underlying.localizedDescription)")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Please check the host, port, and RPC path in server settings.")
        case .unauthorized:
            return String(localized: "Please verify your username and password in server settings.")
        case .serverUnreachable:
            return String(localized: "Check your network connection and ensure the Transmission daemon is running and reachable.")
        case .sslCertificateUntrusted:
            return String(localized: "Enable 'Trust Self-Signed Certificates' in server settings if your server uses a self-signed SSL certificate.")
        case .rpcError:
            return String(localized: "Verify that the operation is supported by this Transmission daemon version.")
        case .noActiveServer:
            return String(localized: "Please select or add an active server in settings.")
        case .decodingFailed:
            return String(localized: "Ensure that the target host is running a compatible Transmission RPC daemon.")
        }
    }

    public static func == (lhs: TransmissionError, rhs: TransmissionError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case (.unauthorized, .unauthorized):
            return true
        case (.sslCertificateUntrusted, .sslCertificateUntrusted):
            return true
        case (.noActiveServer, .noActiveServer):
            return true
        case (.rpcError(let m1), .rpcError(let m2)):
            return m1 == m2
        case (.serverUnreachable(let e1), .serverUnreachable(let e2)):
            return e1.localizedDescription == e2.localizedDescription
        case (.decodingFailed(let e1), .decodingFailed(let e2)):
            return e1.localizedDescription == e2.localizedDescription
        default:
            return false
        }
    }
}
