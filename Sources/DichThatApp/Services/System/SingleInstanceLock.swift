import Darwin
import Foundation

final class SingleInstanceLock {
    private let fileDescriptor: Int32

    init?(identifier: String) {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(identifier).lock", isDirectory: false)
        let descriptor = lockURL.path.withCString {
            open($0, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
        fileDescriptor = descriptor
    }

    deinit {
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }
}
