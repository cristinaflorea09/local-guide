import Foundation
import UIKit

final class ReportService {
    static let shared = ReportService()
    private init() {}

    struct MonthlySummary {
        let month: Date
        let gross: Double
        let platformFee: Double
        let net: Double
        let vatAmount: Double
    }

    private func applicationFeeMajor(for booking: Booking) -> Double {
        guard let amount = booking.applicationFeeAmount else { return 0 }
        return Double(amount) / 100.0
    }

    func computeMonthlySummary(bookings: [Booking], vatRegistered: Bool, vatRate: Int) -> MonthlySummary {
        let gross = bookings.reduce(0.0) { $0 + $1.totalPrice }
        let platformFee = bookings.reduce(0.0) { $0 + applicationFeeMajor(for: $1) }
        let net = max(0, gross - platformFee)
        let vat = vatRegistered ? computeVATFromGross(gross: gross, vatRate: vatRate) : 0
        return MonthlySummary(month: Date(), gross: gross, platformFee: platformFee, net: net, vatAmount: vat)
    }

    /// If prices are VAT-inclusive, VAT component = gross * r / (100 + r)
    func computeVATFromGross(gross: Double, vatRate: Int) -> Double {
        let r = Double(vatRate)
        guard r > 0 else { return 0 }
        return gross * r / (100.0 + r)
    }

    /// Generates a simple tax-ready PDF report for the given month.
    /// Returns a file URL in temporary directory.
    func generateMonthlyPDF(
        sellerName: String,
        sellerId: String,
        month: Date,
        bookings: [Booking],
        currencySymbol: String,
        vatRegistered: Bool,
        vatRate: Int
    ) throws -> URL {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: month)
        let monthTitle = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)

        let gross = bookings.reduce(0.0) { $0 + $1.totalPrice }
        let fee = bookings.reduce(0.0) { $0 + applicationFeeMajor(for: $1) }
        let net = max(0, gross - fee)
        let vat = vatRegistered ? computeVATFromGross(gross: gross, vatRate: vatRate) : 0

        let meta = [
            kCGPDFContextCreator: "LocalGuide",
            kCGPDFContextAuthor: sellerName,
            kCGPDFContextTitle: "Monthly Report \(monthTitle)"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = meta as [String: Any]
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            let title = "LocalGuide - Monthly Earnings Report"
            let subtitle = "Seller: \(sellerName) (\(sellerId))\nMonth: \(monthTitle)"
            let totals = "Gross: \(currencySymbol)\(gross.round2())   Platform fee: \(currencySymbol)\(fee.round2())   Net: \(currencySymbol)\(net.round2())"
            let vatLine = vatRegistered ? "VAT (\(vatRate)% incl.): \(currencySymbol)\(vat.round2())" : "VAT: not registered"

            var y: CGFloat = 40
            y = draw(text: title, font: .boldSystemFont(ofSize: 18), x: 40, y: y, w: pageRect.width - 80)
            y += 6
            y = draw(text: subtitle, font: .systemFont(ofSize: 12), x: 40, y: y, w: pageRect.width - 80)
            y += 10
            y = draw(text: totals, font: .systemFont(ofSize: 12), x: 40, y: y, w: pageRect.width - 80)
            y += 2
            y = draw(text: vatLine, font: .systemFont(ofSize: 12), x: 40, y: y, w: pageRect.width - 80)
            y += 16

            // Table header
            y = draw(text: "Date", font: .boldSystemFont(ofSize: 11), x: 40, y: y, w: 90)
            _ = draw(text: "Listing", font: .boldSystemFont(ofSize: 11), x: 140, y: y, w: 230)
            _ = draw(text: "People", font: .boldSystemFont(ofSize: 11), x: 375, y: y, w: 60)
            _ = draw(text: "Gross", font: .boldSystemFont(ofSize: 11), x: 435, y: y, w: 70)
            _ = draw(text: "Fee", font: .boldSystemFont(ofSize: 11), x: 505, y: y, w: 60)
            y += 10
            drawLine(y: y, width: pageRect.width)
            y += 8

            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none

            let sorted = bookings.sorted(by: { $0.startDate < $1.startDate })
            for b in sorted {
                if y > pageRect.height - 60 {
                    ctx.beginPage()
                    y = 40
                }
                let dateStr = df.string(from: b.startDate)
                let listing = b.effectiveListingType.capitalized + " - " + b.effectiveListingId
                let grossStr = "\(currencySymbol)\(b.totalPrice.round2())"
                let feeStr = "\(currencySymbol)\(applicationFeeMajor(for: b).round2())"

                _ = draw(text: dateStr, font: .systemFont(ofSize: 10), x: 40, y: y, w: 90)
                _ = draw(text: listing, font: .systemFont(ofSize: 10), x: 140, y: y, w: 230)
                _ = draw(text: "\(b.peopleCount)", font: .systemFont(ofSize: 10), x: 375, y: y, w: 60)
                _ = draw(text: grossStr, font: .systemFont(ofSize: 10), x: 435, y: y, w: 70)
                _ = draw(text: feeStr, font: .systemFont(ofSize: 10), x: 505, y: y, w: 60)
                y += 14
            }
        }

        let tmp = FileManager.default.temporaryDirectory
        let url = tmp.appendingPathComponent("LocalGuide_Report_\(sellerId)_\(monthTitle).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func draw(text: String, font: UIFont, x: CGFloat, y: CGFloat, w: CGFloat) -> CGFloat {
        let attr: [NSAttributedString.Key: Any] = [.font: font]
        let rect = CGRect(x: x, y: y, width: w, height: 1000)
        let s = NSAttributedString(string: text, attributes: attr)
        let size = s.boundingRect(with: CGSize(width: w, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        s.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return y + ceil(size.height)
    }

    private func drawLine(y: CGFloat, width: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 40, y: y))
        path.addLine(to: CGPoint(x: width - 40, y: y))
        UIColor.black.withAlphaComponent(0.15).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private extension Double {
    func round2() -> String { String(format: "%.2f", self) }
}

