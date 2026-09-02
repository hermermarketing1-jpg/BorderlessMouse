import Foundation
import Darwin

/// Odpowiada na broadcasty discovery z Windowsa (UDP, gniazdo BSD –
/// żadnych zależności od Network.framework, działa też z broadcastem).
final class DiscoveryResponder {
    private var socketFD: Int32 = -1
    private var thread: Thread?
    private let nameProvider: () -> String
    private let portProvider: () -> UInt16

    init(name: @escaping () -> String, controlPort: @escaping () -> UInt16) {
        nameProvider = name
        portProvider = controlPort
    }

    var isRunning: Bool { socketFD >= 0 }

    func start() throws {
        guard socketFD < 0 else { return }
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &one, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &one, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = ProtocolConstants.discoveryPort.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bindResult == 0 else {
            let e = errno
            close(fd)
            throw POSIXError(.init(rawValue: e) ?? .EIO)
        }
        socketFD = fd
        let t = Thread { [weak self] in self?.loop(fd: fd) }
        t.name = "blm.discovery"
        t.qualityOfService = .utility
        thread = t
        t.start()
    }

    func stop() {
        guard socketFD >= 0 else { return }
        let fd = socketFD
        socketFD = -1
        shutdown(fd, SHUT_RDWR)
        close(fd)
    }

    private func loop(fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 512)
        let request = Array(ProtocolConstants.discoveryRequest.utf8)
        while socketFD == fd {
            var from = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &from) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(fd, &buffer, buffer.count, 0, $0, &fromLen)
                }
            }
            if n <= 0 {
                if socketFD != fd { break }
                if errno == EINTR { continue }
                break
            }
            guard n >= request.count, Array(buffer[0..<request.count]) == request else { continue }
            var w = ByteWriter()
            w.string(ProtocolConstants.discoveryReply)
            w.u16(portProvider())
            w.string(String(nameProvider().utf8.prefix(200))!)
            let reply = w.bytes
            _ = withUnsafePointer(to: &from) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, reply, reply.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}
