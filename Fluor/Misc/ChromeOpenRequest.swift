import AppKit
import Darwin

/// Delivers Chrome's existing launch request directly to the already-running browser.
enum ChromeOpenRequest {
    /// Returns false only when no bytes were sent, so the caller can safely use the source address bar.
    static func send(_ argument: String, switches: [String], to chrome: NSRunningApplication,
                     before deadline: DispatchTime) -> Bool {
        let files = FileManager.default
        let directory = files.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome", isDirectory: true)
        let socketLink = directory.appendingPathComponent("SingletonSocket")
        guard let path = try? files.destinationOfSymbolicLink(atPath: socketLink.path),
              path.hasPrefix("/"), let executable = chrome.executableURL else { return false }

        let arguments = [executable.path, "--user-data-dir=" + directory.path] + switches + ["--", argument]
        return send(arguments, through: path, to: chrome.processIdentifier, before: deadline,
                    isActive: { chrome.isActive }, isTerminated: { chrome.isTerminated })
    }

    /// Uses Chromium's NUL-delimited START message and verifies the peer before sharing the selection.
    private static func send(_ arguments: [String], through path: String, to pid: pid_t,
                             before deadline: DispatchTime, isActive: () -> Bool,
                             isTerminated: () -> Bool) -> Bool {
        guard DispatchTime.now() < deadline, !arguments.contains(where: { $0.utf8.contains(0) }) else {
            return false
        }
        let message = Data((["START", "/"] + arguments).joined(separator: "\0").utf8)
        // The browser reads at most 32 KiB, including the command framing.
        guard message.count <= 32 * 1024 else { return false }

        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        defer { _ = close(socket) }

        var noSignal: Int32 = 1
        guard fcntl(socket, F_SETFD, FD_CLOEXEC) != -1,
              fcntl(socket, F_SETFL, O_NONBLOCK) != -1,
              setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size)) == 0,
              connect(socket, to: path), isPeer(socket, pid: pid) else { return false }

        var sendBuffer: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(socket, SOL_SOCKET, SO_SNDBUF, &sendBuffer, &size) == 0,
              message.count <= Int(sendBuffer), isActive(), DispatchTime.now() < deadline else { return false }

        // One write keeps the small request together for Chrome's socket reader.
        let sent = message.withUnsafeBytes { bytes in
            Darwin.send(socket, bytes.baseAddress, bytes.count, 0)
        }
        guard sent > 0 else { return false }

        _ = shutdown(socket, SHUT_WR)
        // Chrome sends a reply or closes the connection after handling the request.
        // Keep the F4 slot occupied while the browser can still act on the bytes it received.
        var receiver = pollfd(fd: socket, events: Int16(POLLIN), revents: 0)
        while !isTerminated() {
            let ready = poll(&receiver, 1, 250)
            if ready > 0 || (ready < 0 && errno != EINTR) { break }
        }
        return true
    }

    /// Connects only to a bounded Unix socket path. A busy or absent listener leaves the request unsent.
    private static func connect(_ socket: Int32, to path: String) -> Bool {
        var address = sockaddr_un()
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { return false }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes.map { UInt8(bitPattern: $0) })
        }
        address.sun_family = sa_family_t(AF_UNIX)
        let length = MemoryLayout<sockaddr_un>.offset(of: \.sun_path)! + bytes.count
        address.sun_len = UInt8(length)
        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socket, $0, socklen_t(length)) == 0
            }
        }
    }

    /// Pins the connection to the foreground Chrome PID using the kernel's peer identity.
    private static func isPeer(_ socket: Int32, pid: pid_t) -> Bool {
        var peerPID: pid_t = 0
        var size = socklen_t(MemoryLayout<pid_t>.size)
        return getsockopt(socket, SOL_LOCAL, LOCAL_PEERPID, &peerPID, &size) == 0 && peerPID == pid
    }
}
