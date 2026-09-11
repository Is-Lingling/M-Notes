import Foundation
import CoreServices

// MARK: - FSEvent Watcher
/// Wraps FSEventStream to watch a directory for file system changes
final class FSEventWatcher {
    private let url: URL
    private let callback: (URL) -> Void
    private var streamRef: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.markdownnotes.fswatcher", qos: .utility)

    init(url: URL, callback: @escaping (URL) -> Void) {
        self.url = url
        self.callback = callback
    }

    func start() {
        let pathsToWatch = [url.path] as CFArray
        let latency: CFTimeInterval = 0.8  // seconds before events coalesce

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: { pointer in
                guard let pointer else { return nil }
                _ = Unmanaged<FSEventWatcher>.fromOpaque(pointer).retain()
                return UnsafeRawPointer(pointer)
            },
            release: { ptr in
                guard let ptr else { return }
                Unmanaged<FSEventWatcher>.fromOpaque(ptr).release()
            },
            copyDescription: nil
        )

        let flags: FSEventStreamCreateFlags =
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes) |
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents) |
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)

        let stream = FSEventStreamCreate(
            nil,
            { (_, info, numEvents, eventPaths, _, _) in
                guard let info else { return }
                let pathArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
                guard let paths = pathArray as? [String] else { return }
                let watcher = Unmanaged<FSEventWatcher>
                    .fromOpaque(info)
                    .takeUnretainedValue()
                for path in paths.prefix(numEvents) {
                    let changedURL = URL(fileURLWithPath: path)
                    watcher.callback(changedURL)
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        )

        guard let stream else { return }
        streamRef = stream

        // Use a dedicated dispatch queue
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil
    }

    deinit {
        stop()
    }
}
