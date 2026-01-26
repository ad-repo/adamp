#!/usr/bin/env swift
//
// test_plex_rating.swift
// Standalone Plex API test for userRating filtering
//
// Usage: 
//   PLEX_URL=http://192.168.1.x:32400 PLEX_TOKEN=xxx LIBRARY_ID=1 swift scripts/test_plex_rating.swift
//
// Or edit the configuration below and run:
//   swift scripts/test_plex_rating.swift
//
// This script tests different URL formats for the userRating filter to determine
// the correct format that Plex actually uses for filtering by user star ratings.
//

import Foundation

print("Plex Rating API Test")
print("====================")
print("")

// MARK: - Configuration

// Set these directly or use environment variables
let plexURL = ProcessInfo.processInfo.environment["PLEX_URL"] ?? "http://192.168.1.100:32400"
let plexToken = ProcessInfo.processInfo.environment["PLEX_TOKEN"] ?? "YOUR_PLEX_TOKEN"
let libraryID = ProcessInfo.processInfo.environment["LIBRARY_ID"] ?? "1"

// Rating threshold to test (8 = 4+ stars)
let testRating = 8

print("Configuration:")
print("  Server: \(plexURL)")
print("  Library: \(libraryID)")
print("  Token: \(plexToken.prefix(8))...")
print("  Test Rating: >= \(testRating) (>= \(testRating/2) stars)")
print("")

guard plexToken != "YOUR_PLEX_TOKEN" else {
    print("ERROR: Please set PLEX_TOKEN environment variable or edit the script")
    print("")
    print("Usage:")
    print("  PLEX_URL=http://192.168.1.x:32400 PLEX_TOKEN=xxx LIBRARY_ID=1 swift scripts/test_plex_rating.swift")
    exit(1)
}

// MARK: - Helpers

struct PlexTrackInfo {
    let ratingKey: String
    let title: String
    let artist: String
    let userRating: Double?
}

func parseTracksFromJSON(_ data: Data) -> [PlexTrackInfo] {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let mediaContainer = json["MediaContainer"] as? [String: Any],
          let metadata = mediaContainer["Metadata"] as? [[String: Any]] else {
        return []
    }
    
    return metadata.compactMap { item -> PlexTrackInfo? in
        guard let ratingKey = item["ratingKey"] as? String,
              let title = item["title"] as? String else {
            return nil
        }
        let artist = item["grandparentTitle"] as? String ?? "Unknown"
        let userRating = item["userRating"] as? Double
        return PlexTrackInfo(ratingKey: ratingKey, title: title, artist: artist, userRating: userRating)
    }
}

func fetchTracks(urlString: String, description: String) -> (tracks: [PlexTrackInfo], actualURL: String)? {
    print("Test: \(description)")
    print("  URL: \(urlString)")
    
    guard let url = URL(string: urlString) else {
        print("  ERROR: Invalid URL")
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
        print("  ERROR: \(error.localizedDescription)")
        return nil
    }
    
    guard let data = resultData else {
        print("  ERROR: No data received")
        return nil
    }
    
    let tracks = parseTracksFromJSON(data)
    print("  Result: \(tracks.count) tracks returned")
    
    return (tracks, urlString)
}

func fetchSingleTrack(ratingKey: String) -> PlexTrackInfo? {
    let urlString = "\(plexURL)/library/metadata/\(ratingKey)?X-Plex-Token=\(plexToken)"
    guard let url = URL(string: urlString) else { return nil }
    
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    
    let semaphore = DispatchSemaphore(value: 0)
    var resultData: Data?
    
    let task = URLSession.shared.dataTask(with: request) { data, _, _ in
        resultData = data
        semaphore.signal()
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + 10)
    
    guard let data = resultData else { return nil }
    
    let tracks = parseTracksFromJSON(data)
    return tracks.first
}

// MARK: - Test Cases

print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("TEST A: URLQueryItem approach (current implementation)")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")

// This is how the current code builds the URL using URLQueryItem
// URLQueryItem(name: "userRating>=", value: "8") produces userRating%3E%3D=8
var componentsA = URLComponents(string: "\(plexURL)/library/sections/\(libraryID)/all")!
componentsA.queryItems = [
    URLQueryItem(name: "type", value: "10"),
    URLQueryItem(name: "userRating>=", value: String(testRating)),
    URLQueryItem(name: "sort", value: "random"),
    URLQueryItem(name: "limit", value: "20"),
    URLQueryItem(name: "X-Plex-Token", value: plexToken)
]
let urlA = componentsA.url!.absoluteString
let resultA = fetchTracks(urlString: urlA, description: "URLQueryItem with 'userRating>=' as name")
print("")

print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("TEST B: Raw query string (manual URL construction)")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")

// Build URL manually with unencoded >= in the query string
let urlB = "\(plexURL)/library/sections/\(libraryID)/all?type=10&userRating>=\(testRating)&sort=random&limit=20&X-Plex-Token=\(plexToken)"
let resultB = fetchTracks(urlString: urlB, description: "Raw query string with userRating>=\(testRating)")
print("")

print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("TEST C: No rating filter (baseline)")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")

// Fetch without any rating filter as baseline
var componentsC = URLComponents(string: "\(plexURL)/library/sections/\(libraryID)/all")!
componentsC.queryItems = [
    URLQueryItem(name: "type", value: "10"),
    URLQueryItem(name: "sort", value: "random"),
    URLQueryItem(name: "limit", value: "20"),
    URLQueryItem(name: "X-Plex-Token", value: plexToken)
]
let urlC = componentsC.url!.absoluteString
let resultC = fetchTracks(urlString: urlC, description: "No rating filter (baseline)")
print("")

// MARK: - Verify Actual Ratings

print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("VERIFICATION: Check actual userRating values")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")

func verifyTracks(_ tracks: [PlexTrackInfo], testName: String) {
    guard !tracks.isEmpty else {
        print("\(testName): No tracks to verify")
        return
    }
    
    print("\(testName) - First 5 tracks:")
    let tracksWithRatings = tracks.prefix(5).map { track -> (PlexTrackInfo, Double?) in
        // The list response may not include userRating, so fetch individual track
        if track.userRating == nil {
            if let detailed = fetchSingleTrack(ratingKey: track.ratingKey) {
                return (track, detailed.userRating)
            }
        }
        return (track, track.userRating)
    }
    
    var ratedCount = 0
    var matchingCount = 0
    
    for (track, rating) in tracksWithRatings {
        let ratingStr: String
        if let r = rating {
            ratingStr = String(format: "%.1f (%d stars)", r, Int(r / 2))
            ratedCount += 1
            if r >= Double(testRating) {
                matchingCount += 1
            }
        } else {
            ratingStr = "NOT RATED"
        }
        print("  - \(track.artist) - \(track.title)")
        print("    Rating: \(ratingStr)")
    }
    
    print("")
    print("  Summary: \(ratedCount)/\(tracksWithRatings.count) have ratings, \(matchingCount)/\(tracksWithRatings.count) meet threshold")
    print("")
}

if let resultA = resultA {
    verifyTracks(resultA.tracks, testName: "TEST A (URLQueryItem)")
}

if let resultB = resultB {
    verifyTracks(resultB.tracks, testName: "TEST B (Raw query)")
}

if let resultC = resultC {
    verifyTracks(resultC.tracks, testName: "TEST C (Baseline)")
}

// MARK: - Summary

print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("SUMMARY")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")

print("Test A (URLQueryItem): \(resultA?.tracks.count ?? 0) tracks")
print("  URL encodes 'userRating>=' as 'userRating%3E%3D' with separate '=8'")
print("")
print("Test B (Raw query):    \(resultB?.tracks.count ?? 0) tracks")
print("  URL keeps 'userRating>=8' as literal characters")
print("")
print("Test C (Baseline):     \(resultC?.tracks.count ?? 0) tracks")
print("  No filter applied")
print("")

// Analysis
if let aCount = resultA?.tracks.count, let bCount = resultB?.tracks.count, let cCount = resultC?.tracks.count {
    if bCount < cCount && bCount < aCount {
        print("CONCLUSION: Test B (raw query) appears to filter correctly!")
        print("The current implementation (Test A) is NOT filtering by rating.")
        print("")
        print("FIX: Build the URL manually instead of using URLQueryItem for")
        print("     filter parameters that include operators like >=, <=, etc.")
    } else if aCount < cCount && aCount <= bCount {
        print("CONCLUSION: Test A (URLQueryItem) appears to work!")
        print("The current implementation may be correct.")
    } else if aCount == cCount && bCount == cCount {
        print("CONCLUSION: Neither approach is filtering!")
        print("This could mean:")
        print("  1. No tracks have userRating >= \(testRating)")
        print("  2. The Plex API parameter format is different")
        print("  3. Check the server logs or try with a different rating threshold")
    } else {
        print("CONCLUSION: Results are inconclusive. Manual inspection needed.")
    }
}

print("")
print("Test complete.")
