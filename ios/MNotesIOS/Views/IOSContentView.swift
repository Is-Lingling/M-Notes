import SwiftUI

struct IOSContentView: View {
    @EnvironmentObject var appState: IOSAppState
    @State private var showingExportSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main Editor Container
                IOSEditorWebView()
                    .edgesIgnoringSafeArea(.bottom)

                // Mobile Quick Accessory Toolbar
                IOSAccessoryBar()
            }
            .navigationTitle(appState.currentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.isShowingDocumentPicker = true
                    } label: {
                        Image(systemName: "folder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            appState.saveDocument()
                        } label: {
                            Label("保存", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("分享 / 导出", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $appState.isShowingDocumentPicker) {
                IOSDocumentPicker(onPick: { url in
                    appState.openDocument(at: url)
                })
            }
        }
    }
}

// MARK: - Mobile Accessory Toolbar (Quick formatting for touch keyboard)
struct IOSAccessoryBar: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                formatButton("#", command: "heading")
                formatButton("B", command: "bold", isBold: true)
                formatButton("I", command: "italic", isItalic: true)
                formatButton("S", command: "strikethrough")
                formatButton("`", command: "inlineCode")
                formatButton("—", command: "hr")
                formatButton("☑️", command: "task")
                formatButton("∑", command: "math")
                formatButton("📊", command: "mermaid")
                formatButton("⊞", command: "table")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
        .overlay(Divider(), alignment: .top)
    }

    private func formatButton(_ label: String, command: String, isBold: Bool = false, isItalic: Bool = false) -> some View {
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("IOSEditorCommand"), object: command)
        } label: {
            Text(label)
                .font(.system(size: 15, weight: isBold ? .bold : .regular))
                .italic(isItalic)
                .frame(minWidth: 32, minHeight: 32)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - iOS Document Picker
struct IOSDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.text, .plainText], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: IOSDocumentPicker

        init(_ parent: IOSDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onPick(url)
            }
        }
    }
}
