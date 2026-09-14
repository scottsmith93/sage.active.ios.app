import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                profileSummary
                    .listRowBackground(SageActiveTheme.profileHighlightBackground)

                SettingsReferenceRow(icon: .edit, title: "Change account details")
                    .listRowBackground(SageActiveTheme.cardBackground)
            }

            Section {
                businessSummary
                    .listRowBackground(SageActiveTheme.cardBackground)

                SettingsReferenceRow(icon: .switchBusiness, title: "Switch business")
                    .listRowBackground(SageActiveTheme.cardBackground)
            }

            Section {
                SettingsReferenceRow(icon: .language, title: "English (United Kingdom)")
                    .listRowBackground(SageActiveTheme.cardBackground)
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Language settings")
                        .font(.subheadline)
                        .foregroundStyle(SageActiveTheme.primaryText)

                    Text("The app will show content in the language you select, whenever possible.")
                        .font(.footnote)
                        .foregroundStyle(SageActiveTheme.supportingText)
                }
                .textCase(nil)
            }

            Section {
                SettingsReferenceRow(icon: .feedback, title: "Give feedback")
                SettingsReferenceRow(icon: .help, title: "Help centre")
                SettingsReferenceRow(icon: .shieldWithTick, title: "Privacy policy")
            }
            .listRowBackground(SageActiveTheme.cardBackground)

            Section {
                SettingsReferenceRow(
                    icon: .logout,
                    title: "Log out",
                    iconColor: SageActiveTheme.negativeVisual,
                    titleColor: SageActiveTheme.negativeVisual
                )
            }
            .listRowBackground(SageActiveTheme.cardBackground)
        }
        .listStyle(.insetGrouped)
        .listRowSeparatorTint(Color(.separator))
        .scrollContentBackground(.hidden)
        .background(SageActiveTheme.pageBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SageCarbonToolbarButton(
                    icon: .chevronLeft,
                    accessibilityLabel: "Back"
                ) {
                    dismiss()
                }
            }
        }
    }

    private var profileSummary: some View {
        HStack(spacing: 8) {
            ProfileAvatar(initials: "EP")

            VStack(alignment: .leading, spacing: 4) {
                Text("Emma Petit")
                    .font(.headline)
                    .foregroundStyle(SageActiveTheme.primaryText)

                Text("emma.petit@rennestech.fr")
                    .font(.caption)
                    .foregroundStyle(SageActiveTheme.supportingText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 74)
    }

    private var businessSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Business")
                .font(.footnote)
                .foregroundStyle(SageActiveTheme.supportingText)

            Text("LETA Construction")
                .font(.headline)
                .foregroundStyle(SageActiveTheme.primaryText)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
    }
}

private struct SettingsReferenceRow: View {
    let icon: SageCarbonIcon
    let title: String
    var iconColor: Color = SageActiveTheme.primaryText
    var titleColor: Color = SageActiveTheme.primaryText

    var body: some View {
        HStack(spacing: 8) {
            SageCarbonIconView(icon, pointSize: 20, color: iconColor)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.headline)
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            SageCarbonIconView(
                .chevronRightThick,
                pointSize: 14,
                color: SageActiveTheme.primaryText
            )
            .frame(width: 16, height: 16)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 54)
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileAvatar: View {
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(SageActiveTheme.brand)

            Text(initials)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SageActiveTheme.onBrand)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
    }
}
