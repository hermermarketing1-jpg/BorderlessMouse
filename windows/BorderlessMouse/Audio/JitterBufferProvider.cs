using NAudio.Wave;

namespace BorderlessMouse.Audio;

/// <summary>
/// Bufor pierścieniowy między odbiorem UDP a WASAPI. Utrzymuje docelowe
/// opóźnienie: przy niedoborze gra ciszę i czeka aż uzbiera się TargetMs,
/// przy nadmiarze (narastające opóźnienie) tnie do wartości docelowej.
/// </summary>
public sealed class JitterBufferProvider : IWaveProvider
{
    private readonly byte[] _ring;
    private readonly object _gate = new();
    private int _readPos;
    private int _count;
    private bool _prebuffering = true;
    private int _targetBytes;
    private int _maxBytes;

    public WaveFormat WaveFormat { get; }
    public long Underruns { get; private set; }
    public long Overruns { get; private set; }

    public JitterBufferProvider(WaveFormat format, int targetMs)
    {
        WaveFormat = format;
        _ring = new byte[format.AverageBytesPerSecond * 2]; // 2 s
        SetTarget(targetMs);
    }

    public int TargetMs { get; private set; }

    public void SetTarget(int targetMs)
    {
        TargetMs = Math.Clamp(targetMs, 2, 500);
        _targetBytes = Align(WaveFormat.AverageBytesPerSecond * TargetMs / 1000);
        _maxBytes = Math.Min(_ring.Length - WaveFormat.BlockAlign, _targetBytes * 3 + WaveFormat.AverageBytesPerSecond / 20);
    }

    /// <summary>Aktualne wypełnienie w milisekundach.</summary>
    public int BufferedMs
    {
        get { lock (_gate) return (int)(_count * 1000L / WaveFormat.AverageBytesPerSecond); }
    }

    private int Align(int bytes) => bytes - bytes % WaveFormat.BlockAlign;

    public void Write(ReadOnlySpan<byte> data)
    {
        lock (_gate)
        {
            if (data.Length >= _ring.Length) data = data[^(_ring.Length - WaveFormat.BlockAlign)..];
            var free = _ring.Length - _count;
            if (data.Length > free)
            {
                // wyrzuć najstarsze
                var drop = data.Length - free;
                _readPos = (_readPos + drop) % _ring.Length;
                _count -= drop;
            }
            var writePos = (_readPos + _count) % _ring.Length;
            var first = Math.Min(data.Length, _ring.Length - writePos);
            data[..first].CopyTo(_ring.AsSpan(writePos));
            if (first < data.Length) data[first..].CopyTo(_ring.AsSpan(0));
            _count += data.Length;

            if (_count > _maxBytes)
            {
                // opóźnienie narosło – przytnij do docelowego
                var drop = Align(_count - _targetBytes);
                _readPos = (_readPos + drop) % _ring.Length;
                _count -= drop;
                Overruns++;
            }
        }
    }

    public void WriteSilence(int bytes)
    {
        if (bytes <= 0) return;
        Span<byte> zeros = stackalloc byte[Math.Min(bytes, 4096)];
        zeros.Clear();
        while (bytes > 0)
        {
            var n = Math.Min(bytes, zeros.Length);
            Write(zeros[..n]);
            bytes -= n;
        }
    }

    public void Clear()
    {
        lock (_gate)
        {
            _count = 0;
            _readPos = 0;
            _prebuffering = true;
        }
    }

    public int Read(byte[] buffer, int offset, int count)
    {
        lock (_gate)
        {
            if (_prebuffering)
            {
                if (_count >= _targetBytes)
                {
                    _prebuffering = false;
                }
                else
                {
                    Array.Clear(buffer, offset, count);
                    return count;
                }
            }

            var take = Math.Min(count, _count);
            take = Align(take);
            var first = Math.Min(take, _ring.Length - _readPos);
            Array.Copy(_ring, _readPos, buffer, offset, first);
            if (first < take) Array.Copy(_ring, 0, buffer, offset + first, take - first);
            _readPos = (_readPos + take) % _ring.Length;
            _count -= take;

            if (take < count)
            {
                Array.Clear(buffer, offset + take, count - take);
                Underruns++;
                _prebuffering = true;
            }
            return count;
        }
    }
}
