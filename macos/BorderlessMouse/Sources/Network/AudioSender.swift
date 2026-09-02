import Foundation
import Darwin

/// Wysyła pakiety audio UDP do Windowsa. Bezpieczne do wołania z wątku
/// audio (sendto na nieblokującym gnieździe, bez alokacji poza buforem
/// przygotowanym w init).
final class AudioSender {
    private var fd: Int32 = -1
    private var dest = sockaddr_in()
    private var seq: UInt16 = 0
    private var frameIndex: UInt32 = 0
    private var packet: [UInt8]
    let channels: Int
    let format: AudioSampleFormat
    /// Maks. liczba ramek w jednym pakiecie (żeby zmieścić się w MTU).
    let maxFramesPerPacket: Int

    private(set) var packetsSent: UInt64 = 0
    private(set) var sendErrors: UInt64 = 0

    init(host: String, port: UInt16, channels: Int, format: AudioSampleFormat) throws {
        self.channels = channels
        self.format = format
        let bytesPerFrame = channels * (format == .int16 ? 2 : 4)
        maxFramesPerPacket = max(1, 1400 / bytesPerFrame)
        packet = [UInt8](repeating: 0, count: 12 + maxFramesPerPacket * bytesPerFrame)

        let s = socket(AF_INET, SOCK_DGRAM, 0)
        guard s >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        // nieblokujące + większy bufor wysyłkowy
        let flags = fcntl(s, F_GETFL, 0)
        _ = fcntl(s, F_SETFL, flags | O_NONBLOCK)
        var sndbuf: Int32 = 1 << 20
        setsockopt(s, SOL_SOCKET, SO_SNDBUF, &sndbuf, socklen_t(MemoryLayout<Int32>.size))
        // DSCP EF (46) – priorytet dla ruchu audio, jeśli sieć to respektuje
        var tos: Int32 = 46 << 2
        setsockopt(s, IPPROTO_IP, IP_TOS, &tos, socklen_t(MemoryLayout<Int32>.size))

        dest.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &dest.sin_addr) == 1 else {
            Darwin.close(s)
            throw POSIXError(.EINVAL)
        }
        fd = s
    }

    deinit { close() }

    func close() {
        if fd >= 0 { Darwin.close(fd); fd = -1 }
    }

    /// `samples` – interleaved Int16, `frames` ramek. Dzieli na pakiety.
    func send(int16Samples samples: UnsafePointer<Int16>, frames: Int) {
        guard fd >= 0, format == .int16 else { return }
        var offset = 0
        while offset < frames {
            let n = min(maxFramesPerPacket, frames - offset)
            writeHeader(frames: n)
            let byteCount = n * channels * 2
            packet.withUnsafeMutableBytes { raw in
                let dst = raw.baseAddress!.advanced(by: 12)
                memcpy(dst, samples.advanced(by: offset * channels), byteCount)
            }
            transmit(length: 12 + byteCount)
            frameIndex &+= UInt32(n)
            offset += n
        }
    }

    private func writeHeader(frames: Int) {
        let magic = ProtocolConstants.audioMagic
        packet[0] = UInt8(magic & 0xFF); packet[1] = UInt8(magic >> 8)
        packet[2] = UInt8(seq & 0xFF); packet[3] = UInt8(seq >> 8)
        packet[4] = UInt8(frames & 0xFF); packet[5] = UInt8(frames >> 8)
        packet[6] = UInt8(channels)
        packet[7] = format.rawValue
        packet[8] = UInt8(frameIndex & 0xFF)
        packet[9] = UInt8((frameIndex >> 8) & 0xFF)
        packet[10] = UInt8((frameIndex >> 16) & 0xFF)
        packet[11] = UInt8((frameIndex >> 24) & 0xFF)
        seq &+= 1
    }

    private func transmit(length: Int) {
        let sent = packet.withUnsafeBytes { raw -> Int in
            withUnsafePointer(to: &dest) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, raw.baseAddress, length, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        if sent == length { packetsSent &+= 1 } else { sendErrors &+= 1 }
    }
}
