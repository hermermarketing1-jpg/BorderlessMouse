import Foundation
import Network

/// Serwer TCP kanału sterowania. Obsługuje jedno aktywne połączenie
/// (nowe połączenie zastępuje poprzednie). Wszystkie callbacki są wołane
/// na `callbackQueue`.
final class ControlServer {
    struct PeerInfo: Equatable {
        let name: String
        let address: String
    }

    var onPeerConnected: ((PeerInfo) -> Void)?
    var onPeerDisconnected: (() -> Void)?
    var onMessage: ((MessageType, [UInt8]) -> Void)?
    var onListeningChanged: ((Bool, String?) -> Void)?

    private let queue = DispatchQueue(label: "blm.control", qos: .userInteractive)
    private let callbackQueue: DispatchQueue
    private var listener: NWListener?
    private var connection: NWConnection?
    private var inbox: [UInt8] = []
    private var peer: PeerInfo?
    private let localName: () -> String

    init(callbackQueue: DispatchQueue = .main, localName: @escaping () -> String) {
        self.callbackQueue = callbackQueue
        self.localName = localName
    }

    var isConnected: Bool { peer != nil }

    func start(port: UInt16) {
        stop()
        let params = NWParameters.tcp
        if let tcp = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 5
            tcp.keepaliveInterval = 2
            tcp.keepaliveCount = 3
        }
        params.allowLocalEndpointReuse = true
        do {
            let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener = l
            l.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.callbackQueue.async { self.onListeningChanged?(true, nil) }
                case .failed(let err):
                    self.callbackQueue.async { self.onListeningChanged?(false, err.localizedDescription) }
                case .cancelled:
                    self.callbackQueue.async { self.onListeningChanged?(false, nil) }
                default: break
                }
            }
            l.newConnectionHandler = { [weak self] conn in
                self?.accept(conn)
            }
            l.start(queue: queue)
        } catch {
            callbackQueue.async { self.onListeningChanged?(false, error.localizedDescription) }
        }
    }

    func stop() {
        queue.sync {
            self.closeConnection(notify: true)
            self.listener?.cancel()
            self.listener = nil
        }
    }

    func send(_ data: Data) {
        queue.async {
            guard let c = self.connection, self.peer != nil else { return }
            c.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    func disconnectPeer() {
        queue.async { self.closeConnection(notify: true) }
    }

    // MARK: - Private (na `queue`)

    private func accept(_ conn: NWConnection) {
        closeConnection(notify: true)
        connection = conn
        inbox.removeAll(keepingCapacity: true)
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn, conn === self.connection else { return }
            switch state {
            case .ready:
                self.receive(on: conn)
            case .failed, .cancelled:
                self.closeConnection(notify: true)
            default: break
            }
        }
        conn.start(queue: queue)
    }

    private func closeConnection(notify: Bool) {
        guard let c = connection else { return }
        connection = nil
        c.stateUpdateHandler = nil
        c.cancel()
        if peer != nil {
            peer = nil
            if notify { callbackQueue.async { self.onPeerDisconnected?() } }
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self, weak conn] data, _, isComplete, error in
            guard let self, let conn, conn === self.connection else { return }
            if let data, !data.isEmpty {
                self.inbox.append(contentsOf: data)
                self.drainInbox(conn)
            }
            if isComplete || error != nil {
                self.closeConnection(notify: true)
                return
            }
            self.receive(on: conn)
        }
    }

    private func drainInbox(_ conn: NWConnection) {
        var cursor = 0
        while inbox.count - cursor >= 2 {
            let typeByte = inbox[cursor]
            var len = Int(inbox[cursor + 1])
            var header = 2
            if len == 0xFF {
                // długa ramka: u32 length
                guard inbox.count - cursor >= 6 else { break }
                len = Int(inbox[cursor + 2]) | (Int(inbox[cursor + 3]) << 8)
                    | (Int(inbox[cursor + 4]) << 16) | (Int(inbox[cursor + 5]) << 24)
                header = 6
                guard len <= ProtocolConstants.maxLongFrame else {
                    closeConnection(notify: true)
                    return
                }
            }
            guard inbox.count - cursor >= header + len else { break }
            let payload = Array(inbox[(cursor + header)..<(cursor + header + len)])
            cursor += header + len
            handle(typeByte: typeByte, payload: payload, conn: conn)
        }
        if cursor > 0 { inbox.removeFirst(cursor) }
    }

    private func handle(typeByte: UInt8, payload: [UInt8], conn: NWConnection) {
        guard let type = MessageType(rawValue: typeByte) else { return }
        switch type {
        case .hello:
            var r = ByteReader(payload)
            let version = r.u8() ?? 0
            let name = r.restAsString()
            guard version == ProtocolConstants.version else {
                closeConnection(notify: false)
                return
            }
            let address: String
            if case let .hostPort(host, _) = conn.endpoint {
                address = "\(host)".components(separatedBy: "%").first ?? "\(host)"
            } else {
                address = "?"
            }
            let info = PeerInfo(name: name.isEmpty ? address : name, address: address)
            peer = info
            conn.send(content: Frame.welcome(name: localName()), completion: .contentProcessed { _ in })
            callbackQueue.async { self.onPeerConnected?(info) }
        case .ping:
            conn.send(content: Frame.pong(payload), completion: .contentProcessed { _ in })
        default:
            guard peer != nil else { return }
            let cb = onMessage
            callbackQueue.async { cb?(type, payload) }
        }
    }
}
