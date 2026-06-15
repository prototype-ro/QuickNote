import Foundation

/// On-disk location for voice recordings: Documents/Recordings/.
public enum RecordingsDirectory {
    public static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    public static func url(for fileName: String) -> URL {
        folder.appendingPathComponent(fileName)
    }
    public static func remove(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
