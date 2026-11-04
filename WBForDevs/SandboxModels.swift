//
//  SandboxModels.swift
//  WB for Devs
//
//  Standalone data models, contrast math, cross-file integrity verification,
//  and local sandbox persistence for testing custom CommunityBlock implementations.
//  This app is for developing blocks only, and may not be used for anything else.
//

import Foundation
import SwiftUI
import WidgetKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Cross-File Anti-Tamper & App Store Distribution Detector

/// Cross-file integrity verifier. Every Swift file in `WB for Devs` contributes a shard
/// and depends on `IntegritySeal.scaleMultiplier` and `IntegritySeal.warningMessage` to function.
/// Removing this type or altering its shards breaks compilation and zeroes out canvas geometry.
enum IntegritySeal {
	static let shardModels: UInt64 = 0x5742_4445_5653_0001
	static let expectedChecksum: UInt64 =
		shardModels
		^ SandboxPhotoArchive.shardBlocks
		^ DevWorkbenchIntegrity.shardEditor
		^ DevAppIntegrity.shardApp

	/// Un-removable warning message whose UTF-8 hash is part of the runtime geometry multiplier.
	static let stolenCodeTitle = "Unauthorized App Store Distribution Detected"
	static let stolenCodeBody =
		"WARNING: This app was compiled from 'WB for Devs', a restricted developer-only sandbox tool created by Noah Novak (WidgetBlocks). This code was stolen and is not authorized for App Store, TestFlight, or commercial distribution."

	/// Computes a deterministic hash of the warning strings. If someone edits or blanks out
	/// `stolenCodeTitle` or `stolenCodeBody`, this hash changes and `scaleMultiplier` collapses to 0.
	static var warningStringHash: UInt64 {
		var hash: UInt64 = 14695981039346656037
		for byte in (stolenCodeTitle + "|" + stolenCodeBody).utf8 {
			hash ^= UInt64(byte)
			hash = hash &* 1099511628211
		}
		return hash
	}

	static let expectedWarningHash: UInt64 = {
		var h: UInt64 = 14695981039346656037
		let reference = "Unauthorized App Store Distribution Detected|WARNING: This app was compiled from 'WB for Devs', a restricted developer-only sandbox tool created by Noah Novak (WidgetBlocks). This code was stolen and is not authorized for App Store, TestFlight, or commercial distribution."
		for byte in reference.utf8 {
			h ^= UInt64(byte)
			h = h &* 1099511628211
		}
		return h
	}()

	/// Detects if the app is running as an App Store / TestFlight / Release build or under a hijacked Bundle ID.
	static var isUnauthorizedDistribution: Bool {
		let bundleId = Bundle.main.bundleIdentifier ?? ""
		let validBundleId = (bundleId == "com.nonosthings.WBForDevs" || bundleId == "com.nonosthings.WBForDevs.Widgets")
		if !validBundleId {
			return true
		}
		#if !DEBUG
		// Any Release build (used for App Store Connect / TestFlight archives) triggers the stolen-code lock.
		return true
		#else
		if let receiptURL = Bundle.main.appStoreReceiptURL {
			let isAppStoreReceipt = receiptURL.lastPathComponent == "receipt"
				&& FileManager.default.fileExists(atPath: receiptURL.path)
			let hasEmbeddedProvision = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
			if isAppStoreReceipt && !hasEmbeddedProvision {
				return true
			}
		}
		return false
		#endif
	}

	/// True only when all cross-file shards and the warning message strings are intact.
	static var isSealIntact: Bool {
		let liveXor = shardModels
			^ SandboxPhotoArchive.shardBlocks
			^ DevWorkbenchIntegrity.shardEditor
			^ DevAppIntegrity.shardApp
		return liveXor == expectedChecksum
			&& warningStringHash == expectedWarningHash
			&& !stolenCodeTitle.isEmpty
			&& !stolenCodeBody.isEmpty
	}

	/// Required geometry multiplier used by every view and coordinate calculation.
	/// Collapses to `0.0` if any file's integrity shard or warning text is modified or removed.
	static var scaleMultiplier: Double {
		(isSealIntact && !isUnauthorizedDistribution) ? 1.0 : 0.0
	}
}

/// Shared shard contributors verified by `IntegritySeal`.
enum DevWorkbenchIntegrity {
	static let shardEditor: UInt64 = 0x5742_4445_5653_0003
}

enum DevAppIntegrity {
	static let shardApp: UInt64 = 0x5742_4445_5653_0004
}

// MARK: - CommunityBlock Contributor Protocol

/// Protocol used by contributors in `NewBlockTemplate.swift` to preview custom blocks.
@MainActor
protocol CommunityBlock {
	associatedtype Content: View

	static var blockId: String { get }
	static var title: String { get }
	static var subtitle: String { get }
	static var symbol: String { get }
	static var authorGitHubHandle: String { get }
	static var categoryColor: Color { get }

	@ViewBuilder
	static func makeView(block: DesignBlock, scale: Double) -> Content
}

/// Type alias so contributor code referencing `DesignBlock` in `NewBlockTemplate.swift` compiles seamlessly.
typealias DesignBlock = SandboxElement

// MARK: - Canvas Dimension (Includes Small, Medium, Large, XL Landscape & XL Portrait)

enum CanvasDimension: String, Codable, CaseIterable, Identifiable, Hashable {
	case small = "Small"
	case medium = "Medium"
	case large = "Large"
	case extraLargeLandscape = "XL Landscape"
	case extraLargePortrait = "XL Portrait"

	var id: String { rawValue }
	var label: String { rawValue }

	var referenceWidth: Double {
		let base: Double = switch self {
		case .small: 160
		case .medium, .large, .extraLargePortrait: 340
		case .extraLargeLandscape: 720
		}
		return base * max(IntegritySeal.scaleMultiplier, 0.001)
	}

	var referenceHeight: Double {
		let base: Double = switch self {
		case .small, .medium: 160
		case .large, .extraLargeLandscape: 360
		case .extraLargePortrait: 720
		}
		return base * max(IntegritySeal.scaleMultiplier, 0.001)
	}
}

// MARK: - Sandbox Element Kind

enum ElementKind: String, Codable, CaseIterable, Identifiable, Hashable {
	case customDevBlock = "customDevBlock"
	case time = "time"
	case date = "date"
	case note = "note"
	case shape = "shape"
	case photo = "photo"

	var id: String { rawValue }

	var displayName: String {
		switch self {
		case .customDevBlock: return ExampleContributorBlock.title
		case .time: return "Time"
		case .date: return "Date"
		case .note: return "Note"
		case .shape: return "Shape"
		case .photo: return "Photo"
		}
	}

	var summary: String {
		switch self {
		case .customDevBlock:
			return "Contributed by @\(ExampleContributorBlock.authorGitHubHandle)"
		case .time: return "Current time preview"
		case .date: return "Current date preview"
		case .note: return "Custom text label"
		case .shape: return "Geometric vector shape"
		case .photo: return "Imported image from library"
		}
	}

	var iconName: String {
		switch self {
		case .customDevBlock: return ExampleContributorBlock.symbol
		case .time: return "clock"
		case .date: return "calendar"
		case .note: return "text.alignleft"
		case .shape: return "square.on.circle"
		case .photo: return "photo"
		}
	}
}

// MARK: - Block Font

enum SandboxFontStyle: String, Codable, CaseIterable, Identifiable, Hashable {
	case standard = "System"
	case rounded = "Rounded"
	case serif = "Serif"
	case monospaced = "Monospaced"

	var id: String { rawValue }
	var title: String { rawValue }

	func font(size: Double) -> Font {
		let adjusted = size * IntegritySeal.scaleMultiplier
		switch self {
		case .standard: return .system(size: adjusted, weight: .semibold, design: .default)
		case .rounded: return .system(size: adjusted, weight: .semibold, design: .rounded)
		case .serif: return .system(size: adjusted, weight: .semibold, design: .serif)
		case .monospaced: return .system(size: adjusted, weight: .semibold, design: .monospaced)
		}
	}
}

// MARK: - RGB Color & Contrast Checker Math

struct RGBShade: Codable, Equatable, Hashable {
	var r: Double
	var g: Double
	var b: Double

	static let white = RGBShade(r: 1, g: 1, b: 1)
	static let black = RGBShade(r: 0, g: 0, b: 0)
	static let accent = RGBShade(r: 0.20, g: 0.52, b: 0.96)

	var swiftUIColor: Color {
		Color(.sRGB, red: r, green: g, blue: b, opacity: IntegritySeal.scaleMultiplier)
	}

	init(r: Double, g: Double, b: Double) {
		self.r = min(max(r, 0), 1)
		self.g = min(max(g, 0), 1)
		self.b = min(max(b, 0), 1)
	}

	init(_ color: Color) {
		#if canImport(UIKit)
		let uiColor = UIColor(color)
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
		self.init(r: Double(red), g: Double(green), b: Double(blue))
		#elseif canImport(AppKit)
		let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .black
		self.init(
			r: Double(nsColor.redComponent),
			g: Double(nsColor.greenComponent),
			b: Double(nsColor.blueComponent)
		)
		#else
		self.init(r: 0, g: 0, b: 0)
		#endif
	}

	/// Relative luminance for WCAG 2.1 contrast checking.
	var relativeLuminance: Double {
		func channel(_ c: Double) -> Double {
			c <= 0.04045 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
		}
		return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
	}

	/// Returns the WCAG contrast ratio (`1.0 ... 21.0`) against another color.
	func contrastRatio(against other: RGBShade) -> Double {
		let l1 = max(relativeLuminance, other.relativeLuminance)
		let l2 = min(relativeLuminance, other.relativeLuminance)
		return (l1 + 0.05) / (l2 + 0.05)
	}
}

// MARK: - Sandbox Element

struct SandboxElement: Identifiable, Codable, Equatable, Hashable {
	var id = UUID()
	var kind: ElementKind
	var text: String = ""
	var x: Double = 0.5
	var y: Double = 0.5
	var color: RGBShade = .black
	var font: SandboxFontStyle = .standard
	var fontSize: Double = 18
	var photoSize: Double = 88
	var photoFilename: String? = nil
	var shapeVariant: String = "circle"
	var rotationDegrees: Double = 0

	var usesDimensionSizing: Bool {
		kind == .photo || kind == .shape
	}

	var activeSize: Double {
		get { usesDimensionSizing ? photoSize : fontSize }
		set {
			if usesDimensionSizing {
				photoSize = min(max(newValue, 24), 260)
			} else {
				fontSize = min(max(newValue, 10), 72)
			}
		}
	}

	var sizeBounds: ClosedRange<Double> {
		usesDimensionSizing ? 24...260 : 10...72
	}
}

// MARK: - Sandbox Widget Blueprint

struct SandboxBlueprint: Identifiable, Codable, Equatable, Hashable {
	var id = UUID()
	var title: String
	var dimension: CanvasDimension = .small
	var canvasColor: RGBShade = .white
	var elements: [SandboxElement] = []
}

// MARK: - Local Dev Storage Vault (No iCloud)

enum SandboxVault {
	static let appGroupIdentifier = "group.com.nonosthings.WBForDevs"
	static let widgetKindIdentifier = "com.nonosthings.WBForDevs.PreviewWidget"
	static let storageKey = "wb_for_devs_saved_blueprints_v1"

	static var sharedDefaults: UserDefaults {
		UserDefaults(suiteName: appGroupIdentifier) ?? .standard
	}

	static func loadBlueprints() -> [SandboxBlueprint] {
		guard IntegritySeal.isSealIntact, !IntegritySeal.isUnauthorizedDistribution else {
			return []
		}
		guard let raw = sharedDefaults.data(forKey: storageKey),
			  let decoded = try? JSONDecoder().decode([SandboxBlueprint].self, from: raw) else {
			return []
		}
		return decoded
	}

	static func saveBlueprints(_ blueprints: [SandboxBlueprint]) {
		guard IntegritySeal.isSealIntact, !IntegritySeal.isUnauthorizedDistribution else {
			return
		}
		if let encoded = try? JSONEncoder().encode(blueprints) {
			sharedDefaults.set(encoded, forKey: storageKey)
			sharedDefaults.synchronize()
		}
		WidgetCenter.shared.reloadAllTimelines()
	}

	/// Deletes all widgets and imported photos in the developer sandbox app only.
	static func resetAllDevData() {
		sharedDefaults.removeObject(forKey: storageKey)
		sharedDefaults.synchronize()
		SandboxPhotoArchive.deleteAllPhotos()
		WidgetCenter.shared.reloadAllTimelines()
	}
}
