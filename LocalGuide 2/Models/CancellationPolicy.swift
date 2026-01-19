import Foundation

/// Per-listing cancellation policy.
///
/// The platform is a marketplace; each Guide/Host defines their own policy.
/// Backend uses these fields to compute refund eligibility.
struct CancellationPolicy: Codable, Hashable {
    /// Currently only "custom" is supported.
    var type: String = "custom"

    /// Full refund if canceled >= freeCancelHours before the start time.
    var freeCancelHours: Int = 48

    /// Refund percentage (0-100) if canceled after deadline.
    var refundPercentAfterDeadline: Int = 0

    /// Refund percentage for no-show (0-100). Optional.
    var noShowRefundPercent: Int = 0
}
