//
//  KeychainService.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation
import Security

public protocol KeychainServiceProtocol: Sendable {
    func save(password: String, forServerId id: UUID) throws
    func getPassword(forServerId id: UUID) -> String?
    func deletePassword(forServerId id: UUID) throws
    func deleteAllPasswords() throws
}

public enum KeychainError: LocalizedError, Sendable, Equatable {
    case unhandledStatus(OSStatus)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error (\(status)): \(message)"
            }
            return "Keychain error code: \(status)"
        case .invalidData:
            return "Failed to encode/decode password data."
        }
    }
}

public final class KeychainService: KeychainServiceProtocol, Sendable {
    public static let shared = KeychainService()

    private let service: String

    public init(service: String = "com.smnk.loza") {
        self.service = service
    }

    private func accountKey(for id: UUID) -> String {
        "server_\(id.uuidString.lowercased())_password"
    }

    public func save(password: String, forServerId id: UUID) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let account = accountKey(for: id)

        // Delete any existing item first to ensure a clean write
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    public func getPassword(forServerId id: UUID) -> String? {
        let account = accountKey(for: id)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    public func deletePassword(forServerId id: UUID) throws {
        let account = accountKey(for: id)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    public func deleteAllPasswords() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}
