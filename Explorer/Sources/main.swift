import SwiftUI
import AppKit
import UniformTypeIdentifiers
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
            
            do {
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
            } catch {
                await MainActor.run {
                    isLoading = false
                }
                print("Error loading items: \(error)")
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
                HStack {
                    // File icon
                    if selectedItem.isDirectory {
                        Image(systemName: "folder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: getSystemImageName(for: selectedItem))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                    }
                    
                    // File name and type
                    VStack(alignment: .leading) {
                        Text(selectedItem.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(getFileType(for: selectedItem))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !selectedItem.isDirectory {
                        Button("Open") {
                            NSWorkspace.shared.open(selectedItem.url)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // File metadata
                        MetadataView(item: selectedItem)
                            .padding()
                        
                        Divider()
                        
                        // File preview
                        if !selectedItem.isDirectory {
                            FileContentPreview(url: selectedItem.url)
                                .padding()
                        }
                    }
                }
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
        
        switch ext {
        case "pdf":
            return "doc.text"
        case "jpg", "jpeg", "png", "gif":
            return "photo"
        case "mov", "mp4", "avi":
            return "film"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "zip", "gz", "tar":
            return "archivebox"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "chart.bar.doc.horizontal"
        case "ppt", "pptx":
            return "chart.bar.doc.horizontal"
        case "app":
            return "app.square"
        case "txt", "md", "swift", "java", "py", "js", "html", "css":
            return "doc.text.fill"
        default:
            return "doc"
        }
    }
    
    private func getFileType(for item: FileItem) -> String {
        if item.isDirectory {
            return "Folder"
        }
        
        let ext = item.url.pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            return "PDF Document"
        case "jpg", "jpeg":
            return "JPEG Image"
        case "png":
            return "PNG Image"
        case "gif":
            return "GIF Image"
        case "mov":
            return "QuickTime Movie"
        case "mp4":
            return "MP4 Video"
        case "mp3":
            return "MP3 Audio"
        case "doc", "docx":
            return "Word Document"
        case "xls", "xlsx":
            return "Excel Spreadsheet"
        case "ppt", "pptx":
            return "PowerPoint Presentation"
        case "txt":
            return "Text File"
        case "md":
            return "Markdown File"
        case "swift":
            return "Swift Source File"
        case "java":
            return "Java Source File"
        case "py":
            return "Python Source File"
        case "js":
            return "JavaScript File"
        case "html":
            return "HTML File"
        case "css":
            return "CSS File"
        case "app":
            return "Application"
        case "":
            return "File"
        default:
            return "\(ext.uppercased()) File"
        }
    }
}

struct MetadataView: View {
    let item: FileItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("File Information")
                .font(.headline)
                .padding(.bottom, 4)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Size:").foregroundColor(.secondary)
                    Text(item.sizeString)
                }
                GridRow {
                    Text("Created:").foregroundColor(.secondary)
                    Text(item.modificationDateString)
                }
                GridRow {
                    Text("Location:").foregroundColor(.secondary)
                    Text(item.url.deletingLastPathComponent().path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                if item.isHidden {
                    GridRow {
                        Text("Hidden:").foregroundColor(.secondary)
                        Text("Yes")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FileContentPreview: View {
    let url: URL
    @State private var textContent: String = ""
    @State private var image: NSImage? = nil
    @State private var isLoading = true
    @State private var error: Error? = nil
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                Text("Error loading preview: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                previewContent
            }
        }
        .onAppear(perform: loadPreview)
    }
    
    @ViewBuilder
    private var previewContent: some View {
        let fileExtension = url.pathExtension.lowercased()
        
        // Image preview
        if isImageFile(fileExtension) {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 300)
            } else {
                Text("Unable to load image")
                    .foregroundColor(.red)
            }
        }
        // PDF preview
        else if fileExtension == "pdf" {
            PDFPreviewView(url: url)
                .frame(maxWidth: .infinity, maxHeight: 400)
        }
        // Text preview
        else if isTextFile(fileExtension) {
            ScrollView {
                Text(textContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: 400)
        }
        // Unsupported file type
        else {
            Text("Preview not available for this file type")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func loadPreview() {
        isLoading = true
        error = nil
        
        let fileExtension = url.pathExtension.lowercased()
        
        // Load content based on file type
        Task {
            do {
                if isImageFile(fileExtension) {
                    if let image = NSImage(contentsOf: url) {
                        await MainActor.run {
                            self.image = image
                            isLoading = false
                        }
                    } else {
                        throw NSError(domain: "com.explorer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
                    }
                } else if isTextFile(fileExtension) {
                    let data = try Data(contentsOf: url)
                    let encoding: String.Encoding = .utf8
                    
                    if let content = String(data: data, encoding: encoding) {
                        // Limit preview to first 50,000 characters for performance
                        let limitedContent = String(content.prefix(50000))
                        await MainActor.run {
                            textContent = limitedContent
                            if content.count > 50000 {
                                textContent += "\n\n[File truncated, too large to display completely]"
                            }
                            isLoading = false
                        }
                    } else {
                        throw NSError(domain: "com.explorer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode text"])
                    }
                } else if fileExtension == "pdf" {
                    // PDF preview is handled by PDFView
                    await MainActor.run {
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        isLoading = false
                    }
                }
            } catch let loadError {
                await MainActor.run {
                    error = loadError
                    isLoading = false
                }
            }
        }
    }
    
    private func isImageFile(_ extension: String) -> Bool {
        return ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "webp"].contains(`extension`)
    }
    
    private func isTextFile(_ extension: String) -> Bool {
        return ["txt", "md", "swift", "java", "py", "js", "html", "css", "json", "xml", "c", "cpp", "h", "sh", "yaml", "yml", "toml"].contains(`extension`)
    }
}

struct PDFPreviewView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        if let pdfDocument = PDFDocument(url: url) {
            nsView.document = pdfDocument
        }
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