import Foundation

enum Wire {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }
}
