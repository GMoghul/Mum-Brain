// Home screen and lock screen widget: today's jobs at a glance, in the app's own colours and fonts.
// The app writes a small summary (next 8 days of jobs, brain dump count, theme) to the shared App Group;
// this widget only reads it. It moves to the next day by itself at midnight.

import WidgetKit
import SwiftUI
import UIKit
import AppIntents

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
    var n: Int? = nil    // all jobs that day (the app sends at most 14 of them)
    var nd: Int? = nil   // how many of those are done
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
    var font: String? = nil   // the app's font choice (v1.10.0); "clean" = Soft serif
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

    static let defaultTheme = WTheme(accent: "#6548A8", bg: "#FAF7F2", ink: "#23201C", muted: "#6B645B",
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

extension Store {
    // Tick or untick a job from the widget (iOS 17+). The widget's own copy updates straight away;
    // the app picks the tick up from "widgetTicks" the next time it opens and saves it properly.
    static func toggle(id: String, day: String) {
        guard let d = UserDefaults(suiteName: group) else { return }
        var nowDone = true
        if let s = d.string(forKey: "widget"), let data = s.data(using: .utf8),
           var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           var days = root["days"] as? [[String: Any]],
           let di = days.firstIndex(where: { ($0["d"] as? String) == day }),
           var jobs = days[di]["jobs"] as? [[String: Any]],
           let ji = jobs.firstIndex(where: { ($0["id"] as? String) == id }) {
            let was = (jobs[ji]["done"] as? Bool) ?? false
            nowDone = !was
            jobs[ji]["done"] = nowDone
            days[di]["jobs"] = jobs
            if let nd = days[di]["nd"] as? Int { days[di]["nd"] = max(0, nd + (nowDone ? 1 : -1)) }
            root["days"] = days
            if let out = try? JSONSerialization.data(withJSONObject: root), let str = String(data: out, encoding: .utf8) {
                d.set(str, forKey: "widget")
            }
        }
        var ticks = (d.array(forKey: "widgetTicks") as? [[String: Any]]) ?? []
        ticks.removeAll { ($0["id"] as? String) == id && ($0["d"] as? String) == day }
        ticks.append(["id": id, "d": day, "done": nowDone, "at": Date().timeIntervalSince1970])
        d.set(ticks, forKey: "widgetTicks")
    }
}

@available(iOSApplicationExtension 17.0, *)
struct ToggleJobIntent: AppIntent {
    static var title: LocalizedStringResource = "Tick off a job"
    static var isDiscoverable: Bool = false
    @Parameter(title: "Job") var id: String
    @Parameter(title: "Day") var day: String
    init() {}
    init(id: String, day: String) {
        self.id = id
        self.day = day
    }
    func perform() async throws -> some IntentResult {
        Store.toggle(id: id, day: day)
        return .result()
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
    static let shortMonth = make("MMM")
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
    var dark = false
}

func palette(_ t: WTheme, scheme: ColorScheme) -> Palette {
    let dark = t.mode == "dark" || (t.mode != "light" && scheme == .dark)
    if dark {
        return Palette(bg: Color(hex: "#131519"), ink: Color(hex: "#ECEEF1"), muted: Color(hex: "#8C929B"),
                       line: Color(hex: "#2B2F36"), accent: mixed(t.accent, "#FFFFFF", 0.68),
                       w: t.w.map { Color(hex: $0) }, wash: 0, dark: true)
    }
    // v1.10.0: plain white background (no theme colour or wash), like Dawn
    return Palette(bg: Color.white,
                   ink: Color(hex: t.ink.isEmpty ? "#1B1E23" : t.ink),
                   muted: Color(hex: t.muted.isEmpty ? "#6E747D" : t.muted),
                   line: Color(hex: t.line.isEmpty ? "#E4E7EB" : t.line),
                   accent: Color(hex: t.accent),
                   w: t.w.map { Color(hex: $0) }, wash: 0)
}

// Fonts follow the app's font choice (v1.11.0):
// Calm (default) = SF Rounded, Native = SF Pro, Editorial = Newsreader headings, Soft = Fraunces/Figtree.
// The greeting is always a soft italic serif (Newsreader, or Fraunces for Soft).
enum F {
    static var font: String { Store.load()?.theme.font ?? "sfround" }
    static func sys(_ size: CGFloat, _ w: Font.Weight) -> Font {
        font == "native" || font == "news" ? .system(size: size, weight: w) : .system(size: size, weight: w, design: .rounded)
    }
    static func head(_ size: CGFloat) -> Font {
        switch font {
        case "clean": return .custom("Fraunces-SemiBold", size: size)
        case "news": return .custom("Newsreader-Regular", size: size * 1.06)
        default: return sys(size, .semibold)
        }
    }
    static func greet(_ size: CGFloat) -> Font {
        font == "clean" ? .custom("Fraunces-Italic", size: size) : .custom("Newsreader-Italic", size: size * 1.08)
    }
    static func sub(_ size: CGFloat) -> Font { font == "clean" ? .custom("Fraunces-Italic", size: size) : sys(size, .regular) }
    static func body(_ size: CGFloat) -> Font { font == "clean" ? .custom("Figtree-Medium", size: size) : sys(size, .regular) }
    static func bold(_ size: CGFloat) -> Font { font == "clean" ? .custom("Figtree-SemiBold", size: size) : sys(size, .medium) }
}

// Progress bar drawn as the icon's three rows (lilac, blue, teal)
struct RowsBar: View {
    let frac: CGFloat
    let track: Color
    static let bands = [Color(hex: "#B8A3E8"), Color(hex: "#93B6EE"), Color(hex: "#9DD3CE")]
    var body: some View {
        GeometryReader { g in
            VStack(spacing: 1.2) {
                ForEach(0..<3, id: \.self) { i in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1).fill(track)
                        RoundedRectangle(cornerRadius: 1).fill(RowsBar.bands[i]).frame(width: g.size.width * frac)
                    }
                }
            }
        }
    }
}

let starColor = Color(hex: "#F2C14E")
let todayURL = URL(string: "mumbrain://today")
let dumpURL = URL(string: "mumbrain://dump")!

// MARK: - Timeline

enum WStyle { case wash, plain }

struct DayEntry: TimelineEntry {
    let date: Date
    let data: WData?

    var key: String { Fmt.ymd.string(from: date) }
    var day: WDay? { data?.days.first(where: { $0.d == key }) }
    var jobs: [WJob] { day?.jobs ?? [] }
    var open: [WJob] { jobs.filter { !$0.done } }
    var total: Int { max(day?.n ?? 0, jobs.count) }
    var doneCount: Int { day?.nd ?? jobs.filter { $0.done }.count }
    var openCount: Int { max(0, total - doneCount) }
    var dump: Int { data?.dump ?? 0 }
    var late: Int { data?.late ?? 0 }
    var weekday: String { Fmt.weekday.string(from: date) }
    var dateLine: String { Fmt.dateLine.string(from: date) }
    var shortDate: String { Fmt.shortDate.string(from: date) }
    // British, the way you'd say it: "It's Sunday", "25th October", "25th Oct"
    var itsDay: String { "It\u{2019}s \(weekday)" }
    var ordinal: String {
        let n = Calendar.current.component(.day, from: date)
        let suf = (11...13).contains(n % 100) ? "th" : ([1: "st", 2: "nd", 3: "rd"][n % 10] ?? "th")
        return "\(n)\(suf)"
    }
    var spokenDate: String { "\(ordinal) \(Fmt.month.string(from: date))" }
    var spokenShort: String { "\(ordinal) \(Fmt.shortMonth.string(from: date))" }
    var greeting: String {
        let h = Calendar.current.component(.hour, from: date)
        return h < 12 ? "Good morning" : (h < 17 ? "Good afternoon" : "Good evening")
    }
    var headline: String {
        if jobs.isEmpty { return "Nothing planned" }
        if open.isEmpty { return "All done today" }
        return openCount == 1 ? "1 to do today" : "\(openCount) to do today"
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

// The app icon (brain in rows), shown top left
struct BrainIcon: View {
    let size: CGFloat
    var body: some View {
        Group {
            if let ui = UIImage(named: "BrainIcon") {
                Image(uiImage: ui).resizable().interpolation(.high)
            } else {
                RowsBar(frac: 1, track: .clear)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 0.5))
    }
}

// One soft, slightly wavy brushstroke row
struct BrushRow: Shape {
    let seed: Double
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height, steps = 24
        func wob(_ x: Double, _ k: Double) -> CGFloat { CGFloat(sin(x * 0.045 + seed * k) * 0.6 + sin(x * 0.13 + seed * 2.1 * k) * 0.35) }
        p.move(to: CGPoint(x: -4, y: r.minY + wob(0, 1)))
        for i in 1...steps { let x = Double(w + 8) * Double(i) / Double(steps) - 4; p.addLine(to: CGPoint(x: CGFloat(x), y: r.minY + wob(x, 1))) }
        for i in stride(from: steps, through: 0, by: -1) { let x = Double(w + 8) * Double(i) / Double(steps) - 4; p.addLine(to: CGPoint(x: CGFloat(x), y: r.minY + h + wob(x, 1.7))) }
        p.closeSubpath()
        return p
    }
}

// Purple/blue + in the bottom right: opens Brain dump, ready to add
struct AddButton: View {
    let p: Palette
    var body: some View {
        Link(destination: dumpURL) {
            ZStack {
                Circle().fill(p.accent)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 26, height: 26)
        }
        .accessibilityLabel("Add to Brain dump")
    }
}

// The three painted rows, filling whatever height they're given (sits behind the bottom line, edge to edge)
struct WashBand: View {
    let dark: Bool
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                BrushRow(seed: Double(i) * 1.9 + 0.7).fill(RowsBar.bands[i])
            }
        }
        .blur(radius: 0.7)
        .opacity(dark ? 0.35 : 0.55)
        .allowsHitTesting(false)
    }
}

// The bottom line: job count on the left, "+N more", and the + button, with the wash centred behind it
struct BottomLine<Left: View, Mid: View>: View {
    let p: Palette
    let style: WStyle
    let leftWidth: CGFloat
    @ViewBuilder let left: () -> Left
    @ViewBuilder let mid: () -> Mid
    var body: some View {
        HStack(spacing: 14) {
            if leftWidth > 0 {
                left().frame(width: leftWidth, alignment: .leading)
            }
            mid()
            Spacer(minLength: 4)
            AddButton(p: p)
        }
        .frame(height: 26)
        .background(
            Group {
                if style == .wash {
                    WashBand(dark: p.dark).frame(height: 20).padding(.horizontal, -24)
                }
            }
        )
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
    var day: String = ""
    var tick: some View { Tick(color: p.ink, done: job.done, size: size + 1, check: p.bg) }
    var body: some View {
        HStack(spacing: 7) {
            if #available(iOSApplicationExtension 17.0, *), !day.isEmpty {
                // tap the circle to tick the job off (bigger tap area than the circle itself)
                Button(intent: ToggleJobIntent(id: job.id, day: day)) {
                    tick.padding(6).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(-6)
            } else {
                tick
            }
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
        let shown = e.total <= limit ? e.jobs : Array(e.jobs.prefix(limit - 1))
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(shown) { j in
                Row(job: j, p: p, size: size, day: e.key)
            }
            if e.total > shown.count {
                Text("+\(e.total - shown.count) more")
                    .font(F.body(size - 1.5))
                    .foregroundColor(p.muted)
            }
        }
    }
}

// Medium widget list: up to `count` jobs, centred in the space above the bottom line
struct MediumJobs: View {
    let e: DayEntry
    let p: Palette
    let count: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(e.jobs.prefix(count))) { j in
                Row(job: j, p: p, size: 12, day: e.key)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct Message: View {
    let e: DayEntry
    let p: Palette
    let size: CGFloat
    var centred = false
    var sub: String {
        if e.jobs.isEmpty { return e.dump > 0 ? "\(e.dump) waiting in Brain dump" : "Enjoy your day" }
        return e.doneCount == 1 ? "1 job ticked off" : "\(e.doneCount) jobs ticked off"
    }
    var body: some View {
        if centred {
            // all done / nothing planned: a calm resting state in the middle of the space
            VStack(spacing: 5) {
                if !e.jobs.isEmpty {
                    Tick(color: p.accent, done: true, size: size + 8).padding(.bottom, 2)
                }
                Text(e.headline).font(F.bold(size)).foregroundColor(p.ink)
                Text(sub).font(F.body(size - 1.5)).foregroundColor(p.muted)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if !e.jobs.isEmpty {
                        Tick(color: p.accent, done: true, size: size + 2)
                    }
                    Text(e.headline).font(F.bold(size)).foregroundColor(p.ink)
                }
                Text(sub).font(F.body(size - 1.5)).foregroundColor(p.muted)
            }
        }
    }
}

struct ProgressLine: View {
    let e: DayEntry
    let p: Palette
    var body: some View {
        let total = e.total
        let frac = total > 0 ? CGFloat(e.doneCount) / CGFloat(total) : 0
        if e.doneCount == 0 {
            // nothing ticked yet: no empty bar or zero, just the count
            Text(total == 1 ? "1 job today" : "\(total) jobs today")
                .font(F.body(11))
                .foregroundColor(p.muted)
        } else {
        VStack(alignment: .leading, spacing: 4) {
            RowsBar(frac: frac, track: p.line)
                .frame(height: 7)
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
            Text(e.spokenShort)
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
    let style: WStyle
    var body: some View {
        // up to 5 jobs, fewer if the iPhone's text size is larger (so nothing gets cut off)
        if #available(iOS 16.0, *) {
            ViewThatFits(in: .vertical) {
                MediumBody(e: e, p: p, style: style, count: 5)
                MediumBody(e: e, p: p, style: style, count: 4)
                MediumBody(e: e, p: p, style: style, count: 3)
            }
        } else {
            MediumBody(e: e, p: p, style: style, count: 5)
        }
    }
}

struct MediumBody: View {
    let e: DayEntry
    let p: Palette
    let style: WStyle
    let count: Int
    var resting: Bool { e.open.isEmpty }   // all done, or nothing planned
    var more: Int { max(0, e.total - min(count, e.jobs.count)) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    BrainIcon(size: 34).padding(.bottom, 7)
                    Text(e.greeting + "!")
                        .font(F.greet(17))
                        .foregroundColor(p.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(e.weekday)
                        .font(F.sub(13.5))
                        .foregroundColor(p.muted)
                        .lineLimit(1)
                        .padding(.top, 3)
                    Text(e.spokenDate)
                        .font(F.sub(13.5))
                        .foregroundColor(p.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 122, alignment: .topLeading)

                Group {
                    if resting {
                        Message(e: e, p: p, size: 14, centred: true)
                    } else {
                        MediumJobs(e: e, p: p, count: count)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            BottomLine(p: p, style: style, leftWidth: 122) {
                if !resting {
                    if style == .wash || e.doneCount == 0 {
                        // on the wash the rows are already there, so just the words
                        Text(e.doneCount == 0 ? (e.total == 1 ? "1 job today" : "\(e.total) jobs today") : "\(e.doneCount) of \(e.total) done")
                            .font(F.body(11.5))
                            .foregroundColor(p.muted)
                            .lineLimit(1)
                    } else {
                        ProgressLine(e: e, p: p)
                    }
                }
            } mid: {
                if !resting && more > 0 {
                    Text("+\(more) more")
                        .font(F.body(11.5))
                        .foregroundColor(p.muted)
                        .lineLimit(1)
                }
            }
            .padding(.top, 6)
        }
    }
}

struct LargeView: View {
    let e: DayEntry
    let p: Palette
    let style: WStyle
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    BrainIcon(size: 38).padding(.bottom, 8)
                    Text(e.greeting + "!")
                        .font(F.greet(21))
                        .foregroundColor(p.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(e.weekday)
                        .font(F.sub(15))
                        .foregroundColor(p.muted)
                        .padding(.top, 3)
                    Text(e.spokenDate)
                        .font(F.sub(15))
                        .foregroundColor(p.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                MiniMonth(e: e, p: p).frame(width: 124)
            }
            if !e.open.isEmpty {
                ProgressLine(e: e, p: p).padding(.top, 8)
            }
            Group {
                if e.open.isEmpty {
                    Message(e: e, p: p, size: 15, centred: true)
                } else {
                    JobList(e: e, p: p, limit: 6, size: 14, spacing: 8)
                }
            }
            .padding(.top, 12)
            Spacer(minLength: 4)
            BottomLine(p: p, style: style, leftWidth: 0) {
                EmptyView()
            } mid: {
                HStack(spacing: 10) {
                    if e.dump > 0 {
                        BrainDumpChip(e: e, p: p)
                    }
                    if e.late > 0 {
                        Text("\(e.late) still to do from earlier")
                            .font(F.body(11))
                            .foregroundColor(p.muted)
                            .lineLimit(1)
                    }
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
                Gauge(value: Double(e.doneCount), in: 0...Double(max(1, e.total))) {
                    Text("Done")
                } currentValueLabel: {
                    Text("\(e.openCount)")
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
    var wash = false
    var dark = false

    @ViewBuilder
    func bg() -> some View {
        ZStack {
            Wash(p: p)
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            if accessory {
                content.containerBackground(for: .widget) { Color.clear }
            } else {
                content.containerBackground(for: .widget) { bg() }
            }
        } else {
            if accessory {
                content
            } else {
                content.padding(16).background(bg())
            }
        }
    }
}

struct EntryView: View {
    let e: DayEntry
    var style: WStyle = .wash
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
        let t = e.data?.theme ?? Store.defaultTheme
        let dark = t.mode == "dark" || (t.mode != "light" && scheme == .dark)
        content(p)
            .modifier(WidgetBg(p: p, accessory: accessory, dark: dark))
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
                MediumView(e: e, p: p, style: style)
            case .systemLarge, .systemExtraLarge:
                LargeView(e: e, p: p, style: style)
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
        .description("Today's jobs at a glance, with a soft painted wash. Tap to open Today.")
        .supportedFamilies(families)
    }
}

// The same widget without the painted wash (just the app icon), for a cleaner look
struct TodaySimpleWidget: Widget {
    let kind = "MumBrainTodaySimple"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            EntryView(e: entry, style: .plain)
        }
        .configurationDisplayName("Today · Simple")
        .description("Today's jobs at a glance, clean and white. Tap to open Today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct AppWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TodaySimpleWidget()
    }
}
