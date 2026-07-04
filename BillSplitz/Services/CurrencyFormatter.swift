//
//  CurrencyFormatter.swift
//  BillSplitz
//

import Foundation

enum CurrencyFormatter {
    static func string(for amount: Decimal, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    static func editableString(for amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    static func decimal(from text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Decimal(string: cleaned)
    }
}
