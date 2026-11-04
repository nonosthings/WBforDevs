//
//  NewBlockTemplate.swift
//  WidgetBlocks Community Block Starter Template (WB for Devs)
//


import SwiftUI

struct ExampleContributorBlock: CommunityBlock {
	static let blockId = "exampleContributorBlock"
	static let title = "Hydration Tracker"
	static let subtitle = "Daily water intake goal reminder"
	static let symbol = "drop.fill"
	static let authorGitHubHandle = "your-github-username"
	static let categoryColor: Color = .cyan

	static func makeView(block: DesignBlock, scale: Double) -> some View {
		HStack(spacing: 6 * scale) {
			Image(systemName: symbol)
				.imageScale(.medium)
			Text(block.text.isEmpty ? "8 cups" : block.text)
				.font(block.font.font(size: block.fontSize * scale))
				.lineLimit(1)
		}
	}
}
