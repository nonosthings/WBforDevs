//
//  WBForDevsWidgets.swift
//  WBForDevsWidgets
//
//  WidgetKit extension allowing contributors to preview their saved test widgets
//  directly on the iOS Home Screen or macOS Desktop.
//  This app is for developing blocks only, and may not be used for anything else.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - AppEntity & Selection Intent

struct SandboxBlueprintEntity: AppEntity {
	let id: UUID
	let title: String
	let sizeLabel: String

	static var typeDisplayRepresentation: TypeDisplayRepresentation = "Dev Widget"
	static var defaultQuery = SandboxBlueprintQuery()

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(title: "\(title)", subtitle: "\(sizeLabel)")
	}

	init(_ blueprint: SandboxBlueprint) {
		self.id = blueprint.id
		self.title = blueprint.title
		self.sizeLabel = blueprint.dimension.label
	}
}

struct SandboxBlueprintQuery: EntityQuery {
	func entities(for identifiers: [UUID]) async throws -> [SandboxBlueprintEntity] {
		let all = SandboxVault.loadBlueprints()
		return identifiers.compactMap { id in
			all.first(where: { $0.id == id }).map(SandboxBlueprintEntity.init)
		}
	}

	func suggestedEntities() async throws -> [SandboxBlueprintEntity] {
		SandboxVault.loadBlueprints().map(SandboxBlueprintEntity.init)
	}
}

struct SelectSandboxWidgetIntent: WidgetConfigurationIntent {
	static var title: LocalizedStringResource = "Select Dev Widget"
	static var description = IntentDescription("Preview a widget saved in WB for Devs.")

	@Parameter(title: "Dev Widget")
	var blueprint: SandboxBlueprintEntity?
}

// MARK: - Timeline Entry & Provider

struct SandboxTimelineEntry: TimelineEntry {
	let date: Date
	let blueprint: SandboxBlueprint?
}

struct SandboxTimelineProvider: AppIntentTimelineProvider {
	func placeholder(in context: Context) -> SandboxTimelineEntry {
		SandboxTimelineEntry(date: .now, blueprint: SandboxVault.loadBlueprints().first)
	}

	func snapshot(for configuration: SelectSandboxWidgetIntent, in context: Context) async -> SandboxTimelineEntry {
		resolveEntry(for: configuration, date: .now)
	}

	func timeline(for configuration: SelectSandboxWidgetIntent, in context: Context) async -> Timeline<SandboxTimelineEntry> {
		let entry = resolveEntry(for: configuration, date: .now)
		return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900)))
	}

	private func resolveEntry(for configuration: SelectSandboxWidgetIntent, date: Date) -> SandboxTimelineEntry {
		let all = SandboxVault.loadBlueprints()
		let chosen = all.first(where: { $0.id == configuration.blueprint?.id }) ?? all.first
		return SandboxTimelineEntry(date: date, blueprint: chosen)
	}
}

// MARK: - Home Screen / Desktop Widget View

struct SandboxWidgetEntryView: View {
	let entry: SandboxTimelineEntry

	var body: some View {
		Group {
			if IntegritySeal.isUnauthorizedDistribution || !IntegritySeal.isSealIntact {
				VStack(spacing: 4) {
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundStyle(.red)
					Text(IntegritySeal.stolenCodeTitle)
						.font(.caption2.bold())
						.multilineTextAlignment(.center)
				}
				.padding(8)
			} else if let blueprint = entry.blueprint {
				GeometryReader { geo in
					let scale = min(
						geo.size.width / blueprint.dimension.referenceWidth,
						geo.size.height / blueprint.dimension.referenceHeight
					) * IntegritySeal.scaleMultiplier
					ZStack {
						ForEach(blueprint.elements) { element in
							SandboxElementRenderer(
								element: element,
								scale: scale,
								referenceDate: entry.date
							)
							.padding(4 * scale)
							.rotationEffect(.degrees(element.rotationDegrees))
							.position(
								x: element.x * geo.size.width,
								y: element.y * geo.size.height
							)
						}
					}
					.frame(width: geo.size.width, height: geo.size.height)
				}
			} else {
				VStack(spacing: 6) {
					Image(systemName: "hammer.fill")
						.font(.title3)
					Text("Open WB for Devs and save a widget to preview it here.")
						.font(.caption)
						.multilineTextAlignment(.center)
				}
				.padding(12)
			}
		}
		.containerBackground(for: .widget) {
			if let blueprint = entry.blueprint {
				blueprint.canvasColor.swiftUIColor
			} else {
				Color.clear
			}
		}
	}
}

// MARK: - Widget Bundle

@main
struct WBForDevsWidgetBundle: WidgetBundle {
	var body: some Widget {
		WBForDevsPreviewWidget()
	}
}

struct WBForDevsPreviewWidget: Widget {
	private var supportedFamilies: [WidgetFamily] {
		var list: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
		#if os(iOS) || os(macOS)
		if #available(iOS 27.0, macOS 27.0, *) {
			list.append(.systemExtraLargePortrait)
		}
		#endif
		return list
	}

	var body: some WidgetConfiguration {
		AppIntentConfiguration(
			kind: SandboxVault.widgetKindIdentifier,
			intent: SelectSandboxWidgetIntent.self,
			provider: SandboxTimelineProvider()
		) { entry in
			SandboxWidgetEntryView(entry: entry)
		}
		.configurationDisplayName("WB for Devs Preview")
		.description("This app is for developing blocks only, and may not be used for anything else.")
		.supportedFamilies(supportedFamilies)
		.contentMarginsDisabled()
	}
}
