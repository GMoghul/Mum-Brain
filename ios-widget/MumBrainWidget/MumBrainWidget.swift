// Home screen and lock screen widget: today's jobs at a glance, in the app's own colours and fonts.
// The app writes a small summary (next 8 days of jobs, brain dump count, theme) to the shared App Group;
// this widget only reads it. It moves to the next day by itself at midnight.

import WidgetKit
import SwiftUI

// MARK: - Data from the app

struct WJob: Codable, Hashable, Identifiable {
    let id: String
    let t: String
    let tm: String
    let c: String
    let done: Bool
    let star: Bool
}

struct WDay: Codable {
    let d: String
    let jobs: [WJob]
}

struct WTheme: Codable {
    let accent: String
    let bg: String
    let ink: String
    let muted: String
    let line: String
    let w: [String]
    let wash: Double
    let mode: String
}

struct WData: Codable {
    let v: Int
    let days: [WDay]
    let marks: [String: Int]
    let dump: Int
    let late: Int
    let theme: WTheme
}

enum Store {
    static let group = "group.com.gmoghul.mumbrainsorted"

    static func load() -> WData? {
        guard let s = UserDefaults(suiteName: group)?.string(forKey: "widget"),
              let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WData.self, from: d)
    }

    static let defaultTheme = WTheme(accent: "#5F52B0", bg: "#FAF7F2", ink: "#23201C", muted: "#6B645B",
                                     line: "#ECE5DA", w: ["#D9CDF4", "#F4D7C7", "#CFE2D3"], wash: 0.5, mode: "auto")

    // Shown in the widget gallery before the app has sent anything
    static func sample() -> WData {
        let k = Fmt.ymd.string(from: Date())
        let jobs = [
            WJob(id: "1", t: "Book dentist", tm: "3 pm", c: "#5B9FE0", done: false, star: true),
            WJob(id: "2", t: "Pay the bills", tm: "", c: "#62B07D", done: false, star: false),
            WJob(id: "3", t: "Pick up parcel", tm: "", c: "#F29A4A", done: false, star: false),
            WJob(id: "4", t: "Call back", tm: "", c: "#9483DB", done: true, star: false)
        ]
        return WData(v: 1, days: [WDay(d: k, jobs: jobs)], marks: [k: 3], dump: 4, late: 0, theme: defaultTheme)
    }
}

enum Fmt {
    static func make(_ f: String) -> DateFormatter {
        let d = DateFormatter()
        d.locale = Locale(identifier: "en_GB")
        d.dateFormat = f
        return d
    }
    static let ymd: DateFormatter = {
        let d = DateFormatter()
        d.calendar = Calendar(identifier: .gregorian)
        d.locale = Locale(identifier: "en_US_POSIX")
        d.dateFormat = "yyyy-MM-dd"
        return d
    }()
    static let weekday = make("EEEE")
    static let dateLine = make("d MMMM")
    static let shortDate = make("d MMM")
    static let month = make("MMMM")
}

// MARK: - Colours and fonts (match the app)

func rgb(_ hex: String) -> (Double, Double, Double) {
    var s = hex.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return (0.6, 0.6, 0.6) }
    return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
}

extension Color {
    init(hex: String) {
        let c = rgb(hex)
        self.init(red: c.0, green: c.1, blue: c.2)
    }
}

func mixed(_ a: String, _ b: String, _ k: Double) -> Color {
    let x = rgb(a), y = rgb(b)
    return Color(red: x.0 * k + y.0 * (1 - k), green: x.1 * k + y.1 * (1 - k), blue: x.2 * k + y.2 * (1 - k))
}

struct Palette {
    let bg: Color
    let ink: Color
    let muted: Color
    let line: Color
    let accent: Color
    let w: [Color]
    let wash: Double
}

func palette(_ t: WTheme, scheme: ColorScheme) -> Palette {
    let dark = t.mode == "dark" || (t.mode != "light" && scheme == .dark)
    if dark {
        return Palette(bg: Color(hex: "#131519"), ink: Color(hex: "#ECEEF1"), muted: Color(hex: "#8C929B"),
                       line: Color(hex: "#2B2F36"), accent: mixed(t.accent, "#FFFFFF", 0.68),
                       w: t.w.map { Color(hex: $0) }, wash: t.wash * 0.3)
    }
    return Palette(bg: Color(hex: t.bg),
                   ink: Color(hex: t.ink.isEmpty ? "#1B1E23" : t.ink),
                   muted: Color(hex: t.muted.isEmpty ? "#6E747D" : t.muted),
                   line: Color(hex: t.line.isEmpty ? "#E4E7EB" : t.line),
                   accent: Color(hex: t.accent),
                   w: t.w.map { Color(hex: $0) }, wash: t.wash)
}

enum F {
    static func head(_ size: CGFloat) -> Font { .custom("Fraunces-SemiBold", size: size) }
    static func sub(_ size: CGFloat) -> Font { .custom("Fraunces-Italic", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("Figtree-Medium", size: size) }
    static func bold(_ size: CGFloat) -> Font { .custom("Figtree-SemiBold", size: size) }
}

let starColor = Color(hex: "#F2C14E")
let todayURL = URL(string: "mumbrain://today")
let dumpURL = URL(string: "mumbrain://dump")!

// MARK: - Timeline

struct DayEntry: TimelineEntry {
    let date: Date
    let data: WData?

    var key: String { Fmt.ymd.string(from: date) }
    var jobs: [WJob] { data?.days.first(where: { $0.d == key })?.jobs ?? [] }
    var open: [WJob] { jobs.filter { !$0.done } }
    var doneCount: Int { jobs.filter { $0.done }.count }
    var dump: Int { data?.dump ?? 0 }
    var late: Int { data?.late ?? 0 }
    var weekday: String { Fmt.weekday.string(from: date) }
    var dateLine: String { Fmt.dateLine.string(from: date) }
    var shortDate: String { Fmt.shortDate.string(from: date) }
    var greeting: String {
        let h = Calendar.current.component(.hour, from: date)
        return h < 12 ? "Good morning" : (h < 17 ? "Good afternoon" : "Good evening")
    }
    var headline: String {
        if jobs.isEmpty { return "Nothing planned" }
        if open.isEmpty { return "All done today" }
        return open.count == 1 ? "1 to do today" : "\(open.count) to do today"
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), data: Store.sample())
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: Date(), data: Store.load() ?? Store.sample()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let data = Store.load()
        let now = Date()
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        var dates: [Date] = [now]
        // a new entry each midnight (new day) and at noon / 5pm (greeting changes), for the next 8 days
        for day in 0..<8 {
            guard let d = cal.date(byAdding: .day, value: day, to: start) else { continue }
            for hour in [0, 12, 17] {
                if let t = cal.date(bySettingHour: hour, minute: 0, second: 0, of: d), t > now { dates.append(t) }
            }
        }
        completion(Timeline(entries: dates.map { DayEntry(date: $0, data: data) }, policy: .atEnd))
    }
}

// MARK: - Pieces

struct Wash: View {
    let p: Palette
    var body: some View {
        GeometryReader { g in
            ZStack {
                p.bg
                if p.wash > 0 && p.w.count >= 3 {
                    blob(p.w[0], UnitPoint(x: 0.15, y: 0.2), g.size, 0.6)
                    blob(p.w[1], UnitPoint(x: 0.9, y: 0.15), g.size, 0.5)
                    blob(p.w[2], UnitPoint(x: 0.75, y: 0.95), g.size, 0.6)
                }
            }
        }
    }

    func blob(_ c: Color, _ at: UnitPoint, _ size: CGSize, _ r: CGFloat) -> some View {
        RadialGradient(gradient: Gradient(colors: [c.opacity(p.wash), c.opacity(0)]), center: at,
                       startRadius: 0, endRadius: max(size.width, size.height) * r)
    }
}

struct Tick: View {
    let color: Color
    let done: Bool
    let size: CGFloat
    var check: Color = .white
    var body: some View {
        ZStack {
            if done {
                Circle().fill(color)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundColor(check)
            } else {
                Circle().strokeBorder(color, lineWidth: max(1.5, size * 0.13))
            }
        }
        .frame(width: size, height: size)
    }
}

struct Row: View {
    let job: WJob
    let p: Palette
    let size: CGFloat
    var body: some View {
        HStack(spacing: 7) {
            Tick(color: p.ink, done: job.done, size: size + 1, check: p.bg)
            Text(job.t)
                .font(F.body(size))
                .foregroundColor(job.done ? p.muted : p.ink)
                .strikethrough(job.done, color: p.muted)
                .lineLimit(1)
            Spacer(minLength: 2)
            if !job.tm.isEmpty {
                Text(job.tm)
                    .font(F.body(size - 2))
                    .foregroundColor(p.muted)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

struct JobList: View {
    let e: DayEntry
    let p: Palette
    let limit: Int
    let size: CGFloat
    let spacing: CGFloat
    var body: some View {
        // show every job if they all fit, otherwise leave a line for "+N more"
        let shown = e.jobs.count <= limit ? e.jobs : Array(e.jobs.prefix(limit - 1))
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(shown) { j in
                Row(job: j, p: p, size: size)
            }
            if e.jobs.count > shown.count {
                Text("+\(e.jobs.count - shown.count) more")
                    .font(F.body(size - 1.5))
                    .foregroundColor(p.muted)
            }
        }
    }
}

struct Message: View {
    let e: DayEntry
    let p: Palette
    let size: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if !e.jobs.isEmpty {
                    Tick(color: p.accent, done: true, size: size + 2)
                }
                Text(e.headline).font(F.bold(size)).foregroundColor(p.ink)
            }
            if e.jobs.isEmpty {
                Text(e.dump > 0 ? "\(e.dump) waiting in Brain dump" : "Enjoy your day")
                    .font(F.body(size - 1.5))
                    .foregroundColor(p.muted)
            } else {
                Text(e.doneCount == 1 ? "1 job ticked off" : "\(e.doneCount) jobs ticked off")
                    .font(F.body(size - 1.5))
                    .foregroundColor(p.muted)
            }
        }
    }
}

struct ProgressLine: View {
    let e: DayEntry
    let p: Palette
    var body: some View {
        let total = e.jobs.count
        let frac = total > 0 ? CGFloat(e.doneCount) / CGFloat(total) : 0
        if e.doneCount == 0 {
            // nothing ticked yet: no empty bar or zero, just the count
            Text(total == 1 ? "1 job today" : "\(total) jobs today")
                .font(F.body(11))
                .foregroundColor(p.muted)
        } else {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(p.line)
                    Capsule().fill(p.accent).frame(width: g.size.width * frac)
                }
            }
            .frame(height: 5)
            Text("\(e.doneCount) of \(total) done")
                .font(F.body(11))
                .foregroundColor(p.muted)
        }
        }
    }
}

struct MiniMonth: View {
    let e: DayEntry
    let p: Palette
    let cell: CGFloat = 13

    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }
    var first: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: e.date)) ?? e.date
    }
    var daysInMonth: Int { cal.range(of: .day, in: .month, for: first)?.count ?? 30 }
    var offset: Int { (cal.component(.weekday, from: first) + 5) % 7 }
    var todayN: Int { cal.component(.day, from: e.date) }
    var rows: Int { (offset + daysInMonth + 6) / 7 }

    func marked(_ n: Int) -> Bool {
        guard let d = cal.date(byAdding: .day, value: n - 1, to: first) else { return false }
        return (e.data?.marks[Fmt.ymd.string(from: d)] ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.month.string(from: e.date).uppercased())
                .font(F.bold(8.5))
                .tracking(1)
                .foregroundColor(p.muted)
                .padding(.bottom, 1)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(["M", "T", "W", "T", "F", "S", "S"][i])
                        .font(F.bold(7.5))
                        .foregroundColor(p.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { c in
                        dayCell(r * 7 + c - offset + 1)
                    }
                }
            }
        }
    }

    func dayCell(_ n: Int) -> some View {
        ZStack {
            if n >= 1 && n <= daysInMonth {
                if n == todayN {
                    Circle().fill(p.accent).frame(width: cell + 1, height: cell + 1)
                }
                Text("\(n)")
                    .font(F.body(8))
                    .foregroundColor(n == todayN ? Color.white : (n < todayN ? p.muted : p.ink))
                if n != todayN && marked(n) {
                    Circle().fill(p.accent).frame(width: 2.5, height: 2.5).offset(y: cell * 0.48)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: cell)
    }
}

struct BrainDumpChip: View {
    let e: DayEntry
    let p: Palette
    var body: some View {
        Link(destination: dumpURL) {
            HStack(spacing: 5) {
                Image(systemName: "tray").font(.system(size: 10.5, weight: .semibold))
                Text(e.dump == 1 ? "1 in Brain dump" : "\(e.dump) in Brain dump").font(F.bold(11.5))
            }
            .foregroundColor(p.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(p.accent.opacity(0.13)))
        }
    }
}

// MARK: - Sizes

struct SmallView: View {
    let e: DayEntry
    let p: Palette
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(e.weekday)
                .font(F.head(22))
                .foregroundColor(p.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(e.shortDate)
                .font(F.sub(13))
                .foregroundColor(p.muted)
            Spacer(minLength: 6)
            if e.open.isEmpty {
                Message(e: e, p: p, size: 12.5)
            } else {
                JobList(e: e, p: p, limit: 4, size: 11.5, spacing: 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MediumView: View {
    let e: DayEntry
    let p: Palette
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(e.greeting)
                    .font(F.sub(12))
                    .foregroundColor(p.muted)
                Text(e.weekday)
                    .font(F.head(24))
                    .foregroundColor(p.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(e.dateLine)
                    .font(F.sub(13))
                    .foregroundColor(p.muted)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if !e.jobs.isEmpty {
                    ProgressLine(e: e, p: p)
                }
            }
            .frame(width: 108, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 0) {
                if e.open.isEmpty {
                    Spacer(minLength: 0)
                    Message(e: e, p: p, size: 13)
                    Spacer(minLength: 0)
                } else {
                    JobList(e: e, p: p, limit: 5, size: 11.5, spacing: 6)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct LargeView: View {
    let e: DayEntry
    let p: Palette
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(e.greeting)
                        .font(F.sub(13))
                        .foregroundColor(p.muted)
                    Text(e.weekday)
                        .font(F.head(30))
                        .foregroundColor(p.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(e.dateLine)
                        .font(F.sub(15))
                        .foregroundColor(p.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                MiniMonth(e: e, p: p).frame(width: 124)
            }
            if !e.jobs.isEmpty {
                ProgressLine(e: e, p: p).padding(.top, 8)
            }
            Group {
                if e.open.isEmpty {
                    Message(e: e, p: p, size: 14)
                } else {
                    JobList(e: e, p: p, limit: 6, size: 14, spacing: 8)
                }
            }
            .padding(.top, 12)
            Spacer(minLength: 4)
            HStack {
                if e.dump > 0 {
                    BrainDumpChip(e: e, p: p)
                }
                Spacer(minLength: 4)
                if e.late > 0 {
                    Text("\(e.late) still to do from earlier")
                        .font(F.body(11))
                        .foregroundColor(p.muted)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct NoData: View {
    let p: Palette
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today").font(F.head(20)).foregroundColor(p.ink)
            Text("Open the app once to see your jobs here.")
                .font(F.body(12))
                .foregroundColor(p.muted)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@available(iOSApplicationExtension 16.0, *)
struct AccessoryView: View {
    let e: DayEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            if e.jobs.isEmpty {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "checkmark").font(.system(size: 18, weight: .semibold))
                }
            } else {
                Gauge(value: Double(e.doneCount), in: 0...Double(e.jobs.count)) {
                    Text("Done")
                } currentValueLabel: {
                    Text("\(e.open.count)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        case .accessoryInline:
            Text(e.headline)
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(e.headline).font(.headline).widgetAccentable()
                ForEach(Array(e.open.prefix(2))) { j in
                    Text(j.tm.isEmpty ? j.t : "\(j.tm) · \(j.t)")
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Widget

struct WidgetBg: ViewModifier {
    let p: Palette
    let accessory: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            if accessory {
                content.containerBackground(for: .widget) { Color.clear }
            } else {
                content.containerBackground(for: .widget) { Wash(p: p) }
            }
        } else {
            if accessory {
                content
            } else {
                content.padding(16).background(Wash(p: p))
            }
        }
    }
}

struct EntryView: View {
    let e: DayEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var scheme

    var accessory: Bool {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: return false
        default: return true
        }
    }

    var body: some View {
        let p = palette(e.data?.theme ?? Store.defaultTheme, scheme: scheme)
        content(p)
            .modifier(WidgetBg(p: p, accessory: accessory))
            .widgetURL(todayURL)
    }

    @ViewBuilder
    func content(_ p: Palette) -> some View {
        if e.data == nil {
            NoData(p: p)
        } else {
            switch family {
            case .systemSmall:
                SmallView(e: e, p: p)
            case .systemMedium:
                MediumView(e: e, p: p)
            case .systemLarge, .systemExtraLarge:
                LargeView(e: e, p: p)
            default:
                if #available(iOSApplicationExtension 16.0, *) {
                    AccessoryView(e: e)
                }
            }
        }
    }
}

struct TodayWidget: Widget {
    let kind = "MumBrainToday"

    var families: [WidgetFamily] {
        if #available(iOSApplicationExtension 16.0, *) {
            return [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        }
        return [.systemSmall, .systemMedium, .systemLarge]
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            EntryView(e: entry)
        }
        .configurationDisplayName("Today")
        .description("Today's jobs at a glance. Tap to open Today.")
        .supportedFamilies(families)
    }
}

@main
struct AppWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}
