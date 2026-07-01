import SwiftUI

/// The main SwiftUI view for the clipboard history picker.
/// Displays a search field and scrollable list of clipboard entries
/// with keyboard navigation support.
@MainActor
struct PickerView: View {

    // MARK: - State

    @ObservedObject var viewModel: PickerViewModel
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    // MARK: - Constants

    private static let maxPreviewLength = 80
    private static let maskString = "••••••••"

    // MARK: - Body

    var body: some View {
        VStack(spacing: 4) {
            searchField
            entryList
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.upArrow) {
            viewModel.moveSelection(direction: .up)
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.moveSelection(direction: .down)
            return .handled
        }
        .onKeyPress(.return) {
            viewModel.confirmSelection()
            return .handled
        }
        .onKeyPress(.escape) {
            viewModel.dismiss()
            return .handled
        }
        .onKeyPress(characters: .decimalDigits) { press in
            guard let digit = Int(press.characters), digit >= 1, digit <= 9 else {
                return .ignored
            }
            viewModel.selectEntry(at: digit - 1)
            return .handled
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        TextField("Search...", text: $searchText)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
            )
            .focused($isSearchFocused)
            .onChange(of: searchText) { _, newValue in
                viewModel.filter(query: newValue)
            }
    }

    // MARK: - Entry List

    private var entryList: some View {
        Group {
            if viewModel.displayedEntries.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 2) {
                            ForEach(
                                Array(viewModel.displayedEntries.enumerated()),
                                id: \.element.id
                            ) { index, entry in
                                entryRow(entry: entry, index: index)
                                    .id(entry.id)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onChange(of: viewModel.selectedIndex) { _, newIndex in
                        guard newIndex < viewModel.displayedEntries.count else { return }
                        let entry = viewModel.displayedEntries[newIndex]
                        proxy.scrollTo(entry.id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Entry Row

    private func entryRow(entry: ClipboardEntry, index: Int) -> some View {
        HStack(spacing: 6) {
            // Number label (1-9 for first nine entries)
            numberLabel(for: index)

            // Preview text or mask
            previewText(for: entry)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Type indicator for image/file entries
            typeIndicator(for: entry)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(index == viewModel.selectedIndex
                      ? Color.accentColor.opacity(0.2)
                      : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectEntry(at: index)
        }
    }

    // MARK: - Number Label

    private func numberLabel(for index: Int) -> some View {
        Group {
            if index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, alignment: .center)
            } else {
                Spacer()
                    .frame(width: 14)
            }
        }
    }

    // MARK: - Preview Text

    private func previewText(for entry: ClipboardEntry) -> some View {
        Group {
            if entry.isSensitive {
                Text(Self.maskString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
            } else {
                Text(truncatedPreview(for: entry))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Type Indicator

    @ViewBuilder
    private func typeIndicator(for entry: ClipboardEntry) -> some View {
        switch entry.content {
        case .image:
            Text("IMG")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                )
        case .file:
            Text("FILE")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.1))
                )
        default:
            EmptyView()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No clipboard history available")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    /// Truncates the plain text preview to 80 characters, appending "..." if longer.
    private func truncatedPreview(for entry: ClipboardEntry) -> String {
        let preview = entry.content.plainTextPreview
        if preview.count > Self.maxPreviewLength {
            return String(preview.prefix(Self.maxPreviewLength)) + "..."
        }
        return preview
    }
}
