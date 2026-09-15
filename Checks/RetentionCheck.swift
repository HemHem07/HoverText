import Foundation

@main
enum RetentionCheck {
    static func main() {
        assert(CaptureRetention.oneDay.isShorter(than: .sevenDays))
        assert(CaptureRetention.sevenDays.isShorter(than: .thirtyDays))
        assert(CaptureRetention.thirtyDays.isShorter(than: .never))
        assert(!CaptureRetention.thirtyDays.isShorter(than: .sevenDays))
    }
}
