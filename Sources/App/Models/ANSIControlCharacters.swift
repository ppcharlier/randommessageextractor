import Foundation

/// Complete ANSI control character definitions (0x00-0x1F + 0x7F)
struct ANSIControlCharacter: Codable, Hashable, Identifiable {
    let id: UInt8
    let code: UInt8
    let abbreviation: String
    let fullName: String
    let description: String

    var displayFormat: String {
        "0x\(String(format: "%02X", code)) (\(abbreviation))"
    }
}

let ANSI_CONTROL_CHARACTERS: [ANSIControlCharacter] = [
    ANSIControlCharacter(id: 0x00, code: 0x00, abbreviation: "NUL", fullName: "Null", description: "No operation"),
    ANSIControlCharacter(id: 0x01, code: 0x01, abbreviation: "SOH", fullName: "Start of Heading", description: "Message header"),
    ANSIControlCharacter(id: 0x02, code: 0x02, abbreviation: "STX", fullName: "Start of Text", description: "Text start"),
    ANSIControlCharacter(id: 0x03, code: 0x03, abbreviation: "ETX", fullName: "End of Text", description: "Text end"),
    ANSIControlCharacter(id: 0x04, code: 0x04, abbreviation: "EOT", fullName: "End of Transmission", description: "Transmission end"),
    ANSIControlCharacter(id: 0x05, code: 0x05, abbreviation: "ENQ", fullName: "Enquiry", description: "Request status"),
    ANSIControlCharacter(id: 0x06, code: 0x06, abbreviation: "ACK", fullName: "Acknowledge", description: "Positive response"),
    ANSIControlCharacter(id: 0x07, code: 0x07, abbreviation: "BEL", fullName: "Bell", description: "Ring bell/alert"),
    ANSIControlCharacter(id: 0x08, code: 0x08, abbreviation: "BS", fullName: "Backspace", description: "Move back one position"),
    ANSIControlCharacter(id: 0x09, code: 0x09, abbreviation: "HT", fullName: "Horizontal Tab", description: "Tab right"),
    ANSIControlCharacter(id: 0x0A, code: 0x0A, abbreviation: "LF", fullName: "Line Feed", description: "Move to next line"),
    ANSIControlCharacter(id: 0x0B, code: 0x0B, abbreviation: "VT", fullName: "Vertical Tab", description: "Tab down"),
    ANSIControlCharacter(id: 0x0C, code: 0x0C, abbreviation: "FF", fullName: "Form Feed", description: "New page"),
    ANSIControlCharacter(id: 0x0D, code: 0x0D, abbreviation: "CR", fullName: "Carriage Return", description: "Move to line start"),
    ANSIControlCharacter(id: 0x0E, code: 0x0E, abbreviation: "SO", fullName: "Shift Out", description: "Activate alt charset"),
    ANSIControlCharacter(id: 0x0F, code: 0x0F, abbreviation: "SI", fullName: "Shift In", description: "Activate std charset"),
    ANSIControlCharacter(id: 0x10, code: 0x10, abbreviation: "DLE", fullName: "Data Link Escape", description: "Link escape"),
    ANSIControlCharacter(id: 0x11, code: 0x11, abbreviation: "DC1", fullName: "Device Control 1", description: "XON - Resume transmission"),
    ANSIControlCharacter(id: 0x12, code: 0x12, abbreviation: "DC2", fullName: "Device Control 2", description: "Device control 2"),
    ANSIControlCharacter(id: 0x13, code: 0x13, abbreviation: "DC3", fullName: "Device Control 3", description: "XOFF - Stop transmission"),
    ANSIControlCharacter(id: 0x14, code: 0x14, abbreviation: "DC4", fullName: "Device Control 4", description: "Device control 4"),
    ANSIControlCharacter(id: 0x15, code: 0x15, abbreviation: "NAK", fullName: "Negative Acknowledge", description: "Negative response"),
    ANSIControlCharacter(id: 0x16, code: 0x16, abbreviation: "SYN", fullName: "Synchronous Idle", description: "Sync character"),
    ANSIControlCharacter(id: 0x17, code: 0x17, abbreviation: "ETB", fullName: "End of Transmission Block", description: "Block end"),
    ANSIControlCharacter(id: 0x18, code: 0x18, abbreviation: "CAN", fullName: "Cancel", description: "Cancel transmission"),
    ANSIControlCharacter(id: 0x19, code: 0x19, abbreviation: "EM", fullName: "End of Medium", description: "Medium end"),
    ANSIControlCharacter(id: 0x1A, code: 0x1A, abbreviation: "SUB", fullName: "Substitute", description: "Replace bad char"),
    ANSIControlCharacter(id: 0x1B, code: 0x1B, abbreviation: "ESC", fullName: "Escape", description: "Start escape sequence"),
    ANSIControlCharacter(id: 0x1C, code: 0x1C, abbreviation: "FS", fullName: "File Separator", description: "CSV-like separator"),
    ANSIControlCharacter(id: 0x1D, code: 0x1D, abbreviation: "GS", fullName: "Group Separator", description: "Group separator"),
    ANSIControlCharacter(id: 0x1E, code: 0x1E, abbreviation: "RS", fullName: "Record Separator", description: "Record separator"),
    ANSIControlCharacter(id: 0x1F, code: 0x1F, abbreviation: "US", fullName: "Unit Separator", description: "Unit separator"),
    ANSIControlCharacter(id: 0x7F, code: 0x7F, abbreviation: "DEL", fullName: "Delete", description: "Delete character"),
]

// Extraction method enumeration
enum ExtractionMethod: String, Codable, CaseIterable, Identifiable {
    case signalingStrict = "signalingStrict"
    case signalingFlexible = "signalingFlexible"
    case regularExpression = "regularExpression"
    case bitByBitScan = "bitByBitScan"
    case hybridMode = "hybridMode"
    case experimentalProtocol = "experimentalProtocol"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .signalingStrict: return "Signaling Strict"
        case .signalingFlexible: return "Signaling Flexible"
        case .regularExpression: return "Regular Expression"
        case .bitByBitScan: return "Bit-by-Bit Scan"
        case .hybridMode: return "Hybrid Mode"
        case .experimentalProtocol: return "Experimental Protocol"
        }
    }

    var description: String {
        switch self {
        case .signalingStrict: return "Requires exact framing with start/end characters"
        case .signalingFlexible: return "Permissive signaling character detection"
        case .regularExpression: return "Pattern matching with regex [A-Za-z0-9']+"
        case .bitByBitScan: return "Binary stream analysis with bit manipulation"
        case .hybridMode: return "Combines all methods in parallel"
        case .experimentalProtocol: return "Variable-size byte sets with integrity checking"
        }
    }
}
