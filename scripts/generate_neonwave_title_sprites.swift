#!/usr/bin/env swift
// generate_neonwave_title_sprites.swift
// Generates title character sprite PNGs for the NeonWave modern skin.
// Run: swift scripts/generate_neonwave_title_sprites.swift
//
// Produces pure-white 7x11 pixel-art character sprites (A-Z, 0-9, punctuation).
// At runtime, the renderer tints these to NeonWave's cyan (#00ffcc) via titleText.tintColor.
// Uses the same bold pixel font as the Skulls skin for a consistent retro aesthetic.

import AppKit
import Foundation

// MARK: - PNG Bitmap Helpers

func createBitmap(width: Int, height: Int) -> NSBitmapImageRep {
    return NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: width * 4, bitsPerPixel: 32
    )!
}

func savePNG(_ rep: NSBitmapImageRep, to path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("  \(URL(fileURLWithPath: path).lastPathComponent)")
}

func setPixel(_ rep: NSBitmapImageRep, x: Int, y: Int, _ c: (Int, Int, Int)) {
    guard x >= 0, y >= 0, x < rep.pixelsWide, y < rep.pixelsHigh else { return }
    let ptr = rep.bitmapData!
    let bpr = rep.bytesPerRow
    let offset = y * bpr + x * 4
    ptr[offset] = UInt8(clamping: c.0)
    ptr[offset + 1] = UInt8(clamping: c.1)
    ptr[offset + 2] = UInt8(clamping: c.2)
    ptr[offset + 3] = 255
}

func clearBitmap(_ rep: NSBitmapImageRep) {
    let ptr = rep.bitmapData!
    let total = rep.bytesPerRow * rep.pixelsHigh
    for i in stride(from: 0, to: total, by: 4) {
        ptr[i] = 0; ptr[i+1] = 0; ptr[i+2] = 0; ptr[i+3] = 0
    }
}

// MARK: - 7x11 Bold Pixel Font

/// Each character is 7-wide x 11-tall, stored as 11 rows of UInt8 (bits 6..0 = pixels left-to-right).
/// Bold/thick strokes (2px wide) for a distinctive retro look.
/// Same font data as the Skulls skin -- shared aesthetic across bundled skins.
let pixelFont: [Character: [UInt8]] = [
    "A": [0b0011100, 0b0111110, 0b1100011, 0b1100011, 0b1100011, 0b1111111, 0b1111111, 0b1100011, 0b1100011, 0b1100011, 0b1100011],
    "B": [0b1111100, 0b1111110, 0b1100011, 0b1100011, 0b1111100, 0b1111110, 0b1100011, 0b1100011, 0b1100011, 0b1111110, 0b1111100],
    "C": [0b0111110, 0b1111111, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1111111, 0b0111110],
    "D": [0b1111100, 0b1111110, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1111110, 0b1111100],
    "E": [0b1111111, 0b1111111, 0b1100000, 0b1100000, 0b1111100, 0b1111100, 0b1100000, 0b1100000, 0b1100000, 0b1111111, 0b1111111],
    "F": [0b1111111, 0b1111111, 0b1100000, 0b1100000, 0b1111100, 0b1111100, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000],
    "G": [0b0111110, 0b1111111, 0b1100000, 0b1100000, 0b1100000, 0b1101111, 0b1100011, 0b1100011, 0b1100011, 0b1111111, 0b0111110],
    "H": [0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1111111, 0b1111111, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011],
    "I": [0b0111110, 0b0111110, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0111110, 0b0111110],
    "J": [0b0001111, 0b0001111, 0b0000110, 0b0000110, 0b0000110, 0b0000110, 0b0000110, 0b1100110, 0b1100110, 0b0111100, 0b0011000],
    "K": [0b1100011, 0b1100110, 0b1101100, 0b1111000, 0b1110000, 0b1111000, 0b1101100, 0b1100110, 0b1100011, 0b1100011, 0b1100011],
    "L": [0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1111111, 0b1111111],
    "M": [0b1100011, 0b1110111, 0b1111111, 0b1101011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011],
    "N": [0b1100011, 0b1110011, 0b1111011, 0b1101011, 0b1100111, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011],
    "O": [0b0111110, 0b1111111, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1111111, 0b0111110],
    "P": [0b1111110, 0b1111111, 0b1100011, 0b1100011, 0b1111111, 0b1111110, 0b1100000, 0b1100000, 0b1100000, 0b1100000, 0b1100000],
    "Q": [0b0111110, 0b1111111, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1101011, 0b1100110, 0b1111111, 0b0111011],
    "R": [0b1111110, 0b1111111, 0b1100011, 0b1100011, 0b1111111, 0b1111110, 0b1101100, 0b1100110, 0b1100011, 0b1100011, 0b1100011],
    "S": [0b0111110, 0b1111111, 0b1100000, 0b1110000, 0b0111110, 0b0001111, 0b0000011, 0b0000011, 0b1000011, 0b1111111, 0b0111110],
    "T": [0b1111111, 0b1111111, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100],
    "U": [0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1111111, 0b0111110],
    "V": [0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b0110110, 0b0110110, 0b0011100, 0b0011100, 0b0001000, 0b0001000],
    "W": [0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1100011, 0b1101011, 0b1111111, 0b1110111, 0b1100011, 0b1100011],
    "X": [0b1100011, 0b1100011, 0b0110110, 0b0011100, 0b0001000, 0b0001000, 0b0011100, 0b0110110, 0b1100011, 0b1100011, 0b1100011],
    "Y": [0b1100011, 0b1100011, 0b0110110, 0b0011100, 0b0001000, 0b0001000, 0b0001000, 0b0001000, 0b0001000, 0b0001000, 0b0001000],
    "Z": [0b1111111, 0b1111111, 0b0000011, 0b0000110, 0b0001100, 0b0011000, 0b0110000, 0b1100000, 0b1100000, 0b1111111, 0b1111111],
    // Lowercase -- same as uppercase for this bold style (renderer falls back via titleCharImage)
    // Digits
    "0": [0b0111110, 0b1111111, 0b1100011, 0b1100111, 0b1101011, 0b1110011, 0b1100011, 0b1100011, 0b1100011, 0b1111111, 0b0111110],
    "1": [0b0001100, 0b0011100, 0b0111100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0111111, 0b0111111],
    "2": [0b0111110, 0b1111111, 0b1100011, 0b0000011, 0b0000110, 0b0001100, 0b0011000, 0b0110000, 0b1100000, 0b1111111, 0b1111111],
    "3": [0b0111110, 0b1111111, 0b0000011, 0b0000011, 0b0011110, 0b0011110, 0b0000011, 0b0000011, 0b0000011, 0b1111111, 0b0111110],
    "4": [0b0000110, 0b0001110, 0b0011110, 0b0110110, 0b1100110, 0b1111111, 0b1111111, 0b0000110, 0b0000110, 0b0000110, 0b0000110],
    "5": [0b1111111, 0b1111111, 0b1100000, 0b1100000, 0b1111110, 0b1111111, 0b0000011, 0b0000011, 0b0000011, 0b1111111, 0b0111110],
    "6": [0b0011110, 0b0111000, 0b1100000, 0b1100000, 0b1111110, 0b1111111, 0b1100011, 0b1100011, 0b1100011, 0b1111111, 0b0111110],
    "7": [0b1111111, 0b1111111, 0b0000011, 0b0000110, 0b0001100, 0b0011000, 0b0011000, 0b0011000, 0b0011000, 0b0011000, 0b0011000],
    "8": [0b0111110, 0b1111111, 0b1100011, 0b1100011, 0b0111110, 0b0111110, 0b1100011, 0b1100011, 0b1100011, 0b1111111, 0b0111110],
    "9": [0b0111110, 0b1111111, 0b1100011, 0b1100011, 0b1100011, 0b1111111, 0b0111111, 0b0000011, 0b0000011, 0b0011110, 0b0111100],
    // Punctuation
    " ": [0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000],
    "-": [0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b1111111, 0b1111111, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000],
    ".": [0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0011000, 0b0011000, 0b0000000],
    "_": [0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b1111111, 0b1111111],
    ":": [0b0000000, 0b0000000, 0b0011000, 0b0011000, 0b0000000, 0b0000000, 0b0000000, 0b0011000, 0b0011000, 0b0000000, 0b0000000],
    "(": [0b0000110, 0b0001100, 0b0011000, 0b0110000, 0b0110000, 0b0110000, 0b0110000, 0b0011000, 0b0001100, 0b0000110, 0b0000000],
    ")": [0b0110000, 0b0011000, 0b0001100, 0b0000110, 0b0000110, 0b0000110, 0b0000110, 0b0001100, 0b0011000, 0b0110000, 0b0000000],
    "[": [0b0011110, 0b0011000, 0b0011000, 0b0011000, 0b0011000, 0b0011000, 0b0011000, 0b0011000, 0b0011000, 0b0011110, 0b0000000],
    "]": [0b0111100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0001100, 0b0111100, 0b0000000],
    "&": [0b0011100, 0b0110110, 0b0110110, 0b0011100, 0b0111000, 0b1101011, 0b1100110, 0b1100110, 0b0111011, 0b0000000, 0b0000000],
    "'": [0b0011000, 0b0011000, 0b0110000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000, 0b0000000],
    "+": [0b0000000, 0b0000000, 0b0001100, 0b0001100, 0b0111111, 0b0111111, 0b0001100, 0b0001100, 0b0000000, 0b0000000, 0b0000000],
    "#": [0b0010010, 0b0010010, 0b1111111, 0b0010010, 0b0010010, 0b1111111, 0b0010010, 0b0010010, 0b0000000, 0b0000000, 0b0000000],
    "/": [0b0000011, 0b0000110, 0b0000110, 0b0001100, 0b0001100, 0b0011000, 0b0011000, 0b0110000, 0b0110000, 0b1100000, 0b0000000],
]

let charW = 7
let charH = 11

/// Pure white -- tintColor in skin.json will recolor at render time
let white = (255, 255, 255)

func renderCharSprite(char: Character) -> NSBitmapImageRep {
    let rep = createBitmap(width: charW, height: charH)
    clearBitmap(rep)
    
    guard let rows = pixelFont[char] else { return rep }
    
    for row in 0..<charH {
        let bits = rows[row]
        for col in 0..<charW {
            if bits & (1 << (6 - col)) != 0 {
                setPixel(rep, x: col, y: row, white)
            }
        }
    }
    return rep
}

// MARK: - Character-to-filename mapping (filesystem-safe)

func charFilename(_ c: Character) -> String {
    switch c {
    case "A"..."Z": return "title_upper_\(c)"
    case "a"..."z": return "title_lower_\(c)"
    case "0"..."9": return "title_char_\(c)"
    case " ": return "title_char_space"
    case "-": return "title_char_dash"
    case ".": return "title_char_dot"
    case "_": return "title_char_underscore"
    case ":": return "title_char_colon"
    case "(": return "title_char_lparen"
    case ")": return "title_char_rparen"
    case "[": return "title_char_lbracket"
    case "]": return "title_char_rbracket"
    case "&": return "title_char_amp"
    case "'": return "title_char_apos"
    case "+": return "title_char_plus"
    case "#": return "title_char_hash"
    case "/": return "title_char_slash"
    default: return "title_char_\(c)"
    }
}

// MARK: - Main

let outputDir: String
if CommandLine.arguments.count > 1 {
    outputDir = CommandLine.arguments[1]
} else {
    outputDir = "Sources/NullPlayer/Resources/Skins/NeonWave/images"
}

// Create output directory
try! FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

print("Generating NeonWave title character sprites to: \(outputDir)")
print("(White sprites -- tinted to #00ffcc at render time via titleText.tintColor)\n")

var count = 0
for (char, _) in pixelFont {
    let rep = renderCharSprite(char: char)
    let name = charFilename(char)
    savePNG(rep, to: "\(outputDir)/\(name).png")
    count += 1
}

print("\nDone! Generated \(count) title character sprites.")
