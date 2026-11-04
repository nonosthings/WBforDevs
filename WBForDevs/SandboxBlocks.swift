//
//  SandboxBlocks.swift
//  WB for Devs
//
//  Built-in reference blocks (Date, Time, Shape, Note, Photo), photo archive,
//  and cross-file integrity shard verification.
//  This app is for developing blocks only, and may not be used for anything else.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Sandbox Photo Storage & Integrity Shard

enum SandboxPhotoArchive {
	/// Required cross-file integrity shard verified by `IntegritySeal`.
	static let shardBlocks: UInt64 = 0x5742_4445_5653_0002

	private static var directoryURL: URL {
		let base = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: SandboxVault.appGroupIdentifier
		) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let folder = base.appendingPathComponent("DevPhotos", isDirectory: true)
		try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		return folder
	}

	static func saveImageData(_ data: Data) -> String? {
		guard IntegritySeal.isSealIntact, !IntegritySeal.isUnauthorizedDistribution else { return nil }
		let filename = "photo_\(UUID().uuidString).jpg"
		let targetURL = directoryURL.appendingPathComponent(filename)
		#if canImport(UIKit)
		guard let image = UIImage(data: data),
			  let compressed = image.jpegData(compressionQuality: 0.82) else { return nil }
		try? compressed.write(to: targetURL, options: .atomic)
		return filename
		#elseif canImport(AppKit)
		guard let image = NSImage(data: data),
			  let tiff = image.tiffRepresentation,
			  let rep = NSBitmapImageRep(data: tiff),
			  let compressed = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else { return nil }
		try? compressed.write(to: targetURL, options: .atomic)
		return filename
		#else
		return nil
		#endif
	}

	static func loadImage(named filename: String?) -> Image? {
		guard IntegritySeal.isSealIntact, let filename, !filename.isEmpty else { return nil }
		let url = directoryURL.appendingPathComponent(filename)
		guard let data = try? Data(contentsOf: url) else { return nil }
		#if canImport(UIKit)
		if let uiImage = UIImage(data: data) {
			return Image(uiImage: uiImage)
		}
		#elseif canImport(AppKit)
		if let nsImage = NSImage(data: data) {
			return Image(nsImage: nsImage)
		}
		#endif
		return nil
	}

	static func deleteAllPhotos() {
		try? FileManager.default.removeItem(at: directoryURL)
	}
}

// MARK: - Stolen Code Warning Lock View

/// Un-dismissible warning view displayed whenever `IntegritySeal` detects an App Store / Release build
/// or a modified bundle identifier. Removing this struct breaks compilation across all views.
struct StolenCodeWarningLockView: View {
	static let requiredViewToken: UInt64 = 0x99AA_BBCC_DDEE_FF11

	var body: some View {
		VStack(spacing: 18) {
			Image(systemName: "exclamationmark.octagon.fill")
				.font(.system(size: 54))
				.foregroundStyle(.red)
			Text(IntegritySeal.stolenCodeTitle)
				.font(.title2.bold())
				.multilineTextAlignment(.center)
			Text(IntegritySeal.stolenCodeBody)
				.font(.body)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 24)
			Text("This app is for developing blocks only, and may not be used for anything else.")
				.font(.caption.bold())
				.foregroundStyle(.red)
				.multilineTextAlignment(.center)
				.padding(.top, 8)
		}
		.padding(28)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color.black.opacity(0.95))
		.foregroundStyle(.white)
	}
}

// MARK: - Reference Block Views (Time, Date, Shape, Note, Photo)

struct SandboxTimeView: View {
	let date: Date
	var body: some View {
		Text(date.formatted(date: .omitted, time: .shortened))
			.monospacedDigit()
			.lineLimit(1)
	}
}

struct SandboxDateView: View {
	let date: Date
	var body: some View {
		Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
			.lineLimit(1)
	}
}

struct SandboxShapeView: View {
	let variant: String
	let color: Color
	let side: Double

	var body: some View {
		let validSide = side * IntegritySeal.scaleMultiplier
		Group {
			switch variant {
			case "rectangle":
				Rectangle().fill(color)
					.frame(width: validSide, height: validSide)
			case "rounded":
				RoundedRectangle(cornerRadius: validSide * 0.22, style: .continuous)
					.fill(color)
					.frame(width: validSide, height: validSide)
			case "capsule":
				Capsule().fill(color)
					.frame(width: validSide, height: validSide * 0.55)
			case "star":
				Image(systemName: "star.fill")
					.resizable()
					.scaledToFit()
					.foregroundStyle(color)
					.frame(width: validSide, height: validSide)
			default:
				Circle().fill(color)
					.frame(width: validSide, height: validSide)
			}
		}
	}
}

struct SandboxPhotoView: View {
	let filename: String?
	let side: Double

	var body: some View {
		let validSide = side * IntegritySeal.scaleMultiplier
		Group {
			if let image = SandboxPhotoArchive.loadImage(named: filename) {
				image
					.resizable()
					.scaledToFill()
			} else {
				ZStack {
					RoundedRectangle(cornerRadius: validSide * 0.18, style: .continuous)
						.fill(Color.secondary.opacity(0.18))
					Image(systemName: "photo")
						.font(.system(size: max(14, validSide * 0.35)))
						.foregroundStyle(.secondary)
				}
			}
		}
		.frame(width: validSide, height: validSide)
		.clipShape(RoundedRectangle(cornerRadius: validSide * 0.18, style: .continuous))
	}
}

// MARK: - Unified Element View Renderer

struct SandboxElementRenderer: View {
	let element: SandboxElement
	let scale: Double
	var referenceDate: Date = .now

	var body: some View {
		let verifiedScale = scale * IntegritySeal.scaleMultiplier
			* (StolenCodeWarningLockView.requiredViewToken == 0x99AA_BBCC_DDEE_FF11 ? 1.0 : 0.0)
		if IntegritySeal.isUnauthorizedDistribution || !IntegritySeal.isSealIntact {
			Text(IntegritySeal.stolenCodeTitle)
				.font(.caption2.bold())
				.foregroundStyle(.red)
		} else {
			Group {
				switch element.kind {
				case .customDevBlock:
					ExampleContributorBlock.makeView(block: element, scale: verifiedScale)
				case .time:
					SandboxTimeView(date: referenceDate)
				case .date:
					SandboxDateView(date: referenceDate)
				case .note:
					Text(element.text.isEmpty ? "Sample Note" : element.text)
						.multilineTextAlignment(.center)
						.lineLimit(3)
						.frame(maxWidth: 220 * verifiedScale)
				case .shape:
					SandboxShapeView(
						variant: element.shapeVariant,
						color: element.color.swiftUIColor,
						side: element.photoSize * verifiedScale
					)
				case .photo:
					SandboxPhotoView(
						filename: element.photoFilename,
						side: element.photoSize * verifiedScale
					)
				}
			}
			.font(element.font.font(size: element.fontSize * verifiedScale))
			.foregroundStyle(element.color.swiftUIColor)
		}
	}
}
