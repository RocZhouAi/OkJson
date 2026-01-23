//  Constants.swift
//  OkJson
//
//  App-wide constants
//

import Foundation

/// App-wide constants
enum Constants {
    // MARK: - App Info

    static let appName = "OkJson"
    static let appVersion = "1.0.0"

    // MARK: - File Size Limits

    /// Maximum file size in bytes (10MB)
    static let maxFileSizeBytes: Int = 10 * 1024 * 1024

    /// File size warning threshold (5MB)
    static let fileSizeWarningThreshold: Int = 5 * 1024 * 1024

    // MARK: - Performance

    /// Maximum nesting depth for default expansion
    static let defaultMaxDepth: Int = 3

    /// Indentation options
    static let indentationOptions = [2, 4]

    // MARK: - Default Content

    /// Default JSON for testing/demo
    static let defaultJSON = """
    {
        "data": [
            {
                "ID": 10,
                "CreatedAt": "2026-01-15T06:15:43.390143Z",
                "UpdatedAt": "2026-01-15T06:15:43.390143Z",
                "DeletedAt": null,
                "name": "炉下水库",
                "location": "广东省惠州市惠东县多祝镇炉下",
                "description": "惠州炉下位于惠州市惠东县，拥有开阔草原、清澈溪流和美丽山景，全免费。",
                "images": [
                    "https://example.com/image1.png",
                    "https://example.com/image2.png"
                ],
                "created_by": "zhoujunpeng1992",
                "latitude": 22.98616972907305,
                "longitude": 115.02456390068534,
                "has_water": true,
                "has_electricity": false,
                "has_toilet": false,
                "has_campfire": true,
                "has_wifi": false,
                "allows_pets": false,
                "has_parking": true,
                "has_rv": false,
                "has_tent": false,
                "rating": 0,
                "is_favorite": false,
                "rating_distribution": {
                    "1": 0,
                    "2": 0,
                    "3": 0,
                    "4": 0,
                    "5": 0
                },
                "review_count": 0,
                "creator": null
            },
            {
                "ID": 11,
                "name": "耀潭村",
                "location": "广东省惠州市博罗县杨村镇耀潭村",
                "description": "基础概况：位置位于惠州博罗县耀潭村，费用全程免费，拥有超大平坦草坪、江景日落。",
                "has_water": true,
                "has_electricity": false,
                "has_toilet": true,
                "has_campfire": true,
                "rating": 0
            }
        ]
    }
    """

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let indentation = "indentation"
        static let sortKeys = "sortKeys"
        static let syncScroll = "syncScroll"
        static let colorScheme = "colorScheme"
        static let maxDepth = "maxDepth"
        static let lineNumbers = "lineNumbers"
    }

    // MARK: - Error Messages

    enum ErrorMessages {
        static let emptyInput = "Input cannot be empty"
        static let invalidJSON = "Invalid JSON"
        static let fileTooLarge = "File size exceeds 10MB limit"
        static let networkDriveNotSupported = "Network drives are not supported"
        static let encodingError = "Unable to read file as UTF-8"
        static let permissionDenied = "Permission denied"
        static let fileNotFound = "File not found"
    }
}
