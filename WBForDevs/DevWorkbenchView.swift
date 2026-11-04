//
//  DevWorkbenchView.swift
//  WB for Devs
//
//  Interactive developer widget editor with Undo/Redo, Widget Naming,
//  Size Picker Menu (Small, Medium, Large, XL Landscape, XL Portrait),
//  Background Color Picker, Alignment & Snap Guides, Haptics, and WCAG
//  Contrast Checker.
//  This app is for developing blocks only, and may not be used for anything else.
//

import PhotosUI
import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - Developer Workbench Editor

struct DevWorkbenchView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var blueprint: SandboxBlueprint
	let onCommitSave: (SandboxBlueprint) -> Void

	@State private var selectedElementId: UUID? = nil
	@State private var undoHistory: [SandboxBlueprint] = []
	@State private var redoHistory: [SandboxBlueprint] = []
	@State private var dragStartSnapshot: SandboxBlueprint? = nil

	@State private var showingAddDrawer = false
	@State private var activeGuideX: Double? = nil
	@State private var activeGuideY: Double? = nil
	@State private var hapticPulse = 0

	@AppStorage("devHapticsEnabled") private var hapticsEnabled = true
	@AppStorage("devShowsGuides") private var showsGuides = true
	@AppStorage("devSnapsToGuides") private var snapsToGuides = true

	init(blueprint: SandboxBlueprint, onCommitSave: @escaping (SandboxBlueprint) -> Void) {
		_blueprint = State(initialValue: blueprint)
		self.onCommitSave = onCommitSave
	}

	// MARK: Undo / Redo & Contrast Checker

	private func pushUndoSnapshot() {
		if undoHistory.last == blueprint { return }
		undoHistory.append(blueprint)
		if undoHistory.count > 40 {
			undoHistory.removeFirst()
		}
		redoHistory.removeAll()
	}

	private func performUndo() {
		guard let prev = undoHistory.popLast() else { return }
		redoHistory.append(blueprint)
		blueprint = prev
	}

	private func performRedo() {
		guard let next = redoHistory.popLast() else { return }
		undoHistory.append(blueprint)
		blueprint = next
	}

	/// Returns elements that fail the WCAG 4.5:1 contrast check against the widget background color.
	private var lowContrastElements: [SandboxElement] {
		blueprint.elements.filter { item in
			guard item.kind != .photo else { return false }
			return item.color.contrastRatio(against: blueprint.canvasColor) < 4.5
		}
	}

	private var canSaveBlueprint: Bool {
		!blueprint.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	// MARK: Deconstructed Subviews

	private var topConfigBar: some View {
		HStack(spacing: 12) {
			TextField("Widget Name", text: $blueprint.title)
				.textFieldStyle(.plain)
				.font(.subheadline.weight(.medium))
				.padding(.horizontal, 12)
				.padding(.vertical, 8)
				.background(Color.secondary.opacity(0.10), in: Capsule())
				.frame(maxWidth: 220)

			// Size Selector Menu Pill (prevents label squishing and supports all 5 sizes including XL)
			Menu {
				ForEach(CanvasDimension.allCases) { dim in
					Button {
						pushUndoSnapshot()
						blueprint.dimension = dim
					} label: {
						if blueprint.dimension == dim {
							Label(dim.label, systemImage: "checkmark")
						} else {
							Text(dim.label)
						}
					}
				}
			} label: {
				HStack(spacing: 6) {
					Image(systemName: "square.dashed")
					Text(blueprint.dimension.label)
						.lineLimit(1)
					Image(systemName: "chevron.up.chevron.down")
						.font(.caption2)
				}
				.font(.subheadline.weight(.medium))
				.fixedSize(horizontal: true, vertical: false)
				.padding(.horizontal, 14)
				.padding(.vertical, 8)
				.background(Color.secondary.opacity(0.12), in: Capsule())
			}
			.buttonStyle(.plain)

			HStack(spacing: 6) {
				Text("BG")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.secondary)
					.fixedSize()
				// Keep ColorPicker inline (never inside a Menu)
				ColorPicker(
					"Background Color",
					selection: Binding(
						get: { blueprint.canvasColor.swiftUIColor },
						set: { newColor in
							pushUndoSnapshot()
							blueprint.canvasColor = RGBShade(newColor)
						}
					),
					supportsOpacity: false
				)
				.labelsHidden()
				.fixedSize()
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 6)
			.background(Color.secondary.opacity(0.10), in: Capsule())
		}
	}

	private var contrastWarningBanner: some View {
		Group {
			if !lowContrastElements.isEmpty {
				Label(
					"Contrast Check Failed: \(lowContrastElements.count) \(lowContrastElements.count == 1 ? "block has" : "blocks have") a contrast ratio below 4.5:1 against the background color.",
					systemImage: "exclamationmark.triangle.fill"
				)
				.font(.callout)
				.padding(12)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
			}
		}
	}

	@ViewBuilder
	private var bottomInspectorBar: some View {
		if let selectedId = selectedElementId,
		   let index = blueprint.elements.firstIndex(where: { $0.id == selectedId }) {
			DevElementInspector(
				element: blueprint.elements[index],
				onMutate: { transform in
					pushUndoSnapshot()
					transform(&blueprint.elements[index])
				},
				onDelete: {
					pushUndoSnapshot()
					blueprint.elements.remove(at: index)
					selectedElementId = nil
				},
				onDone: {
					selectedElementId = nil
				}
			)
			.padding(.horizontal, 16)
			.padding(.bottom, 12)
		}
	}

	var body: some View {
		if IntegritySeal.isUnauthorizedDistribution || !IntegritySeal.isSealIntact {
			StolenCodeWarningLockView()
		} else {
			ZStack(alignment: .bottom) {
				ScrollView {
					VStack(spacing: 20) {
						topConfigBar

						SandboxInteractiveCanvas(
							blueprint: blueprint,
							selectedElementId: $selectedElementId,
							showsGuides: showsGuides,
							activeGuideX: activeGuideX,
							activeGuideY: activeGuideY,
							onDragMove: { id, newX, newY in
								handleElementDrag(id: id, proposedX: newX, proposedY: newY)
							},
							onDragEnd: {
								if let start = dragStartSnapshot, start != blueprint {
									undoHistory.append(start)
									if undoHistory.count > 40 { undoHistory.removeFirst() }
									redoHistory.removeAll()
								}
								dragStartSnapshot = nil
								activeGuideX = nil
								activeGuideY = nil
							}
						)
						.frame(maxWidth: max(blueprint.dimension.referenceWidth * IntegritySeal.scaleMultiplier, 300))
						.frame(maxWidth: .infinity)

						contrastWarningBanner

						Text("This app is for developing blocks only, and may not be used for anything else.")
							.font(.caption2)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
							.padding(.top, 8)
					}
					.padding(24)
					.padding(.bottom, selectedElementId != nil ? 180 : 24)
				}

				bottomInspectorBar
			}
			.navigationTitle("Block Workbench")
			#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
			.sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: hapticPulse)
			#else
			.sensoryFeedback(.alignment, trigger: hapticPulse)
			#endif
			.toolbar {
				ToolbarItemGroup(placement: .primaryAction) {
					Button(action: performUndo) {
						Label("Undo", systemImage: "arrow.uturn.backward")
					}
					.disabled(undoHistory.isEmpty)

					Button(action: performRedo) {
						Label("Redo", systemImage: "arrow.uturn.forward")
					}
					.disabled(redoHistory.isEmpty)

					Button {
						showingAddDrawer = true
					} label: {
						Label("Add Block", systemImage: "plus.circle.fill")
					}

					Button {
						guard canSaveBlueprint else { return }
						blueprint.title = blueprint.title.trimmingCharacters(in: .whitespacesAndNewlines)
						onCommitSave(blueprint)
						dismiss()
					} label: {
						Label("Save", systemImage: "checkmark")
					}
					.buttonStyle(.borderedProminent)
					.disabled(!canSaveBlueprint)
				}
			}
			.sheet(isPresented: $showingAddDrawer) {
				DevAddElementDrawer { chosenKind in
					pushUndoSnapshot()
					var fresh = SandboxElement(kind: chosenKind)
					fresh.color = blueprint.canvasColor.relativeLuminance < 0.4 ? .white : .black
					blueprint.elements.append(fresh)
					selectedElementId = fresh.id
					showingAddDrawer = false
				}
				.frame(minWidth: 380, idealWidth: 440, minHeight: 420, idealHeight: 500)
			}
		}
	}

	// MARK: Alignment & Guide Snapping

	private func handleElementDrag(id: UUID, proposedX: Double, proposedY: Double) {
		if dragStartSnapshot == nil {
			dragStartSnapshot = blueprint
		}
		guard let idx = blueprint.elements.firstIndex(where: { $0.id == id }) else { return }

		var finalX = min(max(proposedX, 0.08), 0.92)
		var finalY = min(max(proposedY, 0.08), 0.92)
		var matchedX: Double? = nil
		var matchedY: Double? = nil

		if showsGuides && snapsToGuides {
			let peerX = blueprint.elements.filter { $0.id != id }.map(\.x)
			let peerY = blueprint.elements.filter { $0.id != id }.map(\.y)
			let candidatesX = [0.25, 0.5, 0.75] + peerX
			let candidatesY = [0.25, 0.5, 0.75] + peerY

			if let snapX = candidatesX.min(by: { abs($0 - finalX) < abs($1 - finalX) }),
			   abs(snapX - finalX) * blueprint.dimension.referenceWidth < 6.0 {
				finalX = snapX
				matchedX = snapX
			}
			if let snapY = candidatesY.min(by: { abs($0 - finalY) < abs($1 - finalY) }),
			   abs(snapY - finalY) * blueprint.dimension.referenceHeight < 6.0 {
				finalY = snapY
				matchedY = snapY
			}
		}

		if showsGuides && ((activeGuideX == nil && matchedX != nil) || (activeGuideY == nil && matchedY != nil)) {
			if hapticsEnabled {
				hapticPulse += 1
				#if os(macOS)
				NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
				#endif
			}
		}

		activeGuideX = matchedX
		activeGuideY = matchedY
		blueprint.elements[idx].x = finalX
		blueprint.elements[idx].y = finalY
	}
}

// MARK: - Interactive Canvas View

struct SandboxInteractiveCanvas: View {
	let blueprint: SandboxBlueprint
	@Binding var selectedElementId: UUID?
	var isInteractive = true
	var showsGuides = false
	var activeGuideX: Double? = nil
	var activeGuideY: Double? = nil
	var onDragMove: (UUID, Double, Double) -> Void = { _, _, _ in }
	var onDragEnd: () -> Void = {}

	@State private var dragStartPoint: CGPoint? = nil

	var body: some View {
		GeometryReader { geo in
			let scale = geo.size.width / blueprint.dimension.referenceWidth
			ZStack {
				RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
					.fill(blueprint.canvasColor.swiftUIColor)
					.onTapGesture {
						if isInteractive { selectedElementId = nil }
					}

				if isInteractive && showsGuides {
					guideLinesOverlay(in: geo.size)
						.allowsHitTesting(false)
				}

				ForEach(blueprint.elements) { element in
					SandboxElementRenderer(element: element, scale: scale)
						.padding(4 * scale)
						.overlay {
							if isInteractive && selectedElementId == element.id {
								RoundedRectangle(cornerRadius: 6)
									.strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
							}
						}
						.rotationEffect(.degrees(element.rotationDegrees))
						.position(
							x: element.x * geo.size.width,
							y: element.y * geo.size.height
						)
						.gesture(
							DragGesture(minimumDistance: 2, coordinateSpace: .named("devCanvasSpace"))
								.onChanged { value in
									guard isInteractive else { return }
									if dragStartPoint == nil {
										dragStartPoint = CGPoint(x: element.x, y: element.y)
										selectedElementId = element.id
									}
									guard let start = dragStartPoint else { return }
									let nx = start.x + value.translation.width / geo.size.width
									let ny = start.y + value.translation.height / geo.size.height
									onDragMove(element.id, nx, ny)
								}
								.onEnded { _ in
									dragStartPoint = nil
									onDragEnd()
								}
						)
						.onTapGesture {
							if isInteractive { selectedElementId = element.id }
						}
				}
			}
			.coordinateSpace(name: "devCanvasSpace")
			.clipShape(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
					.strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
			)
		}
		.aspectRatio(blueprint.dimension.referenceWidth / blueprint.dimension.referenceHeight, contentMode: .fit)
	}

	private func guideLinesOverlay(in size: CGSize) -> some View {
		ZStack {
			Path { path in
				for frac in [0.25, 0.5, 0.75] {
					path.move(to: CGPoint(x: size.width * frac, y: 0))
					path.addLine(to: CGPoint(x: size.width * frac, y: size.height))
					path.move(to: CGPoint(x: 0, y: size.height * frac))
					path.addLine(to: CGPoint(x: size.width, y: size.height * frac))
				}
			}
			.stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

			Path { path in
				if let gx = activeGuideX {
					path.move(to: CGPoint(x: size.width * gx, y: 0))
					path.addLine(to: CGPoint(x: size.width * gx, y: size.height))
				}
				if let gy = activeGuideY {
					path.move(to: CGPoint(x: 0, y: size.height * gy))
					path.addLine(to: CGPoint(x: size.width, y: size.height * gy))
				}
			}
			.stroke(Color.accentColor, lineWidth: 1.5)
		}
	}
}

// MARK: - Floating Element Inspector

private struct DevElementInspector: View {
	let element: SandboxElement
	let onMutate: ((inout SandboxElement) -> Void) -> Void
	let onDelete: () -> Void
	let onDone: () -> Void

	@State private var photoPickerItem: PhotosPickerItem? = nil

	private let shapeChoices: [(String, String)] = [
		("circle", "Circle"),
		("rectangle", "Square"),
		("rounded", "Rounded"),
		("capsule", "Capsule"),
		("star", "Star")
	]

	var body: some View {
		VStack(spacing: 10) {
			HStack {
				Label(element.kind.displayName, systemImage: element.kind.iconName)
					.font(.subheadline.weight(.semibold))
				Spacer()
				Button(role: .destructive, action: onDelete) {
					Image(systemName: "trash")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)

				Button("Done", action: onDone)
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
			}

			if element.kind == .note || element.kind == .customDevBlock {
				TextField(
					element.kind == .customDevBlock ? "Custom Block Text Parameter" : "Note Text",
					text: Binding(
						get: { element.text },
						set: { newVal in onMutate { $0.text = newVal } }
					)
				)
				.textFieldStyle(.roundedBorder)
			}

			if element.kind == .shape {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 6) {
						ForEach(shapeChoices, id: \.0) { choice in
							Button {
								onMutate { $0.shapeVariant = choice.0 }
							} label: {
								Text(choice.1)
									.font(.caption.weight(element.shapeVariant == choice.0 ? .bold : .regular))
									.padding(.horizontal, 10)
									.padding(.vertical, 5)
									.background(
										element.shapeVariant == choice.0
											? Color.accentColor : Color.secondary.opacity(0.14),
										in: Capsule()
									)
									.foregroundStyle(element.shapeVariant == choice.0 ? .white : .primary)
							}
							.buttonStyle(.plain)
						}
					}
				}
			}

			if element.kind == .photo {
				PhotosPicker(selection: $photoPickerItem, matching: .images) {
					Label(
						element.photoFilename == nil ? "Select Photo" : "Replace Photo",
						systemImage: "photo.on.rectangle"
					)
					.font(.caption.weight(.semibold))
				}
				.buttonStyle(.bordered)
				.onChange(of: photoPickerItem) { _, newItem in
					guard let newItem else { return }
					Task {
						if let data = try? await newItem.loadTransferable(type: Data.self),
						   let savedName = SandboxPhotoArchive.saveImageData(data) {
							onMutate { $0.photoFilename = savedName }
						}
					}
				}
			}

			HStack(spacing: 12) {
				Text("Size")
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize()
				Slider(
					value: Binding(
						get: { element.activeSize },
						set: { newVal in onMutate { $0.activeSize = newVal } }
					),
					in: element.sizeBounds,
					step: 2
				)
				Text("\(Int(element.activeSize))")
					.font(.caption.monospacedDigit())
					.fixedSize()

				if element.kind != .photo && element.kind != .shape {
					Menu {
						ForEach(SandboxFontStyle.allCases) { style in
							Button(style.title) {
								onMutate { $0.font = style }
							}
						}
					} label: {
						Image(systemName: "textformat")
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}

				if element.kind != .photo {
					// Keep ColorPicker inline (never inside a Menu)
					ColorPicker(
						"Color",
						selection: Binding(
							get: { element.color.swiftUIColor },
							set: { newColor in onMutate { $0.color = RGBShade(newColor) } }
						),
						supportsOpacity: false
					)
					.labelsHidden()
					.fixedSize()
				}

				Button {
					onMutate {
						let next = ($0.rotationDegrees + 45).truncatingRemainder(dividingBy: 360)
						$0.rotationDegrees = next
					}
				} label: {
					Image(systemName: "rotate.right")
				}
				.buttonStyle(.bordered)
				.controlSize(.small)

				if abs(element.rotationDegrees) > 0.1 {
					Button("0°") {
						onMutate { $0.rotationDegrees = 0 }
					}
					.buttonStyle(.bordered)
					.controlSize(.small)
				}
			}
		}
		.padding(14)
		.frame(maxWidth: 460)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
		)
	}
}

// MARK: - Add Element Sheet (ScrollView + Explicit Frame for macOS & iOS)

private struct DevAddElementDrawer: View {
	let onPick: (ElementKind) -> Void
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					// Custom Developer Block Section
					VStack(alignment: .leading, spacing: 8) {
						Text("YOUR CUSTOM DEVELOPER BLOCK (NEWBLOCKTEMPLATE.SWIFT)")
							.font(.caption.weight(.semibold))
							.foregroundStyle(.secondary)
							.padding(.horizontal, 4)

						Button {
							onPick(.customDevBlock)
						} label: {
							HStack(spacing: 12) {
								Image(systemName: ElementKind.customDevBlock.iconName)
									.font(.title3.weight(.semibold))
									.foregroundStyle(ExampleContributorBlock.categoryColor)
									.frame(width: 40, height: 40)
									.background(
										ExampleContributorBlock.categoryColor.opacity(0.18),
										in: RoundedRectangle(cornerRadius: 10, style: .continuous)
									)
								VStack(alignment: .leading, spacing: 2) {
									Text(ElementKind.customDevBlock.displayName)
										.font(.headline)
										.foregroundStyle(.primary)
									Text(ElementKind.customDevBlock.summary)
										.font(.caption)
										.foregroundStyle(.secondary)
								}
								Spacer()
								Image(systemName: "plus.circle.fill")
									.font(.title3)
									.foregroundStyle(Color.accentColor)
							}
							.padding(12)
							.background(
								Color.secondary.opacity(0.10),
								in: RoundedRectangle(cornerRadius: 14, style: .continuous)
							)
							.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
						}
						.buttonStyle(.plain)
					}

					// Reference Blocks Grid
					VStack(alignment: .leading, spacing: 8) {
						Text("REFERENCE BLOCKS")
							.font(.caption.weight(.semibold))
							.foregroundStyle(.secondary)
							.padding(.horizontal, 4)

						LazyVGrid(
							columns: [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 10)],
							spacing: 10
						) {
							ForEach(ElementKind.allCases.filter { $0 != .customDevBlock }) { kind in
								Button {
									onPick(kind)
								} label: {
									VStack(alignment: .leading, spacing: 10) {
										HStack {
											Image(systemName: kind.iconName)
												.font(.system(size: 17, weight: .semibold))
												.foregroundStyle(Color.accentColor)
												.frame(width: 34, height: 34)
												.background(
													Color.accentColor.opacity(0.14),
													in: RoundedRectangle(cornerRadius: 9, style: .continuous)
												)
											Spacer()
											Image(systemName: "plus.circle.fill")
												.foregroundStyle(.secondary)
										}
										VStack(alignment: .leading, spacing: 2) {
											Text(kind.displayName)
												.font(.subheadline.weight(.semibold))
												.foregroundStyle(.primary)
											Text(kind.summary)
												.font(.caption2)
												.foregroundStyle(.secondary)
												.lineLimit(2)
										}
									}
									.padding(12)
									.frame(maxWidth: .infinity, alignment: .leading)
									.background(
										Color.secondary.opacity(0.08),
										in: RoundedRectangle(cornerRadius: 14, style: .continuous)
									)
									.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
								}
								.buttonStyle(.plain)
							}
						}
					}
				}
				.padding(18)
			}
			.navigationTitle("Add Block")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
			}
		}
		.frame(minWidth: 380, idealWidth: 440, minHeight: 420, idealHeight: 500)
	}
}
