//
//  TorrentFile.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import Foundation

nonisolated public struct TorrentFile: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: Int
    public var name: String
    public var bytesCompleted: Int64
    public var length: Int64
    public var wanted: Bool
    public var priority: Int

    public init(
        id: Int = 0,
        name: String,
        bytesCompleted: Int64 = 0,
        length: Int64 = 0,
        wanted: Bool = true,
        priority: Int = 0
    ) {
        self.id = id
        self.name = name
        self.bytesCompleted = bytesCompleted
        self.length = length
        self.wanted = wanted
        self.priority = priority
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case bytesCompleted
        case length
        case wanted
        case priority
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.name = try container.decode(String.self, forKey: .name)
        self.bytesCompleted = try container.decodeIfPresent(Int64.self, forKey: .bytesCompleted) ?? 0
        self.length = try container.decodeIfPresent(Int64.self, forKey: .length) ?? 0
        self.wanted = try container.decodeIfPresent(Bool.self, forKey: .wanted) ?? true
        self.priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
    }

    /// Download progress from 0.0 to 1.0
    public var progress: Double {
        guard length > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(bytesCompleted) / Double(length)))
    }

    /// Progress percentage formatted, e.g. "75.4%"
    public var percentDoneString: String {
        String(format: "%.1f%%", progress * 100)
    }

    /// Human-readable file size
    public var formattedLength: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: length)
    }

    /// Human-readable downloaded bytes
    public var formattedBytesCompleted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytesCompleted)
    }

    /// File extension without dot (e.g. "mkv", "iso")
    public var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }
}
