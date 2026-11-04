//
//  WBForDevsApp.swift
//  WB for Devs
//
//  Main application entry point, Home menu showing saved developer widgets,
//  and simplified Settings sheet with Reset App confirmation and mandatory
//  developer-only footer.
//  This app is for developing blocks only, and may not be used for anything else.
//

import SwiftUI
import WidgetKit

@main
struct WBForDevsApp: App {
	var body: some Scene {
		WindowGroup {
			DevHomeScreen()
		}
	}
}

// MARK: - Developer Sandbox Home Screen

struct DevHomeScreen: View {
	@State private var blueprints: [SandboxBlueprint] = []
	@State private var activeEditorBlueprint: SandboxBlueprint? = nil
	@State private var showingSettings = false

	private static let mandatoryFooterText =
		"This app is for developing blocks only, and may not be used for anything else. This app is likely to be buggy so if you do want to help contribute, feel free to make a pull request with changes! Have fun! :)"

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 22) {
					if blueprints.isEmpty {
						VStack(spacing: 14) {
							Image(systemName: "hammer")
								.font(.system(size: 48))
								.foregroundStyle(Color.accentColor)
							Text("WB for Devs")
								.font(.title3.bold())
							Text("Tap + to create a test widget and preview your custom block alongside Date, Time, Shape, Note, and Photo blocks.")
								.font(.subheadline)
								.foregroundStyle(.secondary)
								.multilineTextAlignment(.center)
								.frame(maxWidth: 380)
							Button {
								createNewBlueprint()
							} label: {
								Label("Add Widget", systemImage: "plus")
									.font(.headline)
							}
							.buttonStyle(.borderedProminent)
						}
						.padding(.vertical, 48)
					} else {
						LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 16)], spacing: 16) {
							ForEach(blueprints) { item in
								Button {
									activeEditorBlueprint = item
								} label: {
									VStack(alignment: .leading, spacing: 10) {
										HStack {
											Text(item.title)
												.font(.headline)
												.foregroundStyle(.primary)
												.lineLimit(1)
											Spacer()
											Text(item.dimension.label)
												.font(.caption2.weight(.semibold))
												.padding(.horizontal, 8)
												.padding(.vertical, 3)
												.background(Color.secondary.opacity(0.14), in: Capsule())
												.foregroundStyle(.secondary)
										}

										SandboxInteractiveCanvas(
											blueprint: item,
											selectedElementId: .constant(nil),
											isInteractive: false
										)
										.frame(maxWidth: item.dimension == .small ? 200 : 300)
										.frame(maxWidth: .infinity)
									}
									.padding(14)
									.background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
								}
								.buttonStyle(.plain)
								.contextMenu {
									Button(role: .destructive) {
										deleteBlueprint(item.id)
									} label: {
										Label("Delete Widget", systemImage: "trash")
									}
								}
							}
						}
						.padding(.horizontal, 16)
					}

					Text(Self.mandatoryFooterText)
						.font(.footnote)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
						.padding(.horizontal, 24)
						.padding(.top, 16)
				}
				.padding(.vertical, 20)
			}
			.navigationTitle("WB for Devs")
			.toolbar {
				ToolbarItem(placement: .automatic) {
					Button {
						showingSettings = true
					} label: {
						Label("Settings", systemImage: "gearshape")
					}
				}
				ToolbarItem(placement: .primaryAction) {
					Button {
						createNewBlueprint()
					} label: {
						Label("Add Widget", systemImage: "plus")
					}
				}
			}
			.navigationDestination(item: $activeEditorBlueprint) { draft in
				DevWorkbenchView(blueprint: draft) { saved in
					upsertBlueprint(saved)
				}
			}
			.sheet(isPresented: $showingSettings) {
				DevSettingsSheet {
					SandboxVault.resetAllDevData()
					blueprints = []
				}
			}
			.onAppear {
				blueprints = SandboxVault.loadBlueprints()
			}
		}
	}

	private func createNewBlueprint() {
		let fresh = SandboxBlueprint(
			title: "Dev Widget \(blueprints.count + 1)",
			dimension: .small,
			canvasColor: .white,
			elements: [
				SandboxElement(kind: .customDevBlock, x: 0.5, y: 0.5, color: .black, fontSize: 18)
			]
		)
		activeEditorBlueprint = fresh
	}

	private func upsertBlueprint(_ updated: SandboxBlueprint) {
		if let idx = blueprints.firstIndex(where: { $0.id == updated.id }) {
			blueprints[idx] = updated
		} else {
			blueprints.append(updated)
		}
		SandboxVault.saveBlueprints(blueprints)
	}

	private func deleteBlueprint(_ id: UUID) {
		blueprints.removeAll { $0.id == id }
		SandboxVault.saveBlueprints(blueprints)
	}
}

// MARK: - Minimal Developer Settings Sheet

private struct DevSettingsSheet: View {
	@Environment(\.dismiss) private var dismiss
	let onConfirmResetAll: () -> Void

	@AppStorage("devHapticsEnabled") private var hapticsEnabled = true
	@AppStorage("devShowsGuides") private var showsGuides = true
	@AppStorage("devSnapsToGuides") private var snapsToGuides = true

	@State private var showingResetConfirmation = false

	var body: some View {
		NavigationStack {
			Form {
				Section("Editor Guides & Haptics") {
					Toggle("Enable Haptics", isOn: $hapticsEnabled)
					Toggle("Show Alignment Guides", isOn: $showsGuides)
					Toggle("Snap to Guides", isOn: $snapsToGuides)
						.disabled(!showsGuides)
				}

				Section {
					Button(role: .destructive) {
						showingResetConfirmation = true
					} label: {
						Label("Reset App (Delete All Dev Widgets)", systemImage: "trash")
					}
				} header: {
					Text("Developer Sandbox Reset")
				} footer: {
					Text("This app is for developing blocks only, and may not be used for anything else.")
				}
			}
			.formStyle(.grouped)
			.navigationTitle("Dev Settings")
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
			.alert("Reset WB for Devs?", isPresented: $showingResetConfirmation) {
				Button("Cancel", role: .cancel) {}
				Button("Delete All Dev Widgets", role: .destructive) {
					onConfirmResetAll()
					dismiss()
				}
			} message: {
				Text("This will permanently delete all saved widgets and photos inside WB for Devs. Your main WidgetBlocks app data is unaffected.")
			}
		}
	}
}
