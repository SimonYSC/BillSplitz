//
//  ReceiptParserService.swift
//  BillSplitz
//

import Foundation

struct ReceiptParseResult: Equatable {
    var items: [ReceiptItem]
    var tax: Decimal
    var tip: Decimal
}

struct ReceiptParserService {
    func parse(_ text: String) -> ReceiptParseResult {
        var items: [ReceiptItem] = []
        var tax = Decimal(0)
        var tip = Decimal(0)

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let amountMatch = lastAmount(in: trimmed) else {
                continue
            }

            let label = itemName(from: trimmed, removing: amountMatch.range)
            let lowercasedLabel = label.lowercased()

            if lowercasedLabel.contains("tax") {
                tax += amountMatch.amount
                continue
            }

            if lowercasedLabel.contains("tip") || lowercasedLabel.contains("gratuity") {
                tip += amountMatch.amount
                continue
            }

            if lowercasedLabel.contains("subtotal") || lowercasedLabel == "total" {
                continue
            }

            let category = inferCategory(for: label)
            let item = ReceiptItem(
                rawText: trimmed,
                normalizedName: label.isEmpty ? "Item \(items.count + 1)" : label,
                unitPrice: amountMatch.amount,
                category: category,
                assignmentMode: .unassigned
            )
            items.append(item)
        }

        return ReceiptParseResult(items: items, tax: tax, tip: tip)
    }

    private func lastAmount(in line: String) -> (amount: Decimal, range: Range<String.Index>)? {
        let pattern = #"[-]?\$?\d+(?:,\d{3})*(?:\.\d{2})?"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = expression.matches(in: line, range: range).last,
              let stringRange = Range(match.range, in: line) else {
            return nil
        }

        let amountText = String(line[stringRange])
        guard let amount = CurrencyFormatter.decimal(from: amountText) else {
            return nil
        }

        return (amount, stringRange)
    }

    private func itemName(from line: String, removing amountRange: Range<String.Index>) -> String {
        var label = line
        label.removeSubrange(amountRange)
        return label
            .replacingOccurrences(of: #"[-:]+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inferCategory(for label: String) -> ReceiptItemCategory {
        let lowercasedLabel = label.lowercased()

        if lowercasedLabel.contains("tax")
            || lowercasedLabel.contains("fee")
            || lowercasedLabel.contains("discount") {
            return .adjustment
        }

        if ["beer", "wine", "cocktail", "soda", "tea", "coffee", "drink"].contains(where: lowercasedLabel.contains) {
            return .drink
        }

        if ["dessert", "cake", "mochi", "ice cream", "pie", "sticky rice"].contains(where: lowercasedLabel.contains) {
            return .dessert
        }

        if ["appetizer", "starter", "gyoza", "edamame", "wings", "fries", "chips", "spring roll"].contains(where: lowercasedLabel.contains) {
            return .appetizer
        }

        return .main
    }
}
