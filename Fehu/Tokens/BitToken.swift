//
//  BitToken.swift
//  Fehu
//
//  Created by Wolf McNally on 12/6/20.
//

import SwiftUI

final class BitToken: Token {
    let id: UUID = UUID()
    let value: Bool

    init(value: Bool) {
        self.value = value
    }

    static func random<T>(using generator: inout T) -> BitToken where T : RandomNumberGenerator {
        BitToken(value: Bool.random(using: &generator))
    }
}

extension BitToken: ValueViewable {
    static var minimumWidth: CGFloat { 30 }

    static func symbol(for value: Bool) -> String {
        value ? "🅗" : "Ⓣ"
    }

    var view: AnyView {
        AnyView(
            Text(Self.symbol(for: value))
            .font(regularFont(size: 18))
            .padding(5)
            .background(Color.gray.opacity(0.7))
            .cornerRadius(5)
        )
    }

    static func values(from string: String) -> [BitToken]? {
        var result: [BitToken] = []
        for c in string {
            switch c {
            case "1":
                result.append(BitToken(value: true))
            case "0":
                result.append(BitToken(value: false))
            default:
                return nil
            }
        }
        return result
    }

    static func string(from values: [BitToken]) -> String {
        String(values.map { $0.value ? Character("1") : Character("0") })
    }
}