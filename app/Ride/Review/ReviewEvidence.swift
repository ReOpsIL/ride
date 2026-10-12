import AppKit
import Foundation
import UniformTypeIdentifiers

extension ReviewModel {
    func keepShot(_ row: ReviewRow) {
        guard var shot = shots[row.reviewKey] else {
            return
        }
        shot.kept = true
        shots[row.reviewKey] = shot
    }

    func storeShot(_ row: ReviewRow, data: Data) {
        guard data.count <= ReviewImages.limit, let png = ReviewImages.png(data) else {
            error = data.count > ReviewImages.limit ? "Image is over 2 MB" : "That image could not be read"
            return
        }
        if png.count > ReviewImages.limit {
            error = "Image is over 2 MB"
            return
        }
        let dir = RideEngineClient.shared.indexDir
            .deletingLastPathComponent()
            .appendingPathComponent("trail/evidence", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("\(UUID().uuidString).png")
            try png.write(to: file)
            shots[row.reviewKey] = ReviewShot(local: file, shared: nil, kept: false)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func shareShot(_ row: ReviewRow, root: String?) {
        guard let root, !root.isEmpty, let shot = shots[row.reviewKey], shot.shared == nil else {
            return
        }
        let prefix = row.shape.isEmpty ? "item" : String(row.shape.prefix(8))
        let dir = URL(fileURLWithPath: root).appendingPathComponent(".ride/evidence", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let have = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            let n = have.filter { $0.lastPathComponent.hasPrefix(prefix) }.count + 1
            let name = "\(prefix)-\(n).png"
            try FileManager.default.copyItem(at: shot.local, to: dir.appendingPathComponent(name))
            let relative = ".ride/evidence/\(name)"
            var next = shot
            next.shared = relative
            shots[row.reviewKey] = next
            mark(row, root: root, kind: "suspect", note: relative)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeShot(_ row: ReviewRow, root: String?) {
        guard let shot = shots.removeValue(forKey: row.reviewKey) else {
            return
        }
        try? FileManager.default.removeItem(at: shot.local)
        guard let shared = shot.shared, let root, !root.isEmpty else {
            return
        }
        if let file = sharedFile(root: root, relative: shared) {
            try? FileManager.default.removeItem(at: file)
        }
        let cited = dossier?.marks.first { $0.own && $0.text.contains(shared) }?.id ?? ""
        let id = cited.isEmpty && row.markNote == shared ? row.markId : cited
        drop(id: id, root: root)
    }

    private func sharedFile(root: String, relative: String) -> URL? {
        guard relative.hasPrefix(".ride/evidence/"), !relative.contains("..") else {
            return nil
        }
        return URL(fileURLWithPath: root).appendingPathComponent(relative)
    }
}

enum ReviewImages {
    static let limit = 2 * 1024 * 1024

    static func png(_ data: Data) -> Data? {
        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }

    static func take(_ providers: [NSItemProvider], done: @escaping (Data?) -> Void) -> Bool {
        guard let provider = providers.first else {
            return false
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                DispatchQueue.main.async {
                    done(fileData(item))
                }
            }
            return true
        }
        let type = provider.hasItemConformingToTypeIdentifier(UTType.png.identifier)
            ? UTType.png.identifier
            : UTType.image.identifier
        guard provider.hasItemConformingToTypeIdentifier(type) else {
            return false
        }
        provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
            DispatchQueue.main.async { done(data) }
        }
        return true
    }

    private static func fileData(_ item: NSSecureCoding?) -> Data? {
        let url = item as? URL
        guard let url else {
            return item as? Data
        }
        return try? Data(contentsOf: url)
    }
}
