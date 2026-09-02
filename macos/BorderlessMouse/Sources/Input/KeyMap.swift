import Foundation
import CoreGraphics

/// Mapowanie klawiszy Windows (scancode set 1 + flaga extended, zapasowo VK)
/// na wirtualne kody klawiszy macOS (kVK_*) lub klawisze multimedialne.
enum KeyTarget: Equatable {
    case key(CGKeyCode)
    /// NX_KEYTYPE_* (zdarzenia systemowe: głośność, odtwarzanie)
    case media(Int32)
}

enum KeyMap {
    // kVK_* (Carbon HIToolbox/Events.h)
    enum VK {
        static let a: CGKeyCode = 0x00, s: CGKeyCode = 0x01, d: CGKeyCode = 0x02, f: CGKeyCode = 0x03
        static let h: CGKeyCode = 0x04, g: CGKeyCode = 0x05, z: CGKeyCode = 0x06, x: CGKeyCode = 0x07
        static let c: CGKeyCode = 0x08, v: CGKeyCode = 0x09, isoSection: CGKeyCode = 0x0A, b: CGKeyCode = 0x0B
        static let q: CGKeyCode = 0x0C, w: CGKeyCode = 0x0D, e: CGKeyCode = 0x0E, r: CGKeyCode = 0x0F
        static let y: CGKeyCode = 0x10, t: CGKeyCode = 0x11
        static let n1: CGKeyCode = 0x12, n2: CGKeyCode = 0x13, n3: CGKeyCode = 0x14, n4: CGKeyCode = 0x15
        static let n6: CGKeyCode = 0x16, n5: CGKeyCode = 0x17, equal: CGKeyCode = 0x18, n9: CGKeyCode = 0x19
        static let n7: CGKeyCode = 0x1A, minus: CGKeyCode = 0x1B, n8: CGKeyCode = 0x1C, n0: CGKeyCode = 0x1D
        static let rightBracket: CGKeyCode = 0x1E, o: CGKeyCode = 0x1F, u: CGKeyCode = 0x20, leftBracket: CGKeyCode = 0x21
        static let i: CGKeyCode = 0x22, p: CGKeyCode = 0x23, returnKey: CGKeyCode = 0x24, l: CGKeyCode = 0x25
        static let j: CGKeyCode = 0x26, quote: CGKeyCode = 0x27, k: CGKeyCode = 0x28, semicolon: CGKeyCode = 0x29
        static let backslash: CGKeyCode = 0x2A, comma: CGKeyCode = 0x2B, slash: CGKeyCode = 0x2C, n: CGKeyCode = 0x2D
        static let m: CGKeyCode = 0x2E, period: CGKeyCode = 0x2F, tab: CGKeyCode = 0x30, space: CGKeyCode = 0x31
        static let grave: CGKeyCode = 0x32, delete: CGKeyCode = 0x33, escape: CGKeyCode = 0x35
        static let rightCommand: CGKeyCode = 0x36, command: CGKeyCode = 0x37, shift: CGKeyCode = 0x38
        static let capsLock: CGKeyCode = 0x39, option: CGKeyCode = 0x3A, control: CGKeyCode = 0x3B
        static let rightShift: CGKeyCode = 0x3C, rightOption: CGKeyCode = 0x3D, rightControl: CGKeyCode = 0x3E
        static let function: CGKeyCode = 0x3F, f17: CGKeyCode = 0x40, keypadDecimal: CGKeyCode = 0x41
        static let keypadMultiply: CGKeyCode = 0x43, keypadPlus: CGKeyCode = 0x45, keypadClear: CGKeyCode = 0x47
        static let keypadDivide: CGKeyCode = 0x4B, keypadEnter: CGKeyCode = 0x4C, keypadMinus: CGKeyCode = 0x4E
        static let f18: CGKeyCode = 0x4F, f19: CGKeyCode = 0x50, keypadEquals: CGKeyCode = 0x51
        static let keypad0: CGKeyCode = 0x52, keypad1: CGKeyCode = 0x53, keypad2: CGKeyCode = 0x54, keypad3: CGKeyCode = 0x55
        static let keypad4: CGKeyCode = 0x56, keypad5: CGKeyCode = 0x57, keypad6: CGKeyCode = 0x58, keypad7: CGKeyCode = 0x59
        static let f20: CGKeyCode = 0x5A, keypad8: CGKeyCode = 0x5B, keypad9: CGKeyCode = 0x5C
        static let f5: CGKeyCode = 0x60, f6: CGKeyCode = 0x61, f7: CGKeyCode = 0x62, f3: CGKeyCode = 0x63
        static let f8: CGKeyCode = 0x64, f9: CGKeyCode = 0x65, f11: CGKeyCode = 0x67, f13: CGKeyCode = 0x69
        static let f16: CGKeyCode = 0x6A, f14: CGKeyCode = 0x6B, f10: CGKeyCode = 0x6D, f12: CGKeyCode = 0x6F
        static let f15: CGKeyCode = 0x71, help: CGKeyCode = 0x72, home: CGKeyCode = 0x73, pageUp: CGKeyCode = 0x74
        static let forwardDelete: CGKeyCode = 0x75, f4: CGKeyCode = 0x76, end: CGKeyCode = 0x77, f2: CGKeyCode = 0x78
        static let pageDown: CGKeyCode = 0x79, f1: CGKeyCode = 0x7A, leftArrow: CGKeyCode = 0x7B, rightArrow: CGKeyCode = 0x7C
        static let downArrow: CGKeyCode = 0x7D, upArrow: CGKeyCode = 0x7E
    }

    enum Media {
        static let soundUp: Int32 = 0, soundDown: Int32 = 1, brightnessUp: Int32 = 2, brightnessDown: Int32 = 3
        static let mute: Int32 = 7, play: Int32 = 16, next: Int32 = 17, previous: Int32 = 18
        static let fast: Int32 = 19, rewind: Int32 = 20
    }

    static let modifierKeys: Set<CGKeyCode> = [
        VK.shift, VK.rightShift, VK.control, VK.rightControl,
        VK.option, VK.rightOption, VK.command, VK.rightCommand, VK.capsLock, VK.function,
    ]

    static let arrowAndNavKeys: Set<CGKeyCode> = [
        VK.leftArrow, VK.rightArrow, VK.upArrow, VK.downArrow,
        VK.home, VK.end, VK.pageUp, VK.pageDown, VK.forwardDelete, VK.help,
    ]

    static let functionKeys: Set<CGKeyCode> = [
        VK.f1, VK.f2, VK.f3, VK.f4, VK.f5, VK.f6, VK.f7, VK.f8, VK.f9, VK.f10, VK.f11, VK.f12,
        VK.f13, VK.f14, VK.f15, VK.f16, VK.f17, VK.f18, VK.f19, VK.f20,
    ]

    static let keypadKeys: Set<CGKeyCode> = [
        VK.keypad0, VK.keypad1, VK.keypad2, VK.keypad3, VK.keypad4, VK.keypad5, VK.keypad6, VK.keypad7,
        VK.keypad8, VK.keypad9, VK.keypadDecimal, VK.keypadMultiply, VK.keypadPlus, VK.keypadClear,
        VK.keypadDivide, VK.keypadEnter, VK.keypadMinus, VK.keypadEquals,
    ]

    /// Klucz: scancode | (extended ? 0x100 : 0)
    private static let ext: UInt16 = 0x100

    private static let scancodeTable: [UInt16: KeyTarget] = [
        0x01: .key(VK.escape),
        0x02: .key(VK.n1), 0x03: .key(VK.n2), 0x04: .key(VK.n3), 0x05: .key(VK.n4), 0x06: .key(VK.n5),
        0x07: .key(VK.n6), 0x08: .key(VK.n7), 0x09: .key(VK.n8), 0x0A: .key(VK.n9), 0x0B: .key(VK.n0),
        0x0C: .key(VK.minus), 0x0D: .key(VK.equal), 0x0E: .key(VK.delete), 0x0F: .key(VK.tab),
        0x10: .key(VK.q), 0x11: .key(VK.w), 0x12: .key(VK.e), 0x13: .key(VK.r), 0x14: .key(VK.t),
        0x15: .key(VK.y), 0x16: .key(VK.u), 0x17: .key(VK.i), 0x18: .key(VK.o), 0x19: .key(VK.p),
        0x1A: .key(VK.leftBracket), 0x1B: .key(VK.rightBracket),
        0x1C: .key(VK.returnKey), 0x1C | ext: .key(VK.keypadEnter),
        0x1D: .key(VK.control), 0x1D | ext: .key(VK.rightControl),
        0x1E: .key(VK.a), 0x1F: .key(VK.s), 0x20: .key(VK.d), 0x21: .key(VK.f), 0x22: .key(VK.g),
        0x23: .key(VK.h), 0x24: .key(VK.j), 0x25: .key(VK.k), 0x26: .key(VK.l),
        0x27: .key(VK.semicolon), 0x28: .key(VK.quote), 0x29: .key(VK.grave),
        0x2A: .key(VK.shift), 0x2B: .key(VK.backslash),
        0x2C: .key(VK.z), 0x2D: .key(VK.x), 0x2E: .key(VK.c), 0x2F: .key(VK.v), 0x30: .key(VK.b),
        0x31: .key(VK.n), 0x32: .key(VK.m),
        0x33: .key(VK.comma), 0x34: .key(VK.period),
        0x35: .key(VK.slash), 0x35 | ext: .key(VK.keypadDivide),
        0x36: .key(VK.rightShift),
        0x37: .key(VK.keypadMultiply), 0x37 | ext: .key(VK.f13), // PrintScreen → F13
        0x38: .key(VK.option), 0x38 | ext: .key(VK.rightOption),
        0x39: .key(VK.space), 0x3A: .key(VK.capsLock),
        0x3B: .key(VK.f1), 0x3C: .key(VK.f2), 0x3D: .key(VK.f3), 0x3E: .key(VK.f4), 0x3F: .key(VK.f5),
        0x40: .key(VK.f6), 0x41: .key(VK.f7), 0x42: .key(VK.f8), 0x43: .key(VK.f9), 0x44: .key(VK.f10),
        0x45: .key(VK.f15),                      // Pause → F15
        0x45 | ext: .key(VK.keypadClear),        // NumLock → Clear
        0x46: .key(VK.f14),                      // ScrollLock → F14
        0x47: .key(VK.keypad7), 0x47 | ext: .key(VK.home),
        0x48: .key(VK.keypad8), 0x48 | ext: .key(VK.upArrow),
        0x49: .key(VK.keypad9), 0x49 | ext: .key(VK.pageUp),
        0x4A: .key(VK.keypadMinus),
        0x4B: .key(VK.keypad4), 0x4B | ext: .key(VK.leftArrow),
        0x4C: .key(VK.keypad5),
        0x4D: .key(VK.keypad6), 0x4D | ext: .key(VK.rightArrow),
        0x4E: .key(VK.keypadPlus),
        0x4F: .key(VK.keypad1), 0x4F | ext: .key(VK.end),
        0x50: .key(VK.keypad2), 0x50 | ext: .key(VK.downArrow),
        0x51: .key(VK.keypad3), 0x51 | ext: .key(VK.pageDown),
        0x52: .key(VK.keypad0), 0x52 | ext: .key(VK.help),          // Insert → Help
        0x53: .key(VK.keypadDecimal), 0x53 | ext: .key(VK.forwardDelete),
        0x56: .key(VK.isoSection),               // klawisz <> na klawiaturach ISO
        0x57: .key(VK.f11), 0x58: .key(VK.f12),
        0x5B | ext: .key(VK.command), 0x5C | ext: .key(VK.rightCommand),
        0x5D | ext: .key(VK.rightCommand),       // klawisz Menu → prawy Cmd
        0x59: .key(VK.keypadEquals),
        0x64: .key(VK.f13), 0x65: .key(VK.f14), 0x66: .key(VK.f15), 0x67: .key(VK.f16),
        0x68: .key(VK.f17), 0x69: .key(VK.f18), 0x6A: .key(VK.f19), 0x6B: .key(VK.f20),
        0x70: .key(VK.isoSection),               // JIS Kana – najbliższy sensowny odpowiednik
        0x7D: .key(VK.backslash),                // JIS Yen
    ]

    /// Zapasowe mapowanie po VK (Windows virtual-key), gdy brak scancode.
    private static let vkTable: [UInt16: KeyTarget] = [
        0x08: .key(VK.delete), 0x09: .key(VK.tab), 0x0D: .key(VK.returnKey), 0x10: .key(VK.shift),
        0x11: .key(VK.control), 0x12: .key(VK.option), 0x14: .key(VK.capsLock), 0x1B: .key(VK.escape),
        0x20: .key(VK.space), 0x21: .key(VK.pageUp), 0x22: .key(VK.pageDown), 0x23: .key(VK.end),
        0x24: .key(VK.home), 0x25: .key(VK.leftArrow), 0x26: .key(VK.upArrow), 0x27: .key(VK.rightArrow),
        0x28: .key(VK.downArrow), 0x2D: .key(VK.help), 0x2E: .key(VK.forwardDelete),
        0x30: .key(VK.n0), 0x31: .key(VK.n1), 0x32: .key(VK.n2), 0x33: .key(VK.n3), 0x34: .key(VK.n4),
        0x35: .key(VK.n5), 0x36: .key(VK.n6), 0x37: .key(VK.n7), 0x38: .key(VK.n8), 0x39: .key(VK.n9),
        0x41: .key(VK.a), 0x42: .key(VK.b), 0x43: .key(VK.c), 0x44: .key(VK.d), 0x45: .key(VK.e),
        0x46: .key(VK.f), 0x47: .key(VK.g), 0x48: .key(VK.h), 0x49: .key(VK.i), 0x4A: .key(VK.j),
        0x4B: .key(VK.k), 0x4C: .key(VK.l), 0x4D: .key(VK.m), 0x4E: .key(VK.n), 0x4F: .key(VK.o),
        0x50: .key(VK.p), 0x51: .key(VK.q), 0x52: .key(VK.r), 0x53: .key(VK.s), 0x54: .key(VK.t),
        0x55: .key(VK.u), 0x56: .key(VK.v), 0x57: .key(VK.w), 0x58: .key(VK.x), 0x59: .key(VK.y),
        0x5A: .key(VK.z), 0x5B: .key(VK.command), 0x5C: .key(VK.rightCommand),
        0x60: .key(VK.keypad0), 0x61: .key(VK.keypad1), 0x62: .key(VK.keypad2), 0x63: .key(VK.keypad3),
        0x64: .key(VK.keypad4), 0x65: .key(VK.keypad5), 0x66: .key(VK.keypad6), 0x67: .key(VK.keypad7),
        0x68: .key(VK.keypad8), 0x69: .key(VK.keypad9), 0x6A: .key(VK.keypadMultiply), 0x6B: .key(VK.keypadPlus),
        0x6D: .key(VK.keypadMinus), 0x6E: .key(VK.keypadDecimal), 0x6F: .key(VK.keypadDivide),
        0x70: .key(VK.f1), 0x71: .key(VK.f2), 0x72: .key(VK.f3), 0x73: .key(VK.f4), 0x74: .key(VK.f5),
        0x75: .key(VK.f6), 0x76: .key(VK.f7), 0x77: .key(VK.f8), 0x78: .key(VK.f9), 0x79: .key(VK.f10),
        0x7A: .key(VK.f11), 0x7B: .key(VK.f12), 0x7C: .key(VK.f13), 0x7D: .key(VK.f14), 0x7E: .key(VK.f15),
        0x7F: .key(VK.f16), 0x80: .key(VK.f17), 0x81: .key(VK.f18), 0x82: .key(VK.f19), 0x83: .key(VK.f20),
        0xA0: .key(VK.shift), 0xA1: .key(VK.rightShift), 0xA2: .key(VK.control), 0xA3: .key(VK.rightControl),
        0xA4: .key(VK.option), 0xA5: .key(VK.rightOption),
        0xBA: .key(VK.semicolon), 0xBB: .key(VK.equal), 0xBC: .key(VK.comma), 0xBD: .key(VK.minus),
        0xBE: .key(VK.period), 0xBF: .key(VK.slash), 0xC0: .key(VK.grave), 0xDB: .key(VK.leftBracket),
        0xDC: .key(VK.backslash), 0xDD: .key(VK.rightBracket), 0xDE: .key(VK.quote), 0xE2: .key(VK.isoSection),
    ]

    /// Klawisze multimedialne – rozpoznawane po VK (są jednoznaczne).
    private static let mediaByVK: [UInt16: KeyTarget] = [
        0xAD: .media(Media.mute), 0xAE: .media(Media.soundDown), 0xAF: .media(Media.soundUp),
        0xB0: .media(Media.next), 0xB1: .media(Media.previous), 0xB2: .media(Media.play),
        0xB3: .media(Media.play),
    ]

    static func lookup(scancode: UInt16, vk: UInt16, extended: Bool) -> KeyTarget? {
        if let media = mediaByVK[vk] { return media }
        let key = scancode | (extended ? ext : 0)
        if scancode != 0, let t = scancodeTable[key] { return t }
        if scancode != 0, extended, let t = scancodeTable[scancode] { return t }
        return vkTable[vk]
    }
}
