//
//  ReportExportService.swift
//  InterviewIQ
//
//  Created by Clarice Harijanto
//

import Foundation
import UIKit

// ReportExportService: generates CSV and PDF report files locally on the device.
// Files are written to the app's temp directory and returned as URLs
// for UIActivityViewController sharing (UC-06).
// nonisolated: pure report generation, off the main actor. See
// CandidateRankingService for why MainActor-isolated deinits crash under test.
nonisolated final class ReportExportService {

    // MARK: - CSV

    func generateCSV(sessionTitle: String, candidates: [RankedCandidate]) throws -> URL {
        var lines: [String] = []

        // Header block
        lines.append("InterviewIQ - Candidate Comparison Report")
        lines.append("Session: \(sessionTitle)")
        lines.append("Generated: \(formattedDate(Date()))")
        lines.append("")

        // Column headers
        lines.append("Rank,Candidate Name,Total Score (%),Submitted At,Notes,Transcript")

        // Data rows
        for candidate in candidates {
            let submittedAt = candidate.submittedAt.map { formattedDate($0) } ?? "—"
            let notes = candidate.notes.isEmpty ? "—" : candidate.notes
            let transcript = candidate.transcript.isEmpty ? "—" : candidate.transcript
            // Wrap fields containing commas/quotes in double-quotes
            let row = [
                "\(candidate.rank)",
                csvEscape(candidate.name),
                "\(candidate.totalScore)",
                csvEscape(submittedAt),
                csvEscape(notes),
                csvEscape(transcript)
            ].joined(separator: ",")
            lines.append(row)
        }

        let content = lines.joined(separator: "\n")
        let url = tempFileURL(named: "InterviewIQ_\(sanitized(sessionTitle))_Report.csv")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - PDF

    func generatePDF(
        sessionTitle: String,
        sessionId: String,
        candidates: [RankedCandidate]
    ) throws -> URL {
        let pageWidth: CGFloat = 595       // A4 points
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2

        let url = tempFileURL(named: "InterviewIQ_\(sanitized(sessionTitle))_Report.pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        try renderer.writePDF(to: url) { ctx in
            var yOffset: CGFloat = margin

            func newPageIfNeeded(needed: CGFloat) {
                if yOffset + needed > pageHeight - margin {
                    ctx.beginPage()
                    yOffset = margin
                }
            }

            ctx.beginPage()

            // Header
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 79/255, green: 70/255, blue: 229/255, alpha: 1)
            ]
            "InterviewIQ".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: headerAttrs)
            yOffset += 30

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.secondaryLabel
            ]
            "Candidate Comparison Report".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: subAttrs)
            yOffset += 20

            // Divider
            UIColor(red: 79/255, green: 70/255, blue: 229/255, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(x: margin, y: yOffset, width: contentWidth, height: 2)).fill()
            yOffset += 10

            // Session meta
            let metaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.label
            ]
            "Session: \(sessionTitle)".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: metaAttrs)
            yOffset += 16
            "Generated: \(formattedDate(Date()))".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: metaAttrs)
            yOffset += 28

            // Summary Stats
            if !candidates.isEmpty {
                let avg = candidates.reduce(0) { $0 + $1.totalScore } / candidates.count
                let statAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: UIColor.label
                ]
                let statLine = "Total Candidates: \(candidates.count)   |   Average Score: \(avg)%   |   Top Score: \(candidates.first?.totalScore ?? 0)%"
                statLine.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: statAttrs)
                yOffset += 24
            }

            // Table Header. Notes + Transcript split the remaining width evenly.
            let fixed: CGFloat = 34 + 140 + 60 + 95
            let split = (contentWidth - fixed) / 2
            let colWidths: [CGFloat] = [34, 140, 60, 95, split, split]
            let colHeaders = ["Rank", "Candidate", "Score (%)", "Submitted", "Notes", "Transcript"]

            UIColor(red: 79/255, green: 70/255, blue: 229/255, alpha: 0.1).setFill()
            UIBezierPath(rect: CGRect(x: margin, y: yOffset, width: contentWidth, height: 22)).fill()

            let thAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: UIColor(red: 79/255, green: 70/255, blue: 229/255, alpha: 1)
            ]
            var xCursor = margin + 6
            for (i, header) in colHeaders.enumerated() {
                header.draw(at: CGPoint(x: xCursor, y: yOffset + 5), withAttributes: thAttrs)
                xCursor += colWidths[i]
            }
            yOffset += 22

            // Table Rows
            let tdAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.label
            ]
            let rankAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor(red: 79/255, green: 70/255, blue: 229/255, alpha: 1)
            ]

            for (index, candidate) in candidates.enumerated() {
                newPageIfNeeded(needed: 20)

                // Alternate row background
                if index % 2 == 0 {
                    UIColor.systemGray6.setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: yOffset, width: contentWidth, height: 20)).fill()
                }

                xCursor = margin + 6
                let submittedText = candidate.submittedAt.map { formattedDate($0) } ?? "—"
                let notesText = candidate.notes.isEmpty ? "—" : candidate.notes
                let transcriptText = candidate.transcript.isEmpty ? "—" : candidate.transcript

                let row: [(String, [NSAttributedString.Key: Any])] = [
                    ("#\(candidate.rank)", rankAttrs),
                    (candidate.name, tdAttrs),
                    ("\(candidate.totalScore)%", tdAttrs),
                    (submittedText, tdAttrs),
                    (notesText, tdAttrs),
                    (transcriptText, tdAttrs)
                ]

                for (i, (text, attrs)) in row.enumerated() {
                    let maxW = colWidths[i] - 8
                    let truncated = truncateText(text, width: maxW, attrs: attrs)
                    truncated.draw(at: CGPoint(x: xCursor, y: yOffset + 5), withAttributes: attrs)
                    xCursor += colWidths[i]
                }
                yOffset += 20
            }

            // Bottom line
            UIColor.systemGray4.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: yOffset, width: contentWidth, height: 1)).fill()
            yOffset += 16

            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            "Generated by InterviewIQ · Confidential".draw(
                at: CGPoint(x: margin, y: pageHeight - margin - 14),
                withAttributes: footerAttrs
            )
        }

        return url
    }

    // MARK: - Private Helpers

    private func tempFileURL(named fileName: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    private func sanitized(_ string: String) -> String {
        string.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func truncateText(_ text: String, width: CGFloat, attrs: [NSAttributedString.Key: Any]) -> String {
        var result = text
        while (result as NSString).size(withAttributes: attrs).width > width && result.count > 1 {
            result = String(result.dropLast())
        }
        if result.count < text.count { result += "…" }
        return result
    }
}
