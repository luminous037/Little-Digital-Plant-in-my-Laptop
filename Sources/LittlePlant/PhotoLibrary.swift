import AppKit
import Combine

struct PlantPhoto: Codable, Identifiable, Equatable {
    let id: UUID
    let capturedAt: Date
    let dateText: String
    let plantName: String
    var fileName: String { id.uuidString+".png" }
}
struct PhotoDraft: Identifiable {
    let record: PlantPhoto
    let png: Data
    var id: UUID { record.id }
    var scene: NSImage { NSImage(data:png)! }
}

@MainActor
final class RoomCamera: ObservableObject {
    var capture: () -> NSImage? = { nil }
    var albumPoint: () -> CGPoint? = { nil }
}

@MainActor
final class PhotoLibrary: ObservableObject {
    static let shared = PhotoLibrary()
    @Published private(set) var entries: [PlantPhoto] = []
    @Published private(set) var hasAlbum = true
    @Published var error: String?
    private let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("photos.json") }
    init(directory:URL? = nil) {
        if let directory { self.directory = directory }
        else if CommandLine.arguments.contains("--render-preview") {
            self.directory = FileManager.default.temporaryDirectory.appendingPathComponent("LittlePlantPreviewPhotos-"+UUID().uuidString)
        } else {
            self.directory = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("LittlePlant/PlantRecords",isDirectory:true)
        }
        if let data = try? Data(contentsOf:indexURL), let saved = try? JSONDecoder().decode([PlantPhoto].self,from:data) {
            entries = saved; hasAlbum = true
        }
    }
    static func draft(scene:NSImage,name:String,date:Date = Date()) throws -> PhotoDraft {
        guard let tiff = scene.tiffRepresentation, let bitmap = NSBitmapImageRep(data:tiff), let png = bitmap.representation(using:.png,properties:[:]) else { throw CocoaError(.fileWriteUnknown) }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier:"en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent; formatter.dateFormat = "yyyy/MM/dd"
        return PhotoDraft(record:PlantPhoto(id:UUID(),capturedAt:date,dateText:formatter.string(from:date),plantName:name),png:png)
    }
    func image(for entry:PlantPhoto) -> NSImage? { NSImage(contentsOf:directory.appendingPathComponent(entry.fileName)) }
    private func writeIndex(_ records:[PlantPhoto]) throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try JSONEncoder().encode(records).write(to:indexURL,options:.atomic)
    }
    @discardableResult func save(_ draft:PhotoDraft) -> Bool {
        guard !entries.contains(where:{$0.id == draft.id}) else { return true }
        let url = directory.appendingPathComponent(draft.record.fileName)
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            try draft.png.write(to:url,options:.atomic)
            do { try writeIndex(entries+[draft.record]) }
            catch { try? FileManager.default.removeItem(at:url); throw error }
            entries.append(draft.record); hasAlbum = true; error = nil
            return true
        } catch { self.error = "사진을 저장하지 못했습니다. / Could not save photo."; return false }
    }
    @discardableResult func delete(_ entry:PlantPhoto) -> Bool {
        guard entries.contains(where:{$0.id == entry.id}) else { return false }
        do {
            let remaining = entries.filter { $0.id != entry.id }
            try writeIndex(remaining)
            entries = remaining
            try? FileManager.default.removeItem(at:directory.appendingPathComponent(entry.fileName))
            return true
        } catch { self.error = "사진을 삭제하지 못했습니다. / Could not delete photo."; return false }
    }
    @discardableResult func copy(_ entry:PlantPhoto,to pasteboard:NSPasteboard? = nil) -> Bool {
        guard let scene = image(for:entry), let png = PolaroidGraphic.png(PolaroidGraphic.artwork(scene:scene,record:entry)) else { return false }
        let board = pasteboard ?? .general
        board.clearContents()
        let ok = board.setData(png,forType:.png)
        if let tiff = NSImage(data:png)?.tiffRepresentation { board.setData(tiff,forType:.tiff) }
        return ok
    }
    static func verify(scene:NSImage) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("LittlePlantPhotoChecks-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let library = PhotoLibrary(directory:dir)
        let draft = try Self.draft(scene:scene,name:"몬스테라 🌱",date:Date(timeIntervalSince1970:1_790_000_000))
        precondition(library.hasAlbum && library.entries.isEmpty,"The album must exist before the first photo")
        precondition(library.save(draft) && library.save(draft) && library.entries.count == 1,"A card must be saved exactly once")
        let restored = PhotoLibrary(directory:dir)
        precondition(restored.hasAlbum && restored.entries == [draft.record] && restored.image(for:draft.record) != nil,"Photo, name and capture date must survive relaunch")
        let board = NSPasteboard(name:NSPasteboard.Name("LittlePlantPhotoChecks-"+UUID().uuidString))
        precondition(restored.copy(draft.record,to:board) && board.data(forType:.png) != nil && board.data(forType:.tiff) != nil,"Share must copy a real image")
        precondition(restored.delete(draft.record) && !FileManager.default.fileExists(atPath:dir.appendingPathComponent(draft.record.fileName).path))
        let empty = PhotoLibrary(directory:dir)
        precondition(empty.hasAlbum && empty.entries.isEmpty,"An empty album must remain after deleting the last photo")
        fputs("PASS: photo PNG/date/name persistence, duplicate save guard, image clipboard formats, deletion and empty-album persistence\n",stderr)
    }
}
