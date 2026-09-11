import SwiftUI

// MARK: - Global Search Panel
struct GlobalSearchPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var debounceTimer: Timer?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search Input
            HStack(spacing: 8) {
                if appState.isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }

                TextField("全文搜索最近使用的文档…", text: $appState.globalSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($searchFocused)
                    .onChange(of: appState.globalSearchQuery) { _, query in
                        scheduleSearch(query: query)
                    }

                if !appState.globalSearchQuery.isEmpty {
                    // Result count badge
                    if !appState.globalSearchResults.isEmpty {
                        Text(appState.preferences.language == .english
                             ? "\(appState.globalSearchResults.count) results"
                             : "\(appState.globalSearchResults.count) 条")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(NSColor.tertiaryLabelColor).opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Button {
                        appState.globalSearchQuery = ""
                        appState.globalSearchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))

            Divider()

            // Results List
            if appState.globalSearchResults.isEmpty && !appState.globalSearchQuery.isEmpty && !appState.isSearching {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text("未找到匹配内容")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Text("\"\(appState.globalSearchQuery)\"")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !appState.globalSearchResults.isEmpty {
                searchResultsList
            } else if appState.globalSearchQuery.isEmpty {
                searchPlaceholder
            }
        }
        .onAppear { searchFocused = true }
    }

    // MARK: Results List (grouped by file)
    var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let grouped = Dictionary(grouping: appState.globalSearchResults, by: \.fileURL)
                let sortedKeys = grouped.keys.sorted {
                    $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending
                }

                ForEach(sortedKeys, id: \.self) { fileURL in
                    let results = grouped[fileURL] ?? []
                    SearchFileSection(
                        fileURL: fileURL,
                        results: results,
                        query: appState.globalSearchQuery
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    var searchPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("搜索最近使用的文档内容")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Text("搜索最近使用与当前文档的标题、正文")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Debounced Search
    private func scheduleSearch(query: String) {
        debounceTimer?.invalidate()
        guard !query.isEmpty else {
            appState.globalSearchResults = []
            appState.isSearching = false
            return
        }
        appState.isSearching = true
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
            Task { @MainActor in
                appState.performGlobalSearch(query: query)
            }
        }
    }
}

// MARK: - Search File Section
struct SearchFileSection: View {
    let fileURL: URL
    let results: [GlobalSearchResult]
    let query: String
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File Header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text(fileURL.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("\(results.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            // Result Rows
            if isExpanded {
                ForEach(results) { result in
                    SearchResultRow(result: result, query: query)
                        .onTapGesture {
                            openResult(result)
                        }
                }
            }

            Divider().padding(.leading, 12)
        }
    }

    private func openResult(_ result: GlobalSearchResult) {
        guard appState.openFile(result.fileURL) else { return }
        // Jump to line via JS
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: .editorCommand,
                object: "gotoLine:\(result.lineNumber)"
            )
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: GlobalSearchResult
    let query: String
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Line number
            Text("\(result.lineNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .trailing)
                .padding(.top, 1)

            // Highlighted line text
            highlightedText
                .font(.system(size: 12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isHovered ? Color(NSColor.selectedControlColor).opacity(0.3) : Color.clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }

    var highlightedText: Text {
        let text = result.lineText
        guard let range = text.range(of: query, options: .caseInsensitive) else {
            return Text(text).foregroundStyle(Color.secondary)
        }

        let before = String(text[text.startIndex..<range.lowerBound])
        let match = String(text[range])
        let after = String(text[range.upperBound...])

        return Text(before).foregroundStyle(Color.secondary)
            + Text(match).foregroundStyle(Color.primary).fontWeight(.semibold)
                         .underline(color: Color.accentColor)
            + Text(after).foregroundStyle(Color.secondary)
    }
}
