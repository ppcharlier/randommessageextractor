import Foundation

struct DelimiterPair: Codable {
    let id: String
    let name: String
    let startChar: UInt8
    let endChar: UInt8
    let description: String
}

let STANDARD_DELIMITERS: [DelimiterPair] = [
    DelimiterPair(
        id: "0",
        name: "SOH/ETX",
        startChar: 0x01,
        endChar: 0x03,
        description: "Start of Heading / End of Text"
    ),
    DelimiterPair(
        id: "1",
        name: "STX/ETX",
        startChar: 0x02,
        endChar: 0x03,
        description: "Start of Text / End of Text"
    ),
    DelimiterPair(
        id: "2",
        name: "STX/ETB",
        startChar: 0x02,
        endChar: 0x17,
        description: "Start of Text / End of Transmission Block"
    ),
    DelimiterPair(
        id: "3",
        name: "SOH/EOT",
        startChar: 0x01,
        endChar: 0x04,
        description: "Start of Heading / End of Transmission"
    ),
    DelimiterPair(
        id: "4",
        name: "FS/GS",
        startChar: 0x1C,
        endChar: 0x1D,
        description: "File Separator / Group Separator"
    ),
    DelimiterPair(
        id: "5",
        name: "RS/US",
        startChar: 0x1E,
        endChar: 0x1F,
        description: "Record Separator / Unit Separator"
    ),
    DelimiterPair(
        id: "6",
        name: "ESC/ESC",
        startChar: 0x1B,
        endChar: 0x1B,
        description: "Escape (same as end)"
    ),
    DelimiterPair(
        id: "7",
        name: "DLE/DLE",
        startChar: 0x10,
        endChar: 0x10,
        description: "Data Link Escape (same as end)"
    )
]

func getDelimiterByName(_ name: String) -> DelimiterPair? {
    return STANDARD_DELIMITERS.first { $0.name == name }
}
