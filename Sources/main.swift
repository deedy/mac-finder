import SwiftUI
import AppKit
import PDFKit

@main
struct ExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}

struct ContentView: View {
    @State private var path = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var items: [FileItem] = []
    @State private var selection: Set<FileItem.ID> = []
    @State private var sortOrder: SortOrder = .nameAscending
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showHiddenFiles = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(path: $path)
        } content: {
            VStack(spacing: 0) {
                HStack {
                    Button(action: navigateUp) {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                    
                    TextField("Path", text: $path)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(loadItems)
                    
                    Button(action: loadItems) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    FileListView(
                        items: filteredItems,
                        selection: $selection,
                        sortOrder: $sortOrder,
                        onItemOpen: openItem
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Search files")
            .navigationTitle("Explorer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Folder") {
                            createNewFolder()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showHiddenFiles.toggle()
                        loadItems()
                    }) {
                        Image(systemName: showHiddenFiles ? "eye.fill" : "eye")
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(SortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        } detail: {
            FilePreviewView(selection: selection, items: items)
        }
        .onAppear(perform: loadItems)
    }
    
    private var filteredItems: [FileItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func loadItems() {
        guard !isLoading else { return }
        
        isLoading = true
        selection.removeAll()
        
        // Capture values before going into background task
        let currentPath = path 
        let shouldShowHiddenFiles = showHiddenFiles
        let currentSortOrder = sortOrder
        
        Task {
            // Run file operations in a background task
            var loadedItems: [FileItem] = []
            
            let url = URL(fileURLWithPath: currentPath)
            var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants, .skipsSubdirectoryDescendants]
            
            if !shouldShowHiddenFiles {
                options.insert(.skipsHiddenFiles)
            }
            
            if let fileEnumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [
                    .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
                ],
                options: options
            ) {
                for case let fileURL as URL in fileEnumerator {
                    do {
                        let resourceValues = try fileURL.resourceValues(forKeys: [
                            .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
                        ])
                        
                        let isDirectory = resourceValues.isDirectory ?? false
                        let modDate = resourceValues.contentModificationDate ?? Date.distantPast
                        let size = Int64(resourceValues.fileSize ?? 0)
                        let isHidden = resourceValues.isHidden ?? false
                        
                        // Add the item if it's not hidden or if we're showing hidden files
                        if !isHidden || shouldShowHiddenFiles {
                            let item = FileItem(
                                id: fileURL.path,
                                url: fileURL,
                                name: fileURL.lastPathComponent,
                                isDirectory: isDirectory,
                                modificationDate: modDate,
                                size: size,
                                isHidden: isHidden
                            )
                            loadedItems.append(item)
                        }
                    } catch {
                        print("Error getting resource values: \(error)")
                    }
                }
            }
            
            // Update UI on the main thread
            await MainActor.run {
                items = loadedItems.sorted(by: currentSortOrder.comparator)
                isLoading = false
            }
        }
    }
    
    private func navigateUp() {
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().path
        if parent != path {
            path = parent
            loadItems()
        }
    }
    
    private func openItem(_ item: FileItem) {
        if item.isDirectory {
            path = item.url.path
            loadItems()
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }
    
    private func createNewFolder() {
        let alert = NSAlert()
        alert.messageText = "Create New Folder"
        alert.informativeText = "Enter a name for the new folder:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "Folder Name"
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        alert.window.initialFirstResponder = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let folderName = textField.stringValue
            
            if !folderName.isEmpty {
                let folderURL = URL(fileURLWithPath: path).appendingPathComponent(folderName)
                
                do {
                    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
                    loadItems()
                } catch {
                    let errorAlert = NSAlert(error: error)
                    errorAlert.runModal()
                }
            }
        }
    }
}

struct SidebarView: View {
    @Binding var path: String
    
    private let favoriteLocations = [
        SidebarItem(name: "Home", path: FileManager.default.homeDirectoryForCurrentUser.path, icon: "house"),
        SidebarItem(name: "Desktop", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path, icon: "desktopcomputer"),
        SidebarItem(name: "Documents", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path, icon: "doc"),
        SidebarItem(name: "Downloads", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path, icon: "arrow.down.circle")
    ]
    
    var body: some View {
        List {
            Section("Favorites") {
                ForEach(favoriteLocations) { location in
                    Button(action: {
                        path = location.path
                    }) {
                        Label(location.name, systemImage: location.icon)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section("Devices") {
                Label("Macintosh HD", systemImage: "externaldrive")
            }
        }
        .listStyle(.sidebar)
    }
}

struct FileListView: View {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>
    @Binding var sortOrder: SortOrder
    let onItemOpen: (FileItem) -> Void
    
    @State private var sortingKeyPath: [KeyPathComparator<FileItem>] = []
    
    var body: some View {
        Table(selection: $selection, sortOrder: $sortingKeyPath) {
            TableColumn("Name") { item in
                HStack {
                    Image(systemName: item.isDirectory ? "folder" : "doc")
                        .foregroundColor(item.isDirectory ? .blue : .gray)
                        .opacity(item.isHidden ? 0.6 : 1.0)
                    Text(item.name)
                        .fontWeight(item.isDirectory ? .medium : .regular)
                        .opacity(item.isHidden ? 0.6 : 1.0)
                }
                .onTapGesture(count: 2) {
                    onItemOpen(item)
                }
            }
            .width(min: 220, ideal: 300)
            
            TableColumn("Size") { item in
                Text(item.isDirectory ? "--" : item.sizeString)
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Date Modified") { item in
                Text(item.modificationDateString)
            }
            .width(min: 150, ideal: 180)
        } rows: {
            ForEach(items) { item in
                TableRow(item)
            }
        }
        .onChange(of: sortOrder) { _ in
            selection.removeAll()
        }
        .tableStyle(.inset)
    }
}

struct FilePreviewView: View {
    let selection: Set<FileItem.ID>
    let items: [FileItem]
    
    var body: some View {
        if let selectedID = selection.first, let selectedItem = items.first(where: { $0.id == selectedID }) {
            VStack(spacing: 0) {
                // File header
                HStack {
                    Image(systemName: getSystemImageName(for: selectedItem))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(selectedItem.isDirectory ? .blue : .gray)
                    
                    VStack(alignment: .leading) {
                        Text(selectedItem.name)
                            .font(.headline)
                        Text(getFileType(for: selectedItem))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Open") {
                        NSWorkspace.shared.open(selectedItem.url)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                
                Divider()
                
                // File metadata
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Size:")
                            Text("Modified:")
                            Text("Location:")
                        }
                        .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedItem.sizeString)
                            Text(selectedItem.modificationDateString)
                            Text(selectedItem.url.deletingLastPathComponent().path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding()
                
                Divider()
                
                // File preview
                if !selectedItem.isDirectory {
                    FileContentView(item: selectedItem)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("Select a file to preview")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func getSystemImageName(for item: FileItem) -> String {
        if item.isDirectory {
            return "folder"
        }
        
        let ext = item.url.pathExtension.lowercased()
        
        if ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "webp"].contains(ext) {
            return "photo"
        } else if ext == "pdf" {
            return "doc.text"
        } else if ["txt", "md", "swift", "java", "py", "js", "html", "css"].contains(ext) {
            return "doc.text.fill"
        } else if ["mp4", "mov", "avi"].contains(ext) {
            return "film"
        } else if ["mp3", "wav", "aac"].contains(ext) {
            return "music.note"
        } else {
            return "doc"
        }
    }
    
    private func getFileType(for item: FileItem) -> String {
        if item.isDirectory {
            return "Folder"
        }
        
        let ext = item.url.pathExtension.lowercased()
        
        if ["jpg", "jpeg"].contains(ext) {
            return "JPEG Image"
        } else if ext == "png" {
            return "PNG Image"
        } else if ext == "pdf" {
            return "PDF Document"
        } else if ext == "txt" {
            return "Text File"
        } else if ext == "" {
            return "File"
        } else {
            return "\(ext.uppercased()) File"
        }
    }
}

struct FileContentView: View {
    let item: FileItem
    @State private var textContent: String = ""
    @State private var image: NSImage? = nil
    @State private var pdfDocument: PDFDocument? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading preview...")
            } else if let errorMsg = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text("Error loading preview")
                        .font(.headline)
                    
                    Text(errorMsg)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let image = image {
                // Image preview
                VStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 400)
                    
                    Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else if let pdfDoc = pdfDocument {
                // PDF preview
                PDFPreview(document: pdfDoc)
                    .frame(maxWidth: .infinity, maxHeight: 400)
            } else if !textContent.isEmpty {
                // Text preview
                ScrollView {
                    Text(textContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
            } else {
                Text("Preview not available for this file type")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear(perform: loadContent)
    }
    
    private func loadContent() {
        isLoading = true
        errorMessage = nil
        
        let ext = item.url.pathExtension.lowercased()
        
        // Run on a background thread to avoid UI freezes
        Task {
            // Load image files
            if ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic"].contains(ext) {
                let nsImage = NSImage(contentsOf: item.url)
                
                await MainActor.run {
                    if let loadedImage = nsImage {
                        self.image = loadedImage
                    } else {
                        self.errorMessage = "Unable to decode image format"
                    }
                    self.isLoading = false
                }
                return
            }
            
            // Load PDF files
            if ext == "pdf" {
                let pdfDoc = PDFDocument(url: item.url)
                
                await MainActor.run {
                    if let loadedPDF = pdfDoc {
                        self.pdfDocument = loadedPDF
                    } else {
                        self.errorMessage = "Unable to load PDF document"
                    }
                    self.isLoading = false
                }
                return
            }
            
            // Load text files
            let textExtensions = ["txt", "md", "swift", "java", "py", "js", "html", "css", 
                                 "json", "xml", "c", "cpp", "h", "sh", "yaml", "yml", 
                                 "config", "ini", "gitignore", "properties", "log"]
            
            if textExtensions.contains(ext) {
                do {
                    let data = try Data(contentsOf: item.url)
                    if let content = String(data: data, encoding: .utf8) {
                        // Limit text preview to avoid performance issues
                        let limitedContent = content.count > 20000 
                            ? String(content.prefix(20000)) + "\n\n[Content truncated...]" 
                            : content
                        
                        await MainActor.run {
                            self.textContent = limitedContent
                            self.isLoading = false
                        }
                    } else {
                        await MainActor.run {
                            self.errorMessage = "Unable to decode text with UTF-8 encoding"
                            self.isLoading = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }
                return
            }
            
            // No preview available for other file types
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case nameAscending = "Name (A to Z)"
    case nameDescending = "Name (Z to A)"
    case dateNewest = "Date (Newest First)"
    case dateOldest = "Date (Oldest First)"
    case sizeSmallest = "Size (Smallest First)"
    case sizeLargest = "Size (Largest First)"
    
    var id: String { rawValue }
    
    var comparator: (FileItem, FileItem) -> Bool {
        switch self {
        case .nameAscending:
            return { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        case .dateNewest:
            return { $0.modificationDate > $1.modificationDate }
        case .dateOldest:
            return { $0.modificationDate < $1.modificationDate }
        case .sizeSmallest:
            return { $0.size < $1.size }
        case .sizeLargest:
            return { $0.size > $1.size }
        }
    }
}

struct FileItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let modificationDate: Date
    let size: Int64
    let isHidden: Bool
    
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var modificationDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct SidebarItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String
}