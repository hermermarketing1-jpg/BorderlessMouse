using System.Buffers.Binary;
using System.Net;
using System.Net.Sockets;
using BorderlessMouse.Audio;
using BorderlessMouse.Protocol;

namespace BorderlessMouse.Net;

/// <summary>Odbiera pakiety audio UDP z Maca i wpycha je do bufora jitter.</summary>
public sealed class AudioReceiver : IDisposable
{
    private UdpClient? _udp;
    private Thread? _thread;
    private volatile bool _running;
    private ushort _lastSeq;
    private bool _haveSeq;
    private float _level;

    public JitterBufferProvider? Provider { get; set; }
    public int Port { get; private set; }
    public long PacketsReceived;
    public long PacketsLost;
    public long BytesReceived;
    public float Level => _level;

    /// <summary>Otwiera port UDP (0 = dowolny wolny) i zwraca wybrany port.</summary>
    public int Start(int port)
    {
        Stop();
        var udp = new UdpClient(AddressFamily.InterNetwork);
        udp.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
        udp.Client.ReceiveBufferSize = 1 << 20;
        udp.Client.Bind(new IPEndPoint(IPAddress.Any, port));
        SocketHelpers.DisableUdpConnReset(udp.Client);
        Port = ((IPEndPoint)udp.Client.LocalEndPoint!).Port;
        _udp = udp;
        _running = true;
        _haveSeq = false;
        PacketsReceived = PacketsLost = BytesReceived = 0;
        _thread = new Thread(() => Loop(udp)) { IsBackground = true, Name = "blm-audio-rx", Priority = ThreadPriority.Highest };
        _thread.Start();
        return Port;
    }

    public void Stop()
    {
        _running = false;
        try { _udp?.Close(); } catch { /* ignore */ }
        _udp = null;
        _thread = null;
        _level = 0;
    }

    private void Loop(UdpClient udp)
    {
        var remote = new IPEndPoint(IPAddress.Any, 0);
        while (_running)
        {
            byte[] data;
            try { data = udp.Receive(ref remote); }
            catch (SocketException) { if (!_running) break; continue; }
            catch (ObjectDisposedException) { break; }

            if (data.Length < 12) continue;
            var span = data.AsSpan();
            if (BinaryPrimitives.ReadUInt16LittleEndian(span) != ProtocolConstants.AudioMagic) continue;
            var seq = BinaryPrimitives.ReadUInt16LittleEndian(span[2..]);
            var frames = BinaryPrimitives.ReadUInt16LittleEndian(span[4..]);
            var channels = span[6];
            var format = span[7];
            var provider = Provider;
            if (provider is null) continue;

            if (_haveSeq)
            {
                var expected = (ushort)(_lastSeq + 1);
                if (seq != expected)
                {
                    var gap = (ushort)(seq - expected);
                    if (gap < 100)
                    {
                        Interlocked.Add(ref PacketsLost, gap);
                        // wypełnij lukę ciszą, żeby nie skracać bufora
                        provider.WriteSilence(gap * frames * channels * (format == 0 ? 2 : 4));
                    }
                }
            }
            _lastSeq = seq;
            _haveSeq = true;

            var payload = span[12..];
            Interlocked.Increment(ref PacketsReceived);
            Interlocked.Add(ref BytesReceived, payload.Length);

            if (format == 0)
            {
                // s16le – szybki podgląd poziomu
                var peak = 0;
                for (var i = 0; i + 1 < payload.Length; i += 2)
                {
                    var v = Math.Abs((int)BinaryPrimitives.ReadInt16LittleEndian(payload[i..]));
                    if (v > peak) peak = v;
                }
                var lvl = peak / 32768f;
                _level = lvl > _level ? lvl : _level * 0.85f;
                provider.Write(payload);
            }
            else
            {
                // f32le → s16le
                var count = payload.Length / 4;
                var tmp = new byte[count * 2];
                var peak = 0f;
                for (var i = 0; i < count; i++)
                {
                    var f = Math.Clamp(BinaryPrimitives.ReadSingleLittleEndian(payload[(i * 4)..]), -1f, 1f);
                    if (Math.Abs(f) > peak) peak = Math.Abs(f);
                    BinaryPrimitives.WriteInt16LittleEndian(tmp.AsSpan(i * 2), (short)(f * 32767));
                }
                _level = peak > _level ? peak : _level * 0.85f;
                provider.Write(tmp);
            }
        }
    }

    public void Dispose() => Stop();
}
