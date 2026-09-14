import SwiftUI

/// Shared Sage Active input behaviour, informed by Graphite while retaining Apple-native controls
/// and app-owned, continuous corner geometry.
struct SageActiveTextInput<Field: Hashable>: View {
    let label: String
    @Binding var text: String
    let field: Field
    let focus: FocusState<Field?>.Binding
    var required = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var submitLabel: SubmitLabel = .next
    var axis: Axis = .horizontal
    var suffix: String?
    var supportingText: String?
    var errorMessage: String?
    var characterLimit: Int?
    var onSubmit: () -> Void = { }

    private var isFocused: Bool { focus.wrappedValue == field }
    private var isCollapsed: Bool { isFocused || !text.isEmpty }

    var body: some View {
        SageActiveInputShell(
            label: label,
            required: required,
            isCollapsed: isCollapsed,
            isFocused: isFocused,
            errorMessage: errorMessage,
            supportingText: supportingText,
            counterText: counterText,
            focusAction: { focus.wrappedValue = field }
        ) {
            HStack(alignment: axis == .vertical ? .top : .center, spacing: 8) {
                TextField("", text: $text, axis: axis)
                    .focused(focus, equals: field)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
                    .lineLimit(axis == .vertical ? 3...6 : 1...1)
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityValue(text.isEmpty ? "Empty" : text + (suffix ?? ""))
                    .accessibilityHint(accessibilityHint)

                if let suffix, !text.isEmpty || isFocused {
                    Text(suffix)
                        .foregroundStyle(SageActiveTheme.supportingText)
                        .accessibilityHidden(true)
                }

                if !text.isEmpty && isFocused {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SageActiveTheme.supportingText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(label)")
                }
            }
        }
        .onChange(of: text) { _, newValue in
            guard let characterLimit, newValue.count > characterLimit else { return }
            text = String(newValue.prefix(characterLimit))
        }
    }

    private var counterText: String? {
        guard let characterLimit else { return nil }
        return "\(text.count)/\(characterLimit)"
    }

    private var accessibilityLabel: String {
        required ? "\(label), required" : label
    }

    private var accessibilityHint: String {
        if let errorMessage { return "Error: \(errorMessage)" }
        return supportingText ?? ""
    }
}

struct SageActiveSelectionField: View {
    enum ValueAlignment {
        case stacked
        case trailing
    }

    let label: String
    let value: String
    var required = false
    var isPlaceholder = false
    var valueAlignment: ValueAlignment = .stacked
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .trailing) {
                selectionContent
                    .padding(.trailing, 34)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPlaceholder ? SageActiveTheme.brand : SageActiveTheme.supportingText)
                    .frame(width: 24, height: 44)
                    .padding(.trailing, 10)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.horizontal, 14)
            .background(SageActiveTheme.cardBackground)
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(required ? "\(label), required" : label)
        .accessibilityValue(isPlaceholder ? "Not selected" : value)
        .accessibilityHint("Opens selection options")
    }

    @ViewBuilder
    private var selectionContent: some View {
        if isPlaceholder {
            SageActiveInputLabel(label: label, required: required)
                .font(.body)
                .foregroundStyle(SageActiveTheme.brand)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            switch valueAlignment {
            case .stacked:
                VStack(alignment: .leading, spacing: 4) {
                    SageActiveInputLabel(label: label, required: required)
                        .font(.footnote)
                        .foregroundStyle(SageActiveTheme.supportingText)
                    Text(value)
                        .font(.body)
                        .foregroundStyle(SageActiveTheme.primaryText)
                }

            case .trailing:
                HStack(alignment: .center, spacing: 12) {
                    SageActiveInputLabel(label: label, required: required)
                        .font(.footnote)
                        .foregroundStyle(SageActiveTheme.supportingText)
                    Spacer(minLength: 12)
                    Text(value)
                        .font(.body)
                        .foregroundStyle(SageActiveTheme.primaryText)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

struct SageActiveReadOnlyField: View {
    let label: String
    let value: String

    var body: some View {
        SageActiveInputShell(
            label: label,
            isCollapsed: true,
            isFocused: false
        ) {
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(SageActiveTheme.primaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

private struct SageActiveInputShell<Content: View>: View {
    let label: String
    var required = false
    let isCollapsed: Bool
    let isFocused: Bool
    var errorMessage: String?
    var supportingText: String?
    var counterText: String?
    var focusAction: () -> Void = { }
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: isCollapsed ? 4 : 0) {
                SageActiveInputLabel(label: label, required: required)
                    .font(isCollapsed ? .footnote : .body)
                    .foregroundStyle(labelColour)
                    .animation(.easeInOut(duration: 0.2), value: isCollapsed)

                if isCollapsed {
                    content
                        .font(.body)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, isCollapsed ? 9 : 0)
            .background(SageActiveTheme.cardBackground)
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
            .contentShape(.rect)
            .simultaneousGesture(TapGesture().onEnded(focusAction))

            if errorMessage != nil || supportingText != nil || counterText != nil {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(SageActiveTheme.negativeText)
                    } else if let supportingText {
                        Text(supportingText)
                            .foregroundStyle(SageActiveTheme.supportingText)
                    }

                    Spacer(minLength: 8)

                    if let counterText {
                        Text(counterText)
                            .foregroundStyle(SageActiveTheme.supportingText)
                            .accessibilityLabel("Character count \(counterText)")
                    }
                }
                .font(.footnote)
                .padding(.horizontal, 4)
            }
        }
    }

    private var labelColour: Color {
        if errorMessage != nil { return SageActiveTheme.negativeText }
        if isFocused { return SageActiveTheme.brand }
        if !isCollapsed { return SageActiveTheme.primaryText }
        return SageActiveTheme.supportingText
    }
}

struct SageActiveInputLabel: View {
    let label: String
    let required: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
            if required {
                Text("*")
                    .foregroundStyle(SageActiveTheme.negativeVisual)
            }
        }
        .accessibilityHidden(true)
    }
}
