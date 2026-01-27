#!/usr/bin/env swift
//
// test_plex_track_metadata.swift
// Standalone test for Plex track metadata API
//
// Usage:
//   PLEX_URL=http://192.168.1.x:32400 PLEX_TOKEN=xxx TRACK_ID=123456 swift scripts/test_plex_track_metadata.swift
//
// Or to find a track ID first, omit TRACK_ID to list random tracks:
//   PLEX_URL=http://192.168.1.x:32400 PLEX_TOKEN=xxx LIBRARY_ID=1 swift scripts/test_plex_track_metadata.swift
//

import Foundation

print("Plex Track Metadata API Test")
print("============================")
print("")

// MARK: - Configuration

let plexURL = ProcessInfo.processInfo.environment["PLEX_URL"] ?? "http://192.168.1.100:32400"
let plexToken = ProcessInfo.processInfo.environment["PLEX_TOKEN"] ?? "YOUR_PLEX_TOKEN"
let trackID = ProcessInfo.processInfo.environment["TRACK_ID"]
let libraryID = ProcessInfo.processInfo.environment["LIBRARY_ID"] ?? "1"

print("Configuration:")
print("  Server: \(plexURL)")
print("  Token: \(plexToken.prefix(8))...")
if let trackID = trackID {
    print("  Track ID: \(trackID)")
} else {
    print("  Library ID: \(libraryID) (will fetch random track)")
}
print("")

guard plexToken != "YOUR_PLEX_TOKEN" else {
    print("ERROR: Please set PLEX_TOKEN environment variable")
    print("")
    print("Usage:")
    print("  PLEX_URL=http://192.168.1.x:32400 PLEX_TOKEN=xxx TRACK_ID=123456 swift scripts/test_plex_track_metadata.swift")
    exit(1)
}

// MARK: - HTTP Helper

func fetchJSON(urlString: String) -> [String: Any]? {
    guard let url = URL(string: urlString) else {
        print("ERROR: Invalid URL: \(urlString)")
        return nil
    }
    
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 30
    
    let semaphore = DispatchSemaphore(value: 0)
    var resultData: Data?
    var resultError: Error?
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        resultData = data
        resultError = error
        semaphore.signal()
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + 30)
    
    if let error = resultError {
        print("ERROR: \(error.localizedDescription)")
        return nil
    }
    
    guard let data = resultData,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        print("ERROR: Failed to parse JSON")
        return nil
    }
    
    return json
}

// MARK: - Get a Track ID if not provided

var testTrackID = trackID

if testTrackID == nil {
    print("Fetching a random track from library \(libraryID)...")
    let listURL = "\(plexURL)/library/sections/\(libraryID)/all?type=10&sort=random&limit=1&X-Plex-Token=\(plexToken)"
    
    if let json = fetchJSON(urlString: listURL),
       let container = json["MediaContainer"] as? [String: Any],
       let metadata = container["Metadata"] as? [[String: Any]],
       let firstTrack = metadata.first,
       let ratingKey = firstTrack["ratingKey"] as? String {
        testTrackID = ratingKey
        let title = firstTrack["title"] as? String ?? "Unknown"
        let artist = firstTrack["grandparentTitle"] as? String ?? "Unknown"
        print("Found track: \(artist) - \(title) (ID: \(ratingKey))")
    } else {
        print("ERROR: Could not find any tracks in library")
        exit(1)
    }
    print("")
}

guard let trackIDToTest = testTrackID else {
    print("ERROR: No track ID available")
    exit(1)
}

// MARK: - Fetch Track Metadata

print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("FETCHING TRACK METADATA: /library/metadata/\(trackIDToTest)")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")

let metadataURL = "\(plexURL)/library/metadata/\(trackIDToTest)?X-Plex-Token=\(plexToken)"
print("URL: \(metadataURL)")
print("")

guard let json = fetchJSON(urlString: metadataURL),
      let container = json["MediaContainer"] as? [String: Any],
      let metadata = container["Metadata"] as? [[String: Any]],
      let track = metadata.first else {
    print("ERROR: Failed to fetch track metadata")
    exit(1)
}

// MARK: - Display All Fields

print("RAW TRACK METADATA:")
print("-" .padding(toLength: 60, withPad: "-", startingAt: 0))

// Sort keys for consistent output
let sortedKeys = track.keys.sorted()
for key in sortedKeys {
    let value = track[key]
    if let dict = value as? [String: Any] {
        print("  \(key): [Dictionary with \(dict.count) keys]")
    } else if let array = value as? [Any] {
        print("  \(key): [Array with \(array.count) items]")
    } else {
        print("  \(key): \(value ?? "nil")")
    }
}

print("")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("PARSED FIELDS FOR 'ABOUT PLAYING' FEATURE")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")

// Basic Info
print("BASIC INFO:")
print("  ratingKey: \(track["ratingKey"] ?? "nil")")
print("  title: \(track["title"] ?? "nil")")
print("  grandparentTitle (Artist): \(track["grandparentTitle"] ?? "nil")")
print("  parentTitle (Album): \(track["parentTitle"] ?? "nil")")
print("")

// Track Position
print("TRACK POSITION:")
print("  index (Track #): \(track["index"] ?? "nil")")
print("  parentIndex (Disc #): \(track["parentIndex"] ?? "nil")")
print("  parentYear (Year): \(track["parentYear"] ?? "nil")")
print("")

// Duration
print("DURATION:")
if let duration = track["duration"] as? Int {
    let seconds = duration / 1000
    let minutes = seconds / 60
    print("  duration: \(duration) ms (\(minutes):\(String(format: "%02d", seconds % 60)))")
} else {
    print("  duration: nil")
}
print("")

// Ratings
print("RATINGS:")
print("  ratingCount (Last.fm scrobbles): \(track["ratingCount"] ?? "nil")")
print("  userRating (Your rating 0-10): \(track["userRating"] ?? "nil")")
if let rating = track["userRating"] as? Double {
    let stars = Int(round(rating / 2))
    let starStr = String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)
    print("    → \(starStr)")
}
print("")

// Genre
print("GENRE:")
if let genres = track["Genre"] as? [[String: Any]] {
    for genre in genres {
        print("  - \(genre["tag"] ?? "unknown")")
    }
} else {
    print("  Genre: nil")
}
print("")

// Media Info
print("MEDIA INFO:")
if let mediaArray = track["Media"] as? [[String: Any]], let media = mediaArray.first {
    print("  bitrate: \(media["bitrate"] ?? "nil") kbps")
    print("  audioChannels: \(media["audioChannels"] ?? "nil")")
    print("  audioCodec: \(media["audioCodec"] ?? "nil")")
    print("  container: \(media["container"] ?? "nil")")
    
    // Parts (file info)
    if let parts = media["Part"] as? [[String: Any]], let part = parts.first {
        print("")
        print("  FILE INFO (from Part):")
        print("    file: \(part["file"] ?? "nil")")
        print("    size: \(part["size"] ?? "nil") bytes")
        
        // Streams (detailed audio info)
        if let streams = part["Stream"] as? [[String: Any]] {
            for stream in streams {
                let streamType = stream["streamType"] as? Int ?? 0
                if streamType == 2 { // Audio stream
                    print("")
                    print("  AUDIO STREAM DETAILS:")
                    print("    codec: \(stream["codec"] ?? "nil")")
                    print("    channels: \(stream["channels"] ?? "nil")")
                    print("    channelLayout: \(stream["audioChannelLayout"] ?? "nil")")
                    print("    bitrate: \(stream["bitrate"] ?? "nil") kbps")
                    print("    bitDepth: \(stream["bitDepth"] ?? "nil")")
                    print("    samplingRate: \(stream["samplingRate"] ?? "nil") Hz")
                    print("    displayTitle: \(stream["displayTitle"] ?? "nil")")
                }
            }
        }
    }
} else {
    print("  Media: nil")
}

print("")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("VERIFICATION SUMMARY")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")

// Check which fields are available
var availableFields = [String]()
var missingFields = [String]()

let requiredFields = [
    ("ratingKey", track["ratingKey"]),
    ("title", track["title"]),
    ("grandparentTitle (Artist)", track["grandparentTitle"]),
    ("parentTitle (Album)", track["parentTitle"]),
    ("duration", track["duration"]),
    ("Media array", track["Media"])
]

let optionalFields = [
    ("index (Track #)", track["index"]),
    ("parentIndex (Disc #)", track["parentIndex"]),
    ("parentYear", track["parentYear"]),
    ("ratingCount (Last.fm)", track["ratingCount"]),
    ("userRating", track["userRating"]),
    ("Genre array", track["Genre"])
]

print("REQUIRED FIELDS:")
for (name, value) in requiredFields {
    if value != nil {
        print("  ✓ \(name)")
        availableFields.append(name)
    } else {
        print("  ✗ \(name) - MISSING!")
        missingFields.append(name)
    }
}

print("")
print("OPTIONAL FIELDS:")
for (name, value) in optionalFields {
    if value != nil {
        print("  ✓ \(name)")
        availableFields.append(name)
    } else {
        print("  - \(name) (not set for this track)")
    }
}

print("")
if missingFields.isEmpty {
    print("SUCCESS: All required fields are available!")
    print("The /library/metadata/{trackID} endpoint returns the expected data.")
} else {
    print("WARNING: Some required fields are missing: \(missingFields.joined(separator: ", "))")
}

print("")
print("Test complete.")
