//
//  ShareExportService.swift
//  BillSplitz
//

import Foundation

struct ShareExportService {
    func plainTextSummary(draft: SplitDraft, settlementLines: [SettlementLine]) -> String {
        let currencyCode = draft.session.currencyCode
        let participantByID = Dictionary(uniqueKeysWithValues: draft.participants.map { ($0.id, $0) })
        let payerName = draft.payer?.name ?? "the payer"

        var lines: [String] = []
        lines.append(draft.session.title.uppercased())
        lines.append("PAID BY \(payerName.uppercased()) · TOTAL \(CurrencyFormatter.string(for: draft.receiptTotal, currencyCode: currencyCode))")
        lines.append("")
        lines.append("WHO OWES WHAT")

        for settlementLine in settlementLines {
            guard let participant = participantByID[settlementLine.participantID] else {
                continue
            }

            let name = participant.name.uppercased()
            let dots = String(repeating: ".", count: max(3, 15 - name.count))
            lines.append("\(name) \(dots) \(CurrencyFormatter.string(for: settlementLine.grandTotal, currencyCode: currencyCode))")
        }

        if let payerPaymentMethod = draft.payerPaymentMethod {
            lines.append("")
            lines.append("PAY \(payerName.uppercased()) VIA \(payerPaymentMethod.displayName.uppercased())")

            if let handle = draft.payerPaymentHandle, !handle.isEmpty {
                lines.append(handle)
            }
        }

        lines.append("")
        lines.append("BREAKDOWN")
        for settlementLine in settlementLines {
            guard let participant = participantByID[settlementLine.participantID] else {
                continue
            }

            lines.append(
                "\(participant.name.uppercased()) items \(CurrencyFormatter.editableString(for: settlementLine.itemSubtotal)) tax \(CurrencyFormatter.editableString(for: settlementLine.taxShare)) tip \(CurrencyFormatter.editableString(for: settlementLine.tipShare))"
            )
        }

        lines.append("")
        lines.append("— BILLSPLITZ")
        return lines.joined(separator: "\n")
    }
}
