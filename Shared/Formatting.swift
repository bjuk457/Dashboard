import SwiftUI

enum Fmt {
    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "de_DE")))
    }

    static func compact(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName).locale(Locale(identifier: "de_DE")))
    }

    static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "de_DE")))
    }

    static func signed(_ value: Int) -> String {
        value > 0 ? "+\(number(value))" : number(value)
    }

    static func signedPercent(_ value: Double?) -> String {
        guard let value else { return "neu" }
        return (value > 0 ? "+" : "") + decimal(value) + " %"
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "de_DE")))
    }
}

/// Green when the change is good, red when it is bad.
struct ChangeLabel: View {
    let text: String
    let good: Bool?

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(good == nil ? Color.secondary : (good! ? Color.green : Color.red))
    }
}
