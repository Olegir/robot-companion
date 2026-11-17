// Robot Companion — a tiny desktop robot for macOS
// Робот-компаньйон для робочого столу macOS
//
// Walks around, jumps on windows, builds blocks, waters a flower, drinks coffee,
// follows your cursor, likes being petted, reminds you to take breaks,
// wears seasonal costumes and runs simple commands (EN / UK).
// Гуляє, стрибає по вікнах, будує кубики, поливає квітку, п'є каву,
// стежить за курсором, любить погладжування, нагадує про перерву,
// вдягає сезонні костюми та виконує прості команди (EN / UK).
//
// Not affiliated with or endorsed by Anthropic. "Claude" is a trademark of Anthropic.
// Не пов'язаний з Anthropic і не схвалений нею. «Claude» — торгова марка Anthropic.
//
// License: MIT (see LICENSE)

import AppKit

enum Mood {
    case walk, idle, wave, sleep, build, rummage
    case water, coffee, ball, read, dance
    case jump, fall, love, remind
}

let buildDuration: Double = 9
let rummageDuration: Double = 7
let waterDuration: Double = 8

let viewW: CGFloat = 170
let viewH: CGFloat = 160
let groundY: CGFloat = 152          // де «підлога» у вікні робота
let feetOffset: CGFloat = viewH - groundY
let centerX: CGFloat = 85

extension NSColor {
    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }
    func mix(_ c: NSColor, _ f: CGFloat) -> NSColor { blended(withFraction: f, of: c) ?? self }
}

func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

// MARK: - Мова та ім'я / Language and name

// "uk" або "en". За замовчуванням береться мова системи.
var appLanguage: String = {
    if let saved = UserDefaults.standard.string(forKey: "language") { return saved }
    let first = Locale.preferredLanguages.first ?? "en"
    return first.hasPrefix("uk") ? "uk" : "en"
}()

func L(_ uk: String, _ en: String) -> String { appLanguage == "en" ? en : uk }

// Ім'я користувача зберігається лише локально на цьому Mac (UserDefaults)
var userName: String {
    UserDefaults.standard.string(forKey: "userName")?.trimmingCharacters(in: .whitespaces) ?? ""
}

func hello(_ emoji: String) -> String {
    if userName.isEmpty { return L("Привіт! ", "Hi! ") + emoji }
    return L("Привіт, \(userName)! ", "Hi, \(userName)! ") + emoji
}

// MARK: - Костюми

enum Costume: String, CaseIterable {
    case plain, autumn, winter, newYear, spring, summer, halloween, independence

    var title: String {
        switch self {
        case .plain: return L("Без костюма", "No costume")
        case .autumn: return L("Осінь 🍂", "Autumn 🍂")
        case .winter: return L("Зима ❄️", "Winter ❄️")
        case .newYear: return L("Новий рік 🎄", "New Year 🎄")
        case .spring: return L("Весна 🌸", "Spring 🌸")
        case .summer: return L("Літо 😎", "Summer 😎")
        case .halloween: return L("Хелловін 🎃", "Halloween 🎃")
        case .independence: return L("День Незалежності 💙💛", "Ukrainian Independence Day 💙💛")
        }
    }

    static func auto(for date: Date) -> Costume {
        let cal = Calendar.current
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        if (m == 12 && d >= 19) || (m == 1 && d <= 7) { return .newYear }
        if m == 8 && (d == 23 || d == 24) { return .independence }
        if m == 10 && d >= 25 { return .halloween }
        switch m {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        default: return .autumn
        }
    }

    var greeting: String {
        switch self {
        case .newYear: return L("З Новим роком! 🎄", "Happy New Year! 🎄")
        case .independence: return L("З Днем Незалежності! 💙💛", "Happy Independence Day! 💙💛")
        case .halloween: return L("Бу! 🎃 ", "Boo! 🎃 ") + hello("")
        case .winter: return hello("❄️")
        case .autumn: return hello("🍂")
        case .spring: return hello("🌸")
        case .summer: return hello("☀️")
        case .plain: return hello("👋")
        }
    }
}

let teal = NSColor.rgb(93, 214, 190)
let amber = NSColor.rgb(239, 159, 39)
let pink = NSColor.rgb(237, 120, 160)
let cubePalette: [NSColor] = [
    NSColor.rgb(93, 202, 165), NSColor.rgb(239, 159, 39),
    NSColor.rgb(127, 119, 221), NSColor.rgb(216, 90, 48), NSColor.rgb(55, 138, 221)
]

// MARK: - Малювання

final class RobotView: NSView {
    var accent = NSColor.rgb(216, 90, 48)
    var t: CGFloat = 0
    var moodT: Double = 0
    var moodDuration: Double = 1
    var facing: CGFloat = 1
    var mood: Mood = .idle
    var blink = false
    var isDragging = false
    var hovered = false
    var look = CGPoint.zero            // куди дивляться очі
    var bubble: String?
    var cubeColors: [NSColor] = [cubePalette[0], cubePalette[1], cubePalette[2]]
    var costume: Costume = .plain

    var onClick: (() -> Void)?
    var onDrop: (() -> Void)?
    var onDragStart: (() -> Void)?
    var menuProvider: (() -> NSMenu)?

    private var downLoc = NSPoint.zero
    private var startOrigin = NSPoint.zero
    private var dragged = false

    private let white1 = NSColor(white: 0.99, alpha: 1)
    private let white2 = NSColor(white: 0.78, alpha: 1)

    override var isFlipped: Bool { true }

    // MARK: Допоміжні функції

    private func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
    }
    private func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h))
    }
    private func grad(_ p: NSBezierPath, _ top: NSColor, _ bottom: NSColor) {
        NSGradient(starting: top, ending: bottom)?.draw(in: p, angle: 90)
    }
    private func fill(_ p: NSBezierPath, _ c: NSColor) { c.setFill(); p.fill() }
    private func stroke(_ p: NSBezierPath, _ c: NSColor, _ w: CGFloat) {
        c.setStroke()
        p.lineWidth = w
        p.lineCapStyle = .round
        p.stroke()
    }
    private func poly(_ pts: [NSPoint], _ c: NSColor) {
        let p = NSBezierPath()
        p.move(to: pts[0])
        for pt in pts.dropFirst() { p.line(to: pt) }
        p.close()
        c.setFill()
        p.fill()
        NSColor(white: 0, alpha: 0.15 * c.alphaComponent).setStroke()
        p.lineWidth = 0.5
        p.stroke()
    }
    private func spark(cx: CGFloat, cy: CGFloat, r: CGFloat, _ c: NSColor) {
        let p = NSBezierPath()
        for i in 0..<8 {
            let ang = CGFloat(i) * .pi / 4 - .pi / 2
            let rad = i % 2 == 0 ? r : r * 0.35
            let pt = NSPoint(x: cx + cos(ang) * rad, y: cy + sin(ang) * rad)
            if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
        }
        p.close()
        fill(p, c)
    }
    private func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ c: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: size), .foregroundColor: c]
        (s as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }
    private func arm(left: Bool, cx: CGFloat, ground: CGFloat, angle: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let a = NSAffineTransform()
        a.translateX(by: cx + (left ? -18 : 18), yBy: ground - 31)
        a.rotate(byDegrees: left ? angle : -angle)
        a.concat()
        grad(rrect(-4, -2, 8, 14, 4), white1, white2)
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Головне малювання

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()
        let cx = centerX
        let ground = groundY
        let px = cx + facing * 54

        drawParticles()

        switch mood {
        case .build: drawCubes(px: px, ground: ground)
        case .rummage: drawFolder(px: px, ground: ground)
        case .water: drawFlower(px: px, ground: ground)
        default: break
        }

        drawRobot(cx: cx, ground: ground)

        switch mood {
        case .rummage: drawPapers(px: px, ground: ground)
        case .water: drawWateringCan(cx: cx, ground: ground)
        case .ball: drawBall(cx: cx, ground: ground)
        case .sleep: text("z", cx + 16, ground - 84 - phase(3) * 8, 10, teal); text("Z", cx + 26, ground - 96 - phase(3) * 8, 10, teal)
        case .dance: drawNotes(cx: cx, ground: ground)
        case .love: drawHearts(cx: cx, ground: ground)
        default: break
        }

        if let b = bubble { drawBubble(b, cx: cx, bottom: ground - 100) }
    }

    private func phase(_ period: CGFloat) -> CGFloat { t.truncatingRemainder(dividingBy: period) / period }

    // MARK: Робот

    private func drawRobot(cx: CGFloat, ground: CGFloat) {
        let walking = mood == .walk && !isDragging
        let step: CGFloat = walking ? sin(t * 10) : 0
        var bob: CGFloat = walking ? -abs(step) * 2 : -sin(t * 2)
        var lean: CGFloat = 0
        switch mood {
        case .sleep: bob = 1.5
        case .rummage: lean = facing * 4; bob += 3 + sin(t * 8)
        case .dance: bob = -abs(sin(t * 6)) * 4
        case .love: bob = -abs(sin(t * 8)) * 3
        default: break
        }
        let buildingNow = mood == .build && moodT < buildDuration * 0.8
        let sipping = mood == .coffee && phase(3) > 0.66
        let flowerDone = mood == .water && moodT > waterDuration * 0.8
        let happy = hovered || [.wave, .dance, .love, .jump, .remind].contains(mood)
            || (mood == .build && !buildingNow) || flowerDone
        let surprised = mood == .fall
        let glow: CGFloat = mood == .sleep ? 0.25 : 0.6 + 0.4 * abs(sin(t * 3))

        // Тінь
        if mood != .jump && mood != .fall {
            fill(oval(cx - 22, ground - 5, 44, 7), NSColor(white: 0, alpha: 0.18))
        }

        NSGraphicsContext.saveGraphicsState()
        if mood == .dance {
            let r = NSAffineTransform()
            r.translateX(by: cx, yBy: ground)
            r.rotate(byDegrees: sin(t * 6) * 8)
            r.translateX(by: -cx, yBy: -ground)
            r.concat()
        }

        // Ніжки та ступні
        var lUp = max(0, step) * 3
        var rUp = max(0, -step) * 3
        if mood == .dance { lUp = max(0, sin(t * 6)) * 3; rUp = max(0, -sin(t * 6)) * 3 }
        let dark1 = NSColor(white: 0.38, alpha: 1)
        let dark2 = NSColor(white: 0.16, alpha: 1)
        grad(rrect(cx - 13, ground - 18 - lUp, 9, 12, 4), white1, white2)
        grad(rrect(cx + 4, ground - 18 - rUp, 9, 12, 4), white1, white2)
        grad(rrect(cx - 16, ground - 8 - lUp, 14, 6, 3), dark1, dark2)
        grad(rrect(cx + 2, ground - 8 - rUp, 14, 6, 3), dark1, dark2)

        let tr = NSAffineTransform()
        tr.translateX(by: lean, yBy: bob)
        tr.concat()

        // Тулуб
        grad(rrect(cx - 15, ground - 34, 30, 20, 9), white1, white2)
        fill(oval(cx - 3, ground - 28, 6, 6), (mood == .love ? pink : teal).withAlphaComponent(glow))

        // Руки
        var la: CGFloat = 6 + sin(t * 2) * 3
        var ra: CGFloat = 6 + sin(t * 2 + 1) * 3
        let facingLeft = facing < 0
        switch mood {
        case .walk: la = step * 18; ra = -step * 18
        case .wave, .remind: ra = 150 + sin(t * 12) * 25
        case .build:
            let h: CGFloat = buildingNow ? 40 + abs(sin(t * 8)) * 50 : 120
            if facingLeft { la = h } else { ra = h }
            if !buildingNow { la = 120; ra = 120 }
        case .water: if facingLeft { la = 70 } else { ra = 70 }
        case .coffee, .read: la = -35; ra = -35
        case .ball:
            let tap: CGFloat = 30 + max(0, sin(t * 4.2)) * 40
            if facingLeft { la = tap } else { ra = tap }
        case .dance: la = 120 + sin(t * 6) * 40; ra = 120 - sin(t * 6) * 40
        case .jump, .fall: la = 160; ra = 160
        case .love: la = 60 + sin(t * 10) * 15; ra = 60 - sin(t * 10) * 15
        case .sleep: la = 2; ra = 2
        default: break
        }
        arm(left: true, cx: cx, ground: ground, angle: la)
        arm(left: false, cx: cx, ground: ground, angle: ra)

        // Антена з іскоркою
        fill(rrect(cx - 1, ground - 86, 2, 11, 1), NSColor(white: 0.55, alpha: 1))
        spark(cx: cx, cy: ground - 90, r: 6, amber.withAlphaComponent(glow))

        // Вушка
        grad(oval(cx - 30, ground - 62, 7, 14), accent.mix(.white, 0.3), accent.mix(.black, 0.2))
        grad(oval(cx + 23, ground - 62, 7, 14), accent.mix(.white, 0.3), accent.mix(.black, 0.2))

        // Голова
        let head = rrect(cx - 25, ground - 76, 50, 42, 14)
        grad(head, NSColor(white: 1, alpha: 1), NSColor(white: 0.8, alpha: 1))
        NSColor(white: 0.68, alpha: 1).setStroke()
        head.lineWidth = 0.8
        head.stroke()
        fill(oval(cx - 18, ground - 75, 20, 5), NSColor(white: 1, alpha: 0.7))

        // Екран
        grad(rrect(cx - 19, ground - 70, 38, 30, 9), NSColor(white: 0.25, alpha: 1), NSColor(white: 0.04, alpha: 1))
        fill(rrect(cx - 16, ground - 68, 18, 5, 2.5), NSColor(white: 1, alpha: 0.10))

        // Очі
        let ex0 = clamp(look.x, -4, 4)
        let ey0 = clamp(look.y, -3, 3)
        for dx in [CGFloat(-11), CGFloat(2)] {
            let ex = cx + dx + ex0
            let ey = ground + ey0
            if mood == .sleep || blink || sipping {
                fill(rrect(ex, ey - 56, 9, 2.5, 1.2), teal)
            } else if surprised {
                fill(oval(ex - 0.5, ey - 63, 10, 12), teal.withAlphaComponent(0.25))
                stroke(oval(ex + 1, ey - 61, 7, 8), teal, 2)
            } else if happy {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: ex, y: ey - 53))
                p.curve(to: NSPoint(x: ex + 9, y: ey - 53),
                        controlPoint1: NSPoint(x: ex + 2, y: ey - 60),
                        controlPoint2: NSPoint(x: ex + 7, y: ey - 60))
                stroke(p, mood == .love ? pink : teal, 2.5)
            } else {
                fill(rrect(ex - 1, ey - 63, 11, 15, 5), teal.withAlphaComponent(0.22))
                fill(rrect(ex + 1, ey - 61.5, 7, 11, 3.5), teal)
                fill(rrect(ex + 2, ey - 60, 2, 3, 1), NSColor(white: 1, alpha: 0.7))
            }
        }

        // Рум'янець, коли наводиш курсор або гладиш
        if hovered || mood == .love {
            fill(oval(cx - 17, ground - 50, 7, 3.5), pink.withAlphaComponent(0.55))
            fill(oval(cx + 10, ground - 50, 7, 3.5), pink.withAlphaComponent(0.55))
        }

        // Рот
        let m = NSBezierPath()
        let mx = cx + ex0
        if surprised {
            stroke(oval(mx - 2.5, ground - 49, 5, 5), teal, 1.5)
        } else {
            m.move(to: NSPoint(x: mx - 4, y: ground - 47))
            if mood == .sleep {
                m.line(to: NSPoint(x: mx + 4, y: ground - 47))
            } else {
                let smile: CGFloat = happy ? 5 : 3
                m.curve(to: NSPoint(x: mx + 4, y: ground - 47),
                        controlPoint1: NSPoint(x: mx - 2, y: ground - 47 + smile),
                        controlPoint2: NSPoint(x: mx + 2, y: ground - 47 + smile))
            }
            stroke(m, teal, 1.5)
        }

        drawCostume(cx: cx, ground: ground)

        // Предмети в руках (перед тулубом)
        if mood == .coffee { drawMug(cx: cx, ground: ground, sipping: sipping) }
        if mood == .read { drawBook(cx: cx, ground: ground) }

        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: Костюми

    private func scarf(cx: CGFloat, ground: CGFloat, _ c1: NSColor, _ c2: NSColor) {
        let sway = sin(t * 3) * 1.5
        grad(rrect(cx + 5 + sway, ground - 34, 7, 14, 2.5), c1, c1.mix(.black, 0.2))
        fill(rrect(cx + 5 + sway, ground - 26, 7, 2, 1), c2)
        grad(rrect(cx - 17, ground - 38, 34, 7, 3.5), c1.mix(.white, 0.1), c1.mix(.black, 0.15))
        for i in 0..<4 {
            fill(rrect(cx - 13 + CGFloat(i) * 8, ground - 37, 2.5, 5, 1), c2.withAlphaComponent(0.8))
        }
    }

    private func drawCostume(cx: CGFloat, ground: CGFloat) {
        switch costume {
        case .plain:
            break

        case .autumn:
            scarf(cx: cx, ground: ground, NSColor.rgb(214, 110, 40), NSColor.rgb(250, 205, 125))
            // Берет
            grad(oval(cx - 25, ground - 83, 40, 13), NSColor.rgb(170, 50, 50), NSColor.rgb(120, 30, 30))
            fill(rrect(cx - 7, ground - 87, 3, 5, 1.5), NSColor.rgb(120, 30, 30))

        case .winter, .newYear:
            let festive = costume == .newYear
            let hat1 = festive ? NSColor.rgb(220, 50, 50) : NSColor.rgb(55, 138, 221)
            let hat2 = festive ? NSColor.rgb(160, 25, 30) : NSColor.rgb(24, 95, 165)
            scarf(cx: cx, ground: ground, festive ? NSColor.rgb(220, 50, 50) : NSColor.rgb(216, 90, 48), NSColor(white: 1, alpha: 1))
            if festive {
                // Святковий ковпак, що звисає вбік
                let cap = NSBezierPath()
                cap.move(to: NSPoint(x: cx - 23, y: ground - 71))
                cap.curve(to: NSPoint(x: cx + 30, y: ground - 84),
                          controlPoint1: NSPoint(x: cx - 18, y: ground - 96),
                          controlPoint2: NSPoint(x: cx + 14, y: ground - 100))
                cap.line(to: NSPoint(x: cx + 23, y: ground - 71))
                cap.close()
                grad(cap, hat1, hat2)
                fill(rrect(cx - 26, ground - 75, 52, 7, 3.5), NSColor(white: 0.97, alpha: 1))
                fill(oval(cx + 26, ground - 89, 9, 9), NSColor(white: 0.97, alpha: 1))
            } else {
                // В'язана шапка з помпоном
                let dome = NSBezierPath()
                dome.move(to: NSPoint(x: cx - 24, y: ground - 71))
                dome.curve(to: NSPoint(x: cx + 24, y: ground - 71),
                           controlPoint1: NSPoint(x: cx - 22, y: ground - 93),
                           controlPoint2: NSPoint(x: cx + 22, y: ground - 93))
                dome.close()
                grad(dome, hat1, hat2)
                for i in 0..<5 {
                    fill(rrect(cx - 15 + CGFloat(i) * 7, ground - 85 + abs(CGFloat(i) - 2) * 2, 1.5, 12, 0.75), hat2.withAlphaComponent(0.6))
                }
                grad(rrect(cx - 26, ground - 76, 52, 8, 4), NSColor(white: 1, alpha: 1), NSColor(white: 0.85, alpha: 1))
                fill(oval(cx - 6, ground - 96, 12, 12), NSColor(white: 0.97, alpha: 1))
            }

        case .spring:
            // Віночок із квіточок
            let colors = [pink, NSColor.rgb(250, 205, 125), NSColor.rgb(175, 169, 236), pink, NSColor(white: 1, alpha: 1)]
            for i in 0..<5 {
                let fx = cx - 18 + CGFloat(i) * 9
                let fy = ground - 77 - (i == 2 ? 2 : 0)
                for k in 0..<5 {
                    let a = CGFloat(k) * 2 * .pi / 5
                    fill(oval(fx + cos(a) * 2.5 - 2, fy + sin(a) * 2.5 - 2, 4, 4), colors[i])
                }
                fill(oval(fx - 1.5, fy - 1.5, 3, 3), amber)
            }

        case .summer:
            // Сонцезахисні окуляри, підняті на лоб
            let frame = NSColor(white: 0.12, alpha: 1)
            fill(rrect(cx - 18, ground - 81, 15, 9, 4), frame)
            fill(rrect(cx + 3, ground - 81, 15, 9, 4), frame)
            fill(rrect(cx - 3, ground - 78, 6, 2, 1), frame)
            fill(rrect(cx - 15, ground - 79.5, 5, 2, 1), NSColor(white: 1, alpha: 0.35))
            fill(rrect(cx + 6, ground - 79.5, 5, 2, 1), NSColor(white: 1, alpha: 0.35))

        case .halloween:
            // Капелюх відьмочки
            let purple = NSColor.rgb(83, 74, 183)
            let cone = NSBezierPath()
            cone.move(to: NSPoint(x: cx - 15, y: ground - 76))
            cone.line(to: NSPoint(x: cx + 6, y: ground - 104))
            cone.line(to: NSPoint(x: cx + 15, y: ground - 76))
            cone.close()
            grad(cone, purple.mix(.white, 0.15), purple.mix(.black, 0.3))
            fill(oval(cx - 31, ground - 80, 62, 9), purple.mix(.black, 0.35))
            fill(rrect(cx - 14, ground - 82, 28, 4, 1), amber)

        case .independence:
            // Прапорець на антені
            fill(rrect(cx + 1, ground - 96, 16, 5, 1), NSColor.rgb(0, 91, 187))
            fill(rrect(cx + 1, ground - 91, 16, 5, 1), NSColor.rgb(255, 213, 0))
            // Синьо-жовтий шарфик
            scarf(cx: cx, ground: ground, NSColor.rgb(0, 91, 187), NSColor.rgb(255, 213, 0))
        }
    }

    // Листя, сніжинки, пелюстки — падають хвилями, щоб не набридало
    private func drawParticles() {
        guard costume != .plain, costume != .summer else { return }
        let cycle = t.truncatingRemainder(dividingBy: 60)
        guard cycle < 25 else { return }
        let fadeIn = min(1, cycle / 2)
        let fadeOut = min(1, (25 - cycle) / 2)
        let alpha = min(fadeIn, fadeOut)
        for i in 0..<6 {
            let fi = CGFloat(i)
            let speed: CGFloat = costume == .autumn || costume == .halloween ? 14 : 10
            let y = (t * speed + fi * 29).truncatingRemainder(dividingBy: viewH + 10) - 10
            let x = (fi * 31 + 12).truncatingRemainder(dividingBy: viewW - 10) + sin(t * 1.3 + fi) * 8
            switch costume {
            case .autumn, .halloween:
                let colors = [NSColor.rgb(214, 110, 40), NSColor.rgb(239, 159, 39), NSColor.rgb(170, 50, 50)]
                NSGraphicsContext.saveGraphicsState()
                let r = NSAffineTransform()
                r.translateX(by: x, yBy: y)
                r.rotate(byDegrees: sin(t * 2 + fi) * 50)
                r.concat()
                fill(oval(-4, -2, 8, 4), colors[i % 3].withAlphaComponent(alpha))
                NSGraphicsContext.restoreGraphicsState()
            case .winter, .newYear:
                let s: CGFloat = 2.5 + CGFloat(i % 3)
                let flake = oval(x - s / 2, y - s / 2, s, s)
                fill(flake, NSColor.rgb(225, 238, 255, alpha))
                NSColor.rgb(150, 185, 230, alpha * 0.8).setStroke()
                flake.lineWidth = 0.6
                flake.stroke()
            case .spring:
                fill(oval(x - 2.5, y - 1.5, 5, 3), pink.withAlphaComponent(alpha * 0.8))
            case .independence:
                fill(oval(x - 2, y - 2, 4, 4), (i % 2 == 0 ? NSColor.rgb(0, 91, 187) : NSColor.rgb(255, 213, 0)).withAlphaComponent(alpha))
            default:
                break
            }
        }
    }

    // MARK: Кубики

    private func cube(_ x: CGFloat, _ y: CGFloat, _ base: NSColor, _ alpha: CGFloat) {
        let w: CGFloat = 9, h: CGFloat = 10
        let b = NSPoint(x: x, y: y)
        let lb = NSPoint(x: x - w, y: y - w * 0.5)
        let rb = NSPoint(x: x + w, y: y - w * 0.5)
        let tf = NSPoint(x: x, y: y - h)
        let tl = NSPoint(x: x - w, y: y - h - w * 0.5)
        let trp = NSPoint(x: x + w, y: y - h - w * 0.5)
        let tb = NSPoint(x: x, y: y - h - w)
        poly([b, lb, tl, tf], base.withAlphaComponent(alpha))
        poly([b, rb, trp, tf], base.mix(.black, 0.25).withAlphaComponent(alpha))
        poly([tf, tl, tb, trp], base.mix(.white, 0.35).withAlphaComponent(alpha))
    }

    private func drawCubes(px: CGFloat, ground: CGFloat) {
        let ph = buildDuration / 4
        var fade: CGFloat = 1
        if moodT > buildDuration - 0.8 { fade = CGFloat(max(0, (buildDuration - moodT) / 0.8)) }
        fill(oval(px - 13, ground - 6, 26, 6), NSColor(white: 0, alpha: 0.12 * fade))
        for i in 0..<3 {
            let start = Double(i) * ph + 0.3
            if moodT < start { continue }
            let k = CGFloat(min(1, (moodT - start) / 0.5))
            let y = ground - 2 - CGFloat(i) * 10 - (1 - k * k) * 30
            cube(px, y, cubeColors[i % cubeColors.count], min(1, k * 1.5) * fade)
        }
    }

    // MARK: Папка

    private func drawFolder(px: CGFloat, ground: CGFloat) {
        let x = px - 17, y = ground - 24
        let back = NSColor.rgb(186, 117, 23)
        fill(oval(px - 19, ground - 5, 38, 6), NSColor(white: 0, alpha: 0.12))
        fill(rrect(x, y - 4, 14, 6, 2), back)
        fill(rrect(x, y, 34, 22, 3), back)
        fill(rrect(x + 5, y - 3 - abs(sin(t * 6)) * 2, 24, 14, 1), NSColor(white: 0.97, alpha: 1))
        let open = 3 + abs(sin(t * 4)) * 3
        grad(rrect(x, y + 4 + open, 34, 18 - open, 3), NSColor.rgb(250, 205, 125), amber)
    }

    private func drawPapers(px: CGFloat, ground: CGFloat) {
        for k in 0..<2 {
            let ph = CGFloat((moodT + Double(k) * 0.45).truncatingRemainder(dividingBy: 0.9) / 0.9)
            let x = px + facing * ph * 22
            let y = ground - 28 - sin(ph * .pi) * 28
            let a = 1 - ph
            let paper = rrect(x - 3.5, y, 7, 9, 1)
            fill(paper, NSColor(white: 1, alpha: a))
            NSColor(white: 0.6, alpha: a).setStroke()
            paper.lineWidth = 0.5
            paper.stroke()
            fill(rrect(x - 2, y + 3, 4, 0.8, 0.4), NSColor(white: 0.6, alpha: a))
            fill(rrect(x - 2, y + 5, 4, 0.8, 0.4), NSColor(white: 0.6, alpha: a))
        }
    }

    // MARK: Квітка та лійка

    private func drawFlower(px: CGFloat, ground: CGFloat) {
        let grow = CGFloat(min(1, moodT / (waterDuration * 0.8)))
        let stemH = 8 + grow * 20
        fill(oval(px - 12, ground - 5, 24, 6), NSColor(white: 0, alpha: 0.12))
        // Стебло і листочки
        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: px, y: ground - 14))
        stem.curve(to: NSPoint(x: px, y: ground - 14 - stemH),
                   controlPoint1: NSPoint(x: px - 3, y: ground - 14 - stemH * 0.4),
                   controlPoint2: NSPoint(x: px + 3, y: ground - 14 - stemH * 0.7))
        stroke(stem, NSColor.rgb(99, 153, 34), 2)
        let leafY = ground - 16 - stemH * 0.45
        fill(oval(px - 9, leafY - 2, 8, 4), NSColor.rgb(120, 180, 50))
        fill(oval(px + 1, leafY - 6, 8, 4), NSColor.rgb(120, 180, 50))
        // Квітка
        let fy = ground - 14 - stemH
        let pr = 2.5 + grow * 2.5
        for i in 0..<5 {
            let a = CGFloat(i) * 2 * .pi / 5 + t * 0.5
            fill(oval(px + cos(a) * pr - pr, fy + sin(a) * pr - pr, pr * 2, pr * 2), pink)
        }
        fill(oval(px - pr * 0.7, fy - pr * 0.7, pr * 1.4, pr * 1.4), amber)
        // Горщик
        let pot = NSBezierPath()
        pot.move(to: NSPoint(x: px - 10, y: ground - 15))
        pot.line(to: NSPoint(x: px + 10, y: ground - 15))
        pot.line(to: NSPoint(x: px + 7, y: ground - 1))
        pot.line(to: NSPoint(x: px - 7, y: ground - 1))
        pot.close()
        grad(pot, NSColor.rgb(226, 120, 80), NSColor.rgb(160, 70, 40))
        fill(rrect(px - 11, ground - 17, 22, 4, 1.5), NSColor.rgb(200, 95, 60))
    }

    private func drawWateringCan(cx: CGFloat, ground: CGFloat) {
        guard moodT < waterDuration * 0.8 else { return }
        let hx = cx + facing * 30
        let hy = ground - 26
        // Корпус лійки
        grad(rrect(hx - 7, hy - 2, 14, 11, 3), NSColor.rgb(133, 183, 235), NSColor.rgb(55, 120, 200))
        let spout = NSBezierPath()
        spout.move(to: NSPoint(x: hx + facing * 6, y: hy + 6))
        spout.line(to: NSPoint(x: hx + facing * 16, y: hy - 3))
        stroke(spout, NSColor.rgb(55, 120, 200), 2.5)
        // Краплі
        for k in 0..<3 {
            let ph = CGFloat((moodT + Double(k) * 0.25).truncatingRemainder(dividingBy: 0.75) / 0.75)
            let dx = hx + facing * (17 + ph * 8)
            let dy = hy - 2 + ph * ph * 22
            fill(oval(dx - 1.2, dy, 2.4, 3.5), NSColor.rgb(90, 160, 230).withAlphaComponent(1 - ph * 0.5))
        }
    }

    // MARK: Кава, книжка, м'ячик

    private func drawMug(cx: CGFloat, ground: CGFloat, sipping: Bool) {
        let y: CGFloat = sipping ? ground - 42 : ground - 31
        let x = cx - 6
        stroke(oval(x + 9, y + 3, 7, 7), NSColor(white: 0.85, alpha: 1), 2)
        grad(rrect(x, y, 12, 12, 3), NSColor(white: 1, alpha: 1), NSColor(white: 0.8, alpha: 1))
        fill(rrect(x, y + 4, 12, 3, 0), accent.withAlphaComponent(0.8))
        if !sipping {
            for k in 0..<2 {
                let ph = CGFloat((Double(t) + Double(k) * 0.6).truncatingRemainder(dividingBy: 1.2) / 1.2)
                let s = NSBezierPath()
                let sx = x + 4 + CGFloat(k) * 4
                s.move(to: NSPoint(x: sx, y: y - 2 - ph * 6))
                s.curve(to: NSPoint(x: sx, y: y - 10 - ph * 6),
                        controlPoint1: NSPoint(x: sx + 3, y: y - 5 - ph * 6),
                        controlPoint2: NSPoint(x: sx - 3, y: y - 7 - ph * 6))
                stroke(s, NSColor(white: 0.7, alpha: 0.7 * (1 - ph)), 1.2)
            }
        }
    }

    private func drawBook(cx: CGFloat, ground: CGFloat) {
        let y = ground - 36
        fill(rrect(cx - 15, y - 1, 30, 17, 2), NSColor.rgb(127, 119, 221))
        fill(rrect(cx - 13, y, 12.5, 15, 1), NSColor(white: 0.98, alpha: 1))
        fill(rrect(cx + 0.5, y, 12.5, 15, 1), NSColor(white: 0.95, alpha: 1))
        for i in 0..<4 {
            let ly = y + 3 + CGFloat(i) * 3
            fill(rrect(cx - 11, ly, 8.5, 0.8, 0.4), NSColor(white: 0.7, alpha: 1))
            fill(rrect(cx + 2.5, ly, 8.5, 0.8, 0.4), NSColor(white: 0.7, alpha: 1))
        }
        // Перегортання сторінки
        let p = phase(3.5)
        if p > 0.85 {
            let k = (p - 0.85) / 0.15
            let w = 12.5 * (1 - 2 * abs(k - 0.5))
            let x = k < 0.5 ? cx + 0.5 : cx - w
            fill(rrect(x, y, max(1, w), 15, 1), NSColor(white: 1, alpha: 1))
        }
    }

    private func drawBall(cx: CGFloat, ground: CGFloat) {
        let ph = t * 4.2
        let dist = 30 + abs(sin(ph / 2)) * 26
        let bx = cx + facing * dist
        let by = ground - 7 - abs(sin(ph)) * 26
        fill(oval(bx - 6, ground - 3, 12, 4), NSColor(white: 0, alpha: 0.12))
        grad(oval(bx - 7, by - 7, 14, 14), NSColor.rgb(240, 110, 90), NSColor.rgb(190, 50, 40))
        let stripe = NSBezierPath()
        stripe.move(to: NSPoint(x: bx - 7, y: by))
        stripe.curve(to: NSPoint(x: bx + 7, y: by), controlPoint1: NSPoint(x: bx - 3, y: by + 4), controlPoint2: NSPoint(x: bx + 3, y: by + 4))
        stroke(stripe, NSColor(white: 1, alpha: 0.9), 1.5)
        fill(oval(bx - 4, by - 5, 4, 3), NSColor(white: 1, alpha: 0.6))
    }

    // MARK: Ноти, сердечка, бульбашка

    private func drawNotes(cx: CGFloat, ground: CGFloat) {
        let notes = ["♪", "♫"]
        for k in 0..<2 {
            let ph = CGFloat((Double(t) + Double(k) * 0.9).truncatingRemainder(dividingBy: 1.8) / 1.8)
            let x = cx + (k == 0 ? -34 : 24) + sin(ph * 6) * 3
            text(notes[k], x, ground - 70 - ph * 25, 13, (k == 0 ? teal : amber).withAlphaComponent(1 - ph))
        }
    }

    private func drawHearts(cx: CGFloat, ground: CGFloat) {
        for k in 0..<3 {
            let ph = CGFloat((Double(t) + Double(k) * 0.5).truncatingRemainder(dividingBy: 1.5) / 1.5)
            let x = cx - 26 + CGFloat(k) * 22 + sin(ph * 5 + CGFloat(k)) * 4
            text("♥", x, ground - 86 - ph * 22, 12, pink.withAlphaComponent(1 - ph))
        }
    }

    private func drawBubble(_ s: String, cx: CGFloat, bottom: CGFloat) {
        let lines = s.components(separatedBy: "\n")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor(white: 0.15, alpha: 1)
        ]
        let widths = lines.map { ($0 as NSString).size(withAttributes: attrs).width }
        let w = min(viewW - 6, (widths.max() ?? 20) + 14)
        let lineH: CGFloat = 14
        let h = CGFloat(lines.count) * lineH + 8
        let x = clamp(cx - w / 2, 3, viewW - w - 3)
        let y = bottom - h
        let box = rrect(x, y, w, h, 8)
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: cx - 5, y: bottom - 0.5))
        tail.line(to: NSPoint(x: cx, y: bottom + 6))
        tail.line(to: NSPoint(x: cx + 5, y: bottom - 0.5))
        tail.close()
        fill(box, NSColor(white: 1, alpha: 0.97))
        fill(tail, NSColor(white: 1, alpha: 0.97))
        NSColor(white: 0.75, alpha: 1).setStroke()
        box.lineWidth = 0.6
        box.stroke()
        for (i, line) in lines.enumerated() {
            let lw = widths[i]
            (line as NSString).draw(at: NSPoint(x: x + (w - lw) / 2, y: y + 4 + CGFloat(i) * lineH), withAttributes: attrs)
        }
    }

    // MARK: Мишка

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        downLoc = NSEvent.mouseLocation
        startOrigin = window?.frame.origin ?? .zero
        dragged = false
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        let dx = p.x - downLoc.x
        let dy = p.y - downLoc.y
        if !dragged && abs(dx) + abs(dy) > 3 { dragged = true; onDragStart?() }
        if dragged { window?.setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)) }
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if dragged { onDrop?() } else { onClick?() }
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = menuProvider?() { NSMenu.popUpContextMenu(menu, with: event, for: self) }
    }
}

// MARK: - Вікна інших програм

struct Win {
    let id: Int
    let rect: NSRect   // у координатах Cocoa (0 — внизу екрана)
}

func fetchWindows() -> [Win] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
        return []
    }
    let primaryH = NSScreen.screens.first?.frame.height ?? 0
    let myPid = Int(ProcessInfo.processInfo.processIdentifier)
    var out: [Win] = []
    for w in list {
        guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
              let pid = w[kCGWindowOwnerPID as String] as? Int, pid != myPid,
              let num = w[kCGWindowNumber as String] as? Int,
              let bd = w[kCGWindowBounds as String] as? NSDictionary,
              let b = CGRect(dictionaryRepresentation: bd as CFDictionary) else { continue }
        if let a = w[kCGWindowAlpha as String] as? Double, a < 0.1 { continue }
        if b.width < 220 || b.height < 120 { continue }
        out.append(Win(id: num, rect: NSRect(x: b.minX, y: primaryH - b.maxY, width: b.width, height: b.height)))
    }
    return out
}

// MARK: - Поведінка

enum Motion { case grounded, falling, jumping }

final class Controller: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var view: RobotView!
    var timer: Timer?
    var frameCount = 0

    // Настрій
    var moodStart = Date()
    var moodUntil = Date()
    var nextBlink = Date().addingTimeInterval(2)
    var blinkUntil = Date.distantPast
    var forcedSleep = false

    // Рух
    var motion = Motion.grounded
    var floorID: Int?                 // nil — низ екрана
    var floorRect = NSRect.zero
    var windows: [Win] = []
    var vy: CGFloat = 0
    var jumpFrom = NSPoint.zero
    var jumpTo = NSPoint.zero
    var jumpStart = Date()
    let jumpDuration: Double = 0.9
    var jumpTargetID: Int?
    var jumpTargetRect = NSRect.zero
    let speed: CGFloat = 1.0

    // Реакція на мишку
    var lastMouse = NSPoint.zero
    var petAmount: CGFloat = 0
    var hoverTime: Double = 0

    // Бульбашки та нагадування
    var bubbleText: String?
    var bubbleUntil = Date.distantPast
    var nextPhraseAt = Date().addingTimeInterval(90)
    var nextBreak = Date()
    var breakMinutes: Int {
        get { UserDefaults.standard.object(forKey: "breakMinutes") as? Int ?? 50 }
        set { UserDefaults.standard.set(newValue, forKey: "breakMinutes") }
    }

    // Костюм: "auto" або назва конкретного костюма
    var costumeSetting: String {
        get { UserDefaults.standard.string(forKey: "costume") ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: "costume") }
    }
    func applyCostume() {
        view.costume = costumeSetting == "auto" ? Costume.auto(for: Date()) : (Costume(rawValue: costumeSetting) ?? Costume.plain)
    }

    // Автозапуск / Autostart
    let agentLabel = "local.robotcompanion"
    var launchAgentURL: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/Library/LaunchAgents/\(agentLabel).plist")
    }
    var autostartOn: Bool { FileManager.default.fileExists(atPath: launchAgentURL.path) }

    // Команди та таймер
    var panel: KeyPanel?
    var commandField: NSTextField?
    var timerEnd: Date?

    var idlePhrases: [String] {
        appLanguage == "en"
            ? ["Beep-boop!", "I'm here if you need me 🙂", "Have a great day!", "What are we building today?",
               "Pet me with the mouse 🙂", "Click me and give me a command 🙂"]
            : ["Біп-буп!", "Я тут, якщо що 🙂", "Гарного дня!", "Що будуємо сьогодні?",
               "Погладь мене мишкою 🙂", "Клацни і дай мені команду 🙂"]
    }
    var listeningText: String { L("Слухаю! 🙂", "Listening! 🙂") }

    // MARK: Запуск

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = screenFrame()
        let rect = NSRect(x: screen.midX - viewW / 2, y: screen.minY - feetOffset, width: viewW, height: viewH)

        window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        view = RobotView(frame: NSRect(x: 0, y: 0, width: viewW, height: viewH))
        view.onClick = { [weak self] in self?.clicked() }
        view.onDrop = { [weak self] in self?.startFalling() }
        view.onDragStart = { [weak self] in self?.motion = .grounded }
        view.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }
        window.contentView = view
        window.orderFrontRegardless()

        nextBreak = Date().addingTimeInterval(Double(max(1, breakMinutes)) * 60)
        windows = fetchWindows()
        applyCostume()
        if let data = UserDefaults.standard.data(forKey: "accent"),
           let c = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            view.accent = c
        }
        setMood(.wave, seconds: 2)

        // Прибираємо автозапуск зі старою назвою, якщо він лишився з попередньої версії
        let agentsDir = NSHomeDirectory() + "/Library/LaunchAgents"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: agentsDir)) ?? []
        for file in files where file.hasSuffix(".robotcompanion.plist") && file != "\(agentLabel).plist" {
            try? FileManager.default.removeItem(atPath: agentsDir + "/" + file)
            setAutostart(true)
        }

        // Автозапуск: вмикаємо при першому запуску, далі оновлюємо шлях до програми
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "autostartInitialized") {
            // Перший запуск: питаємо дозволу, нічого не вмикаємо без згоди
            defaults.set(true, forKey: "autostartInitialized")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.askAutostart() }
        } else {
            if autostartOn { setAutostart(true) }
            say(view.costume.greeting, 3.5)
        }
        timer = Timer.scheduledTimer(timeInterval: 1.0 / 30.0, target: self,
                                     selector: #selector(tick), userInfo: nil, repeats: true)
    }

    // MARK: Допоміжне

    func screenFrame() -> NSRect {
        (window?.screen ?? NSScreen.main ?? NSScreen.screens[0]).visibleFrame
    }
    var feet: NSPoint {
        NSPoint(x: window.frame.minX + centerX, y: window.frame.minY + feetOffset)
    }
    func setFeet(_ p: NSPoint) {
        window.setFrameOrigin(NSPoint(x: p.x - centerX, y: p.y - feetOffset))
    }
    func floorRange() -> (CGFloat, CGFloat) {
        let s = screenFrame()
        var lo = s.minX + 30, hi = s.maxX - 30
        if floorID != nil {
            lo = max(lo, floorRect.minX + 15)
            hi = min(hi, floorRect.maxX - 15)
        }
        return (lo, max(lo, hi))
    }
    func usableTop(_ r: NSRect) -> Bool { r.maxY < screenFrame().maxY - 70 }

    func say(_ s: String, _ seconds: Double) {
        bubbleText = s
        bubbleUntil = Date().addingTimeInterval(seconds)
    }

    func setMood(_ mood: Mood, seconds: Double) {
        view.mood = mood
        view.moodDuration = seconds
        moodStart = Date()
        moodUntil = moodStart.addingTimeInterval(seconds)
        if [.walk, .build, .rummage, .water, .ball].contains(mood) {
            view.facing = Bool.random() ? 1 : -1
        }
        if mood == .build {
            view.cubeColors = (0..<3).map { _ in cubePalette.randomElement() ?? teal }
        }
        // Біля краю повертаємося до центру, щоб предмети було видно
        if [.build, .rummage, .water, .ball].contains(mood) {
            let (lo, hi) = floorRange()
            if feet.x < lo + 50 { view.facing = 1 }
            if feet.x > hi - 50 { view.facing = -1 }
        }
        if Double.random(in: 0..<1) < 0.4 {
            let phrase: String? = {
                switch mood {
                case .build: return L("Будую вежу! 🧱", "Building a tower! 🧱")
                case .rummage: return L("Що ж тут у нас...", "What do we have here...")
                case .water: return L("Рости, квіточко! 🌱", "Grow, little flower! 🌱")
                case .coffee: return L("Ммм, кава ☕", "Mmm, coffee ☕")
                case .ball: return L("Лови!", "Catch!")
                case .read: return L("Цікава книжка 📖", "Great book 📖")
                case .dance: return L("Танцюємо! 🎶", "Let's dance! 🎶")
                default: return nil
                }
            }()
            if let p = phrase { say(p, 3) }
        }
    }

    func pickMood() {
        if forcedSleep { setMood(.sleep, seconds: 3600); return }
        let options: [(Double, () -> Void)] = [
            (0.26, { self.setMood(.walk, seconds: Double.random(in: 3...8)) }),
            (0.08, { self.setMood(.idle, seconds: Double.random(in: 2...4)) }),
            (0.04, { self.setMood(.wave, seconds: 2) }),
            (0.06, { self.setMood(.sleep, seconds: Double.random(in: 6...10)) }),
            (0.08, { self.setMood(.build, seconds: buildDuration) }),
            (0.08, { self.setMood(.rummage, seconds: rummageDuration) }),
            (0.07, { self.setMood(.water, seconds: waterDuration) }),
            (0.07, { self.setMood(.coffee, seconds: 9) }),
            (0.07, { self.setMood(.ball, seconds: 8) }),
            (0.06, { self.setMood(.read, seconds: 10) }),
            (0.05, { self.setMood(.dance, seconds: 7) }),
            (0.08, { if !self.tryJump() { self.setMood(.walk, seconds: 5) } })
        ]
        var r = Double.random(in: 0..<options.reduce(0) { $0 + $1.0 })
        for (w, action) in options {
            if r < w { action(); return }
            r -= w
        }
        setMood(.idle, seconds: 2)
    }

    // MARK: Головний цикл

    @objc func tick() {
        let now = Date()
        let dt = 1.0 / 30.0
        frameCount += 1
        view.t += CGFloat(dt)
        view.moodT = now.timeIntervalSince(moodStart)

        if frameCount % 1800 == 0 { applyCostume() }   // раз на хвилину перевіряємо дату
        if frameCount % 15 == 0 {
            windows = fetchWindows()
            if motion == .grounded && !view.isDragging { checkFloor() }
        }

        // Моргання
        if now >= nextBlink {
            blinkUntil = now.addingTimeInterval(0.15)
            nextBlink = now.addingTimeInterval(Double.random(in: 2.5...5))
        }
        view.blink = now < blinkUntil

        updateMouse(dt: dt)
        updateReminders(now)

        if !view.isDragging {
            switch motion {
            case .jumping: stepJump(now)
            case .falling: stepFall()
            case .grounded:
                if now >= moodUntil { pickMood() }
                if view.mood == .walk { stepWalk() }
            }
        }

        // Що показати в бульбашці
        if now < bubbleUntil, let b = bubbleText {
            view.bubble = b
        } else if view.hovered && hoverTime > 0.8 {
            if let end = timerEnd {
                let left = max(0, Int(end.timeIntervalSince(now)))
                view.bubble = String(format: "⏳ %d:%02d", left / 60, left % 60)
            } else {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                view.bubble = "🕒 " + f.string(from: now)
            }
        } else {
            view.bubble = nil
        }

        view.needsDisplay = true
    }

    // MARK: Мишка: погляд, наведення, погладжування

    func updateMouse(dt: Double) {
        let m = NSEvent.mouseLocation
        let o = window.frame.origin
        let robotRect = NSRect(x: o.x + centerX - 30, y: o.y + feetOffset, width: 60, height: 98)
        let wasHovered = view.hovered
        view.hovered = robotRect.contains(m) && !view.isDragging

        if view.hovered {
            hoverTime += dt
            let d = hypot(m.x - lastMouse.x, m.y - lastMouse.y)
            if d > 0.5 { petAmount += d }
        } else {
            hoverTime = 0
            petAmount = max(0, petAmount - 3)
        }
        if wasHovered != view.hovered && view.hovered && view.mood == .sleep && !forcedSleep {
            setMood(.idle, seconds: 2)   // прокидається, коли підносиш курсор
        }
        lastMouse = m

        if petAmount > 260 && motion == .grounded {
            petAmount = 0
            setMood(.love, seconds: 2.5)
            say([L("Мур-біп! ♥", "Purr-beep! ♥"), L("Хі-хі, лоскотно!", "Hee-hee, that tickles!"), L("Я тебе теж люблю 🙂", "Love you too 🙂")].randomElement() ?? "♥", 2.5)
        }

        // Очі стежать за курсором
        let head = NSPoint(x: o.x + centerX, y: o.y + feetOffset + 57)
        let dx = m.x - head.x
        let dy = m.y - head.y
        switch view.mood {
        case .read: view.look = CGPoint(x: 0, y: 3)
        case .rummage: view.look = CGPoint(x: view.facing * 4, y: 1)
        case .water, .build, .ball: view.look = CGPoint(x: view.facing * 3, y: 1)
        default:
            if hypot(dx, dy) < 450 {
                view.look = CGPoint(x: clamp(dx / 25, -4, 4), y: clamp(-dy / 25, -3, 3))
            } else {
                view.look = CGPoint(x: view.facing * 2, y: 0)
            }
        }
    }

    // MARK: Нагадування та репліки

    func updateReminders(_ now: Date) {
        if let end = timerEnd, now >= end {
            timerEnd = nil
            say(L("⏰ Таймер! Час вийшов", "⏰ Timer! Time is up"), 10)
            NSSound(named: "Glass")?.play()
            if motion == .grounded { forcedSleep = false; setMood(.remind, seconds: 10) }
        }
        if breakMinutes > 0 && now >= nextBreak {
            nextBreak = now.addingTimeInterval(Double(breakMinutes) * 60)
            say(L("Час на перерву!\nПотягнись і попий води 🙂", "Time for a break!\nStretch and drink some water 🙂"), 15)
            if motion == .grounded {
                forcedSleep = false
                setMood(.remind, seconds: 15)
            }
        }
        if now >= nextPhraseAt {
            nextPhraseAt = now.addingTimeInterval(Double.random(in: 120...300))
            if now >= bubbleUntil && view.mood != .sleep {
                say(idlePhrases.randomElement() ?? L("Біп!", "Beep!"), 3.5)
            }
        }
    }

    // MARK: Ходьба, стрибки, падіння

    func stepWalk() {
        var f = feet
        f.x += speed * view.facing
        let (lo, hi) = floorRange()
        if f.x > hi || f.x < lo {
            if floorID != nil && Bool.random() {
                f.x += view.facing * 25    // крок за край вікна
                setFeet(f)
                startFalling()
                return
            }
            view.facing *= -1
            f.x = clamp(f.x, lo, hi)
        }
        setFeet(f)
    }

    func checkFloor() {
        guard let id = floorID else {
            let s = screenFrame()
            if abs(feet.y - s.minY) > 1 { startFalling() }
            return
        }
        guard let w = windows.first(where: { $0.id == id }), usableTop(w.rect) else {
            startFalling()
            return
        }
        if w.rect != floorRect {
            // Вікно посунули: їдемо разом із ним
            let dx = w.rect.minX - floorRect.minX
            floorRect = w.rect
            var f = feet
            f.x += dx
            f.y = w.rect.maxY
            setFeet(f)
            if f.x < w.rect.minX + 5 || f.x > w.rect.maxX - 5 { startFalling() }
        }
    }

    func startFalling() {
        motion = .falling
        vy = 0
        floorID = nil
        view.mood = .fall
        moodStart = Date()
    }

    func stepFall() {
        vy -= 0.9
        let old = feet
        var ny = old.y + vy
        let s = screenFrame()
        var landed = false
        // Шукаємо найвищу поверхню під ногами
        var best: Win?
        for w in windows where w.rect.minX + 5 <= old.x && old.x <= w.rect.maxX - 5
            && w.rect.maxY <= old.y && w.rect.maxY >= ny && usableTop(w.rect) {
            if best == nil || w.rect.maxY > best!.rect.maxY { best = w }
        }
        if let w = best {
            ny = w.rect.maxY
            floorID = w.id
            floorRect = w.rect
            landed = true
        } else if ny <= s.minY {
            ny = s.minY
            floorID = nil
            landed = true
        }
        let x = clamp(old.x, s.minX + 30, s.maxX - 30)
        setFeet(NSPoint(x: x, y: ny))
        if landed {
            motion = .grounded
            vy = 0
            setMood(.idle, seconds: 1)
            if Bool.random() { say((appLanguage == "en" ? ["Oops!", "Landed!", "Whoa!"] : ["Оп!", "Приземлився!", "Ух!"]).randomElement() ?? "!", 1.5) }
        }
    }

    func tryJump() -> Bool {
        let f = feet
        let s = screenFrame()
        // Іноді зістрибуємо з вікна вниз
        if floorID != nil && Bool.random() {
            let tx = clamp(f.x + view.facing * 80, s.minX + 30, s.maxX - 30)
            startJump(to: NSPoint(x: tx, y: s.minY), id: nil, rect: .zero)
            return true
        }
        let candidates = windows.filter { w in
            let tx = clamp(f.x, w.rect.minX + 40, w.rect.maxX - 40)
            return w.id != floorID && w.rect.maxY > f.y + 40 && w.rect.maxY < f.y + 500
                && usableTop(w.rect) && abs(tx - f.x) < 350
        }
        guard let w = candidates.randomElement() else { return false }
        let tx = clamp(f.x + view.facing * 40, w.rect.minX + 40, w.rect.maxX - 40)
        startJump(to: NSPoint(x: tx, y: w.rect.maxY), id: w.id, rect: w.rect)
        return true
    }

    func startJump(to target: NSPoint, id: Int?, rect: NSRect) {
        jumpFrom = feet
        jumpTo = target
        jumpTargetID = id
        jumpTargetRect = rect
        jumpStart = Date()
        motion = .jumping
        view.facing = target.x >= jumpFrom.x ? 1 : -1
        view.mood = .jump
        moodStart = Date()
        if Bool.random() { say(id == nil ? L("Стрибаю вниз!", "Jumping down!") : L("Гоп на віконце!", "Hop onto the window!"), 1.5) }
    }

    func stepJump(_ now: Date) {
        let p = CGFloat(min(1, now.timeIntervalSince(jumpStart) / jumpDuration))
        let x = jumpFrom.x + (jumpTo.x - jumpFrom.x) * p
        let y = jumpFrom.y + (jumpTo.y - jumpFrom.y) * p + sin(p * .pi) * 60
        setFeet(NSPoint(x: x, y: y))
        if p >= 1 {
            motion = .grounded
            floorID = jumpTargetID
            floorRect = jumpTargetRect
            setMood(.wave, seconds: 1.2)
        }
    }

    // MARK: Дії

    func clicked() {
        if view.mood == .remind {
            say(L("Добре, відпочивай! 🙂", "Okay, enjoy your break! 🙂"), 2)
            setMood(.wave, seconds: 1.5)
            return
        }
        showCommandPanel()
    }

    @objc func openClaude() {
        forcedSleep = false
        if motion == .grounded { setMood(.wave, seconds: 1.5) }
        say(L("Відкриваю Claude!", "Opening Claude!"), 1.5)
        let ws = NSWorkspace.shared
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        if let url = ws.urlForApplication(withBundleIdentifier: "com.anthropic.claudefordesktop") {
            ws.openApplication(at: url, configuration: config)
        } else if FileManager.default.fileExists(atPath: "/Applications/Claude.app") {
            ws.openApplication(at: URL(fileURLWithPath: "/Applications/Claude.app"), configuration: config)
        } else if let web = URL(string: "https://claude.ai") {
            ws.open(web)
        }
    }

    func doMood(_ m: Mood, _ seconds: Double) {
        guard motion == .grounded else { return }
        forcedSleep = false
        setMood(m, seconds: seconds)
    }

    @objc func toggleSleep() {
        forcedSleep.toggle()
        if forcedSleep { doMood(.sleep, 3600); forcedSleep = true } else { doMood(.wave, 2) }
    }
    @objc func wave() { doMood(.wave, 2.5) }
    @objc func build() { doMood(.build, buildDuration) }
    @objc func rummage() { doMood(.rummage, rummageDuration) }
    @objc func water() { doMood(.water, waterDuration) }
    @objc func coffee() { doMood(.coffee, 9) }
    @objc func ball() { doMood(.ball, 8) }
    @objc func read() { doMood(.read, 10) }
    @objc func dance() { doMood(.dance, 7) }
    @objc func jump() {
        guard motion == .grounded else { return }
        if !tryJump() { say(L("Немає куди стрибати 🤷", "Nowhere to jump 🤷"), 2) }
    }

    @objc func goHome() {
        let s = screenFrame()
        floorID = nil
        motion = .grounded
        setFeet(NSPoint(x: clamp(feet.x, s.minX + 30, s.maxX - 30), y: s.minY))
    }

    @objc func setColor(_ sender: NSMenuItem) {
        if let c = sender.representedObject as? NSColor {
            view.accent = c
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: c, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: "accent")
            }
        }
    }

    @objc func setCostume(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        costumeSetting = value
        applyCostume()
        if motion == .grounded { setMood(.dance, seconds: 3) }
        say(value == "auto" ? L("Одягаюсь за сезоном: \(view.costume.title)", "Dressing for the season: \(view.costume.title)") : L("Новий образ! ✨", "New look! ✨"), 3)
    }

    func setAutostart(_ on: Bool) {
        let fm = FileManager.default
        if on {
            let plist: [String: Any] = [
                "Label": agentLabel,
                "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
                "RunAtLoad": true
            ]
            do {
                try fm.createDirectory(at: launchAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: launchAgentURL, options: .atomic)
            } catch {
                say(L("Не вийшло ввімкнути автозапуск 😕", "Could not enable autostart 😕"), 4)
            }
        } else {
            try? fm.removeItem(at: launchAgentURL)
        }
    }

    @objc func setLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? String else { return }
        appLanguage = lang
        UserDefaults.standard.set(lang, forKey: "language")
        if motion == .grounded { setMood(.wave, seconds: 2) }
        say(L("Тепер говорю українською 🇺🇦", "Now speaking English 🇬🇧"), 3)
    }

    @objc func askName() {
        let alert = NSAlert()
        alert.messageText = L("Як тебе звати?", "What's your name?")
        alert.informativeText = L("Я вітатимусь з тобою на ім'я. Ім'я зберігається тільки на цьому Mac.",
                                  "I will greet you by name. Your name is stored only on this Mac.")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = userName
        alert.accessoryView = field
        alert.addButton(withTitle: L("Зберегти", "Save"))
        alert.addButton(withTitle: L("Скасувати", "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn {
            let name = String(field.stringValue.trimmingCharacters(in: .whitespaces).prefix(30))
            UserDefaults.standard.set(name, forKey: "userName")
            if motion == .grounded { setMood(.love, seconds: 2) }
            say(hello("🙂"), 3)
        }
    }

    func askAutostart() {
        let alert = NSAlert()
        alert.messageText = L("Запускати робота разом із Mac?", "Start the robot together with your Mac?")
        alert.informativeText = L("Це можна будь-коли змінити: правий клік по роботу → «Запускати разом із Mac».",
                                  "You can change this any time: right-click the robot → \"Start with Mac\".")
        alert.addButton(withTitle: L("Так", "Yes"))
        alert.addButton(withTitle: L("Ні", "No"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            setAutostart(true)
            say(L("Тепер я запускатимусь\nразом із Mac 🙂", "I will now start\ntogether with your Mac 🙂"), 4)
        } else {
            say(hello("👋"), 3)
        }
    }

    @objc func toggleAutostart() {
        let newValue = !autostartOn
        setAutostart(newValue)
        say(newValue ? L("Запускатимусь разом із Mac 🙂", "I will start with your Mac 🙂") : L("Автозапуск вимкнено", "Autostart is off"), 3)
    }

    @objc func setBreak(_ sender: NSMenuItem) {
        breakMinutes = sender.tag
        if sender.tag > 0 {
            nextBreak = Date().addingTimeInterval(Double(sender.tag) * 60)
            say(L("Нагадаю через \(sender.tag) хв ⏰", "I will remind you in \(sender.tag) min ⏰"), 2.5)
        } else {
            say(L("Нагадування вимкнено", "Reminders are off"), 2)
        }
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        func item(_ title: String, _ sel: Selector, in m: NSMenu) {
            let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            i.target = self
            m.addItem(i)
        }
        item(L("Дати команду…", "Give a command…"), #selector(showCommandPanel), in: menu)
        item(L("Відкрити Claude", "Open Claude"), #selector(openClaude), in: menu)
        item(L("Що ти вмієш?", "What can you do?"), #selector(showHelp), in: menu)
        menu.addItem(.separator())

        let actions = NSMenu()
        item(L("Побудуй кубики 🧱", "Build blocks 🧱"), #selector(build), in: actions)
        item(L("Понишпор у папці 📁", "Rummage in a folder 📁"), #selector(rummage), in: actions)
        item(L("Полий квітку 🌱", "Water the flower 🌱"), #selector(water), in: actions)
        item(L("Попий кави ☕", "Have a coffee ☕"), #selector(coffee), in: actions)
        item(L("Пограй з м'ячиком ⚽", "Play with the ball ⚽"), #selector(ball), in: actions)
        item(L("Почитай книжку 📖", "Read a book 📖"), #selector(read), in: actions)
        item(L("Потанцюй 🎶", "Dance 🎶"), #selector(dance), in: actions)
        item(L("Застрибни на вікно 🪟", "Jump onto a window 🪟"), #selector(jump), in: actions)
        item(L("Помахай рукою 👋", "Wave 👋"), #selector(wave), in: actions)
        let actionsItem = NSMenuItem(title: L("Заняття", "Activities"), action: nil, keyEquivalent: "")
        actionsItem.submenu = actions
        menu.addItem(actionsItem)

        item(forcedSleep ? L("Прокинься", "Wake up") : L("Поспи", "Take a nap"), #selector(toggleSleep), in: menu)
        item(L("Повернись на низ екрана", "Go back to the bottom of the screen"), #selector(goHome), in: menu)

        let breaks = NSMenu()
        for (title, minutes) in [(L("Кожні 30 хв", "Every 30 min"), 30), (L("Кожні 50 хв", "Every 50 min"), 50), (L("Кожні 90 хв", "Every 90 min"), 90), (L("Вимкнути", "Off"), 0)] {
            let i = NSMenuItem(title: title, action: #selector(setBreak(_:)), keyEquivalent: "")
            i.target = self
            i.tag = minutes
            i.state = minutes == breakMinutes ? .on : .off
            breaks.addItem(i)
        }
        let breakItem = NSMenuItem(title: L("Нагадування про перерву", "Break reminders"), action: nil, keyEquivalent: "")
        breakItem.submenu = breaks
        menu.addItem(breakItem)

        let colors = NSMenu()
        for (name, c) in [(L("Теракотовий", "Terracotta"), NSColor.rgb(216, 90, 48)), (L("Бірюзовий", "Teal"), NSColor.rgb(29, 158, 117)),
                          (L("Фіолетовий", "Purple"), NSColor.rgb(127, 119, 221)), (L("Синій", "Blue"), NSColor.rgb(55, 138, 221))] {
            let i = NSMenuItem(title: name, action: #selector(setColor(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = c
            colors.addItem(i)
        }
        let colorItem = NSMenuItem(title: L("Колір вушок", "Ear color"), action: nil, keyEquivalent: "")
        colorItem.submenu = colors
        menu.addItem(colorItem)

        let costumes = NSMenu()
        let autoItem = NSMenuItem(title: L("Автоматично за сезоном (\(Costume.auto(for: Date()).title))", "Automatic by season (\(Costume.auto(for: Date()).title))"),
                                  action: #selector(setCostume(_:)), keyEquivalent: "")
        autoItem.target = self
        autoItem.representedObject = "auto"
        autoItem.state = costumeSetting == "auto" ? .on : .off
        costumes.addItem(autoItem)
        costumes.addItem(.separator())
        for c in Costume.allCases {
            let i = NSMenuItem(title: c.title, action: #selector(setCostume(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = c.rawValue
            i.state = costumeSetting == c.rawValue ? .on : .off
            costumes.addItem(i)
        }
        let costumeItem = NSMenuItem(title: L("Костюм", "Costume"), action: nil, keyEquivalent: "")
        costumeItem.submenu = costumes
        menu.addItem(costumeItem)

        let auto = NSMenuItem(title: L("Запускати разом із Mac", "Start with Mac"), action: #selector(toggleAutostart), keyEquivalent: "")
        auto.target = self
        auto.state = autostartOn ? .on : .off
        menu.addItem(auto)

        let langs = NSMenu()
        for (title, code) in [("Українська", "uk"), ("English", "en")] {
            let i = NSMenuItem(title: title, action: #selector(setLanguage(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = code
            i.state = appLanguage == code ? .on : .off
            langs.addItem(i)
        }
        let langItem = NSMenuItem(title: L("Мова / Language", "Language / Мова"), action: nil, keyEquivalent: "")
        langItem.submenu = langs
        menu.addItem(langItem)

        let nameItem = NSMenuItem(title: L("Як тебе звати?…", "Your name…"), action: #selector(askName), keyEquivalent: "")
        nameItem.target = self
        menu.addItem(nameItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L("Вийти", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        return menu
    }
}

// MARK: - Поле для команд

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

extension Controller: NSTextFieldDelegate {

    @objc func showCommandPanel() {
        if panel == nil {
            let p = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 44),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.level = .floating
            p.hasShadow = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 300, height: 44))
            bg.material = .popover
            bg.state = .active
            bg.wantsLayer = true
            bg.layer?.cornerRadius = 12
            bg.layer?.masksToBounds = true

            let field = NSTextField(frame: NSRect(x: 14, y: 11, width: 272, height: 22))
            field.placeholderString = L("Що зробити? (Enter — відкрити Claude)", "What should I do? (Enter opens Claude)")
            field.isBordered = false
            field.drawsBackground = false
            field.focusRingType = .none
            field.font = .systemFont(ofSize: 14)
            field.target = self
            field.action = #selector(commandEntered(_:))
            field.delegate = self
            (field.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = false
            bg.addSubview(field)

            p.contentView = bg
            NotificationCenter.default.addObserver(self, selector: #selector(panelResigned),
                                                   name: NSWindow.didResignKeyNotification, object: p)
            panel = p
            commandField = field
        }
        guard let p = panel, let field = commandField else { return }
        let s = screenFrame()
        let x = clamp(window.frame.midX - 150, s.minX + 8, s.maxX - 308)
        let y = min(window.frame.minY + feetOffset + 108, s.maxY - 52)
        p.setFrameOrigin(NSPoint(x: x, y: y))
        field.stringValue = ""
        field.placeholderString = L("Що зробити? (Enter — відкрити Claude)", "What should I do? (Enter opens Claude)")
        p.makeKeyAndOrderFront(nil)
        p.makeFirstResponder(field)
        if motion == .grounded && view.mood != .sleep { setMood(.idle, seconds: 20) }
        say(listeningText, 20)
    }

    @objc func panelResigned() { hidePanel() }

    func hidePanel() {
        panel?.orderOut(nil)
        if bubbleText == listeningText { bubbleUntil = .distantPast }
    }

    // Esc закриває поле
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            hidePanel()
            return true
        }
        return false
    }

    @objc func commandEntered(_ sender: NSTextField) {
        let text = sender.stringValue
        hidePanel()
        run(text)
    }

    // MARK: Виконання команд

    func run(_ raw: String) {
        let cmd = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = cmd.lowercased().replacingOccurrences(of: "’", with: "'")
        if c.isEmpty { openClaude(); return }
        func has(_ words: String...) -> Bool { words.contains { c.contains($0) } }

        // Довідка / Help
        if has("що ти вмієш", "допомога", "help", "команди", "what can you do", "commands") { showHelp(); return }

        // Вкладки браузера / Browser tabs
        if has("вкладк", "tab") {
            let chrome = has("хром", "chrome")
            if has("закрит", "поверн", "віднов", "reopen", "restore", "closed") { reopenClosedTab(chrome: chrome); return }
            if has("останн", "last") { browserTab(.last, chrome: chrome); return }
            if has("перш", "first") { browserTab(.first, chrome: chrome); return }
            if has("нов", "new") { browserTab(.new, chrome: chrome); return }
            if has("закрий", "close") { browserTab(.close, chrome: chrome); return }
            if has("скільки", "які", "що відкрито", "how many", "which", "list") { browserTab(.info, chrome: chrome); return }
        }

        // Таймер / Timer
        if has("скасуй таймер", "вимкни таймер", "зупини таймер", "cancel timer", "stop timer") {
            timerEnd = nil
            reply(L("Таймер скасовано", "Timer cancelled"), .idle)
            return
        }
        if has("таймер", "нагадай через", "засічи", "timer", "remind me in"), let n = firstNumber(c) {
            var seconds = Double(n) * 60
            var unit = L("хв", "min")
            if has("сек", "sec") { seconds = Double(n); unit = L("сек", "sec") }
            if has("годин", "hour") { seconds = Double(n) * 3600; unit = L("год", "h") }
            timerEnd = Date().addingTimeInterval(seconds)
            reply(L("Таймер на \(n) \(unit) ⏳\nНаведи на мене, щоб глянути", "Timer for \(n) \(unit) ⏳\nHover over me to check"), .wave)
            return
        }

        // Час і дата / Time and date
        if has("котра година", "скільки час", "який час", "яка дата", "яке сьогодні",
               "what time", "time is it", "what date", "what day") {
            let f = DateFormatter()
            f.locale = Locale(identifier: appLanguage == "en" ? "en_US" : "uk_UA")
            f.dateFormat = appLanguage == "en" ? "HH:mm, EEEE, MMMM d" : "HH:mm, EEEE, d MMMM"
            reply("🕒 " + f.string(from: Date()), .wave)
            return
        }

        // Скріншот / Screenshot
        if has("скрін", "знімок екрана", "screenshot") {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH.mm.ss"
            let path = NSHomeDirectory() + "/Desktop/" + L("Знімок робота ", "Robot screenshot ") + f.string(from: Date()) + ".png"
            panel?.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.shell("/usr/sbin/screencapture", ["-x", path]) {
                    self.reply(L("Зробив знімок 📸\nВін на робочому столі", "Screenshot taken 📸\nIt is on your Desktop"), .wave)
                } else {
                    self.reply(L("Не вийшло зробити знімок 😕", "Could not take a screenshot 😕"), .idle)
                }
            }
            return
        }

        // Гучність / Volume
        if has("гучніш", "louder", "volume up") { _ = apple("set volume output volume ((output volume of (get volume settings)) + 15)"); reply(L("Гучніше 🔊", "Louder 🔊"), .dance); return }
        if has("тихіш", "quieter", "volume down") { _ = apple("set volume output volume ((output volume of (get volume settings)) - 15)"); reply(L("Тихіше 🔉", "Quieter 🔉"), .idle); return }
        if has("увімкни звук", "unmute") { _ = apple("set volume without output muted"); reply(L("Звук увімкнено 🔊", "Sound on 🔊"), .wave); return }
        if has("без звуку", "вимкни звук", "mute") { _ = apple("set volume with output muted"); reply(L("Звук вимкнено 🔇", "Sound muted 🔇"), .idle); return }

        // Папки / Folders
        if has("папк", "відкрий", "покажи", "folder", "open", "show") {
            let folders: [(String, String, String, String)] = [
                ("завантаж", "Downloads", "Завантаження", "Downloads"), ("download", "Downloads", "Завантаження", "Downloads"),
                ("документ", "Documents", "Документи", "Documents"), ("document", "Documents", "Документи", "Documents"),
                ("робочий стіл", "Desktop", "Робочий стіл", "Desktop"), ("робочого столу", "Desktop", "Робочий стіл", "Desktop"),
                ("desktop", "Desktop", "Робочий стіл", "Desktop"),
                ("програм", "Applications", "Програми", "Applications"), ("applications", "Applications", "Програми", "Applications")
            ]
            let mentionsApp = c.contains("програму") || c.contains(" app ")
            for (key, dir, ukName, enName) in folders where c.contains(key) && (has("папк", "folder") || !mentionsApp) {
                NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory() + "/" + dir))
                let name = L(ukName, enName)
                reply(L("Відкриваю «\(name)» 📁", "Opening \(name) 📁"), .rummage, 4)
                return
            }
        }

        // Пошук у Google / Google search
        for key in ["загугли", "знайди", "пошукай", "пошук", "google", "search for", "search", "find"] where c.hasPrefix(key) {
            let q = String(cmd.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
            var comps = URLComponents(string: "https://www.google.com/search")
            comps?.queryItems = [URLQueryItem(name: "q", value: q)]
            if !q.isEmpty, let url = comps?.url {
                NSWorkspace.shared.open(url)
                reply(L("Шукаю: \(q.prefix(24)) 🔍", "Searching: \(q.prefix(24)) 🔍"), .rummage, 4)
                return
            }
        }

        // Сайт (щось на зразок google.com) / Website
        if let range = c.range(of: "[a-z0-9-]+(\\.[a-z0-9-]+)*\\.[a-z]{2,}(/\\S*)?", options: .regularExpression) {
            var site = String(c[range])
            if !site.hasPrefix("http") { site = "https://" + site }
            if let url = URL(string: site) {
                NSWorkspace.shared.open(url)
                reply(L("Відкриваю сайт 🌐", "Opening the website 🌐"), .wave)
                return
            }
        }

        // Програми / Apps
        for key in ["відкрий ", "запусти ", "увімкни ", "open ", "launch ", "start "] where c.hasPrefix(key) {
            let name = String(c.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
            openApp(name)
            return
        }

        // Дії самого робота / Robot actions
        let robotActions: [(String, Mood, Double)] = [
            ("танц", .dance, 7), ("кави", .coffee, 9), ("каву", .coffee, 9), ("квітк", .water, waterDuration),
            ("кубик", .build, buildDuration), ("м'яч", .ball, 8), ("мяч", .ball, 8),
            ("книж", .read, 10), ("читай", .read, 10), ("понишпор", .rummage, rummageDuration),
            ("помахай", .wave, 2.5), ("привіт", .wave, 2.5),
            ("dance", .dance, 7), ("coffee", .coffee, 9), ("flower", .water, waterDuration),
            ("block", .build, buildDuration), ("ball", .ball, 8), ("book", .read, 10), ("read", .read, 10),
            ("rummage", .rummage, rummageDuration), ("wave", .wave, 2.5), ("hello", .wave, 2.5)
        ]
        for (key, mood, sec) in robotActions where c.contains(key) {
            doMood(mood, sec)
            say(mood == .wave ? L("Привіт! 👋", "Hi! 👋") : L("Із задоволенням!", "With pleasure!"), 2.5)
            return
        }
        if has("поспи", "спати", "засни", "sleep", "nap") { if !forcedSleep { toggleSleep() }; return }
        if has("прокинь", "wake") { if forcedSleep { toggleSleep() }; return }
        if has("стриб", "jump") { jump(); return }

        // Усе інше — питання до Claude
        askClaude(cmd)
    }

    // MARK: Команди для браузерів

    enum TabAction { case last, first, new, close, info }

    func browserTab(_ action: TabAction, chrome: Bool) {
        let app = chrome ? "Google Chrome" : "Safari"
        let body: String
        switch (action, chrome) {
        case (.last, false): body = "set current tab of front window to last tab of front window"
        case (.first, false): body = "set current tab of front window to first tab of front window"
        case (.new, false): body = "tell front window to set current tab to (make new tab)"
        case (.close, false): body = "close current tab of front window"
        case (.info, false): body = "return (count of tabs of front window as text) & \"|\" & (name of current tab of front window)"
        case (.last, true): body = "set active tab index of front window to (count of tabs of front window)"
        case (.first, true): body = "set active tab index of front window to 1"
        case (.new, true): body = "tell front window to make new tab"
        case (.close, true): body = "close active tab of front window"
        case (.info, true): body = "return (count of tabs of front window as text) & \"|\" & (title of active tab of front window)"
        }
        let newWindow = action == .new ? (chrome ? "make new window" : "make new document") : "return \"nowin\""
        let script = """
        tell application "\(app)"
            activate
            if (count of windows) = 0 then
                \(newWindow)
            end if
            \(body)
        end tell
        """
        let (result, error) = apple(script)
        if let e = error { explain(e); return }
        if result == "nowin" { reply(L("У \(app) немає відкритих вікон 🤔", "\(app) has no open windows 🤔"), .idle); return }
        switch action {
        case .last: reply(L("Відкрив останню вкладку 🧭", "Switched to the last tab 🧭"), .wave)
        case .first: reply(L("Відкрив першу вкладку 🧭", "Switched to the first tab 🧭"), .wave)
        case .new: reply(L("Нова вкладка готова ✨", "New tab is ready ✨"), .wave)
        case .close: reply(L("Закрив вкладку 👋", "Tab closed 👋"), .idle)
        case .info:
            let parts = (result ?? "").components(separatedBy: "|")
            let count = parts.first ?? "?"
            let title = parts.count > 1 ? String(parts[1].prefix(26)) : ""
            reply(L("Вкладок: \(count)\nЗараз: \(title)", "Tabs: \(count)\nNow: \(title)"), .read, 4)
        }
    }

    func reopenClosedTab(chrome: Bool) {
        let app = chrome ? "Google Chrome" : "Safari"
        let script = """
        tell application "\(app)" to activate
        delay 0.3
        tell application "System Events" to keystroke "t" using {command down, shift down}
        """
        let (_, error) = apple(script)
        if let e = error { explain(e); return }
        reply(L("Повернув закриту вкладку ↩️", "Reopened the closed tab ↩️"), .wave)
    }

    // MARK: Програми та Claude

    func openApp(_ spoken: String) {
        let names: [String: String] = [
            "сафарі": "Safari", "safari": "Safari", "хром": "Google Chrome", "chrome": "Google Chrome",
            "телеграм": "Telegram", "telegram": "Telegram", "нотатки": "Notes", "календар": "Calendar",
            "пошту": "Mail", "пошта": "Mail", "музику": "Music", "музика": "Music", "фото": "Photos",
            "файндер": "Finder", "finder": "Finder", "налаштування": "System Settings",
            "ноушн": "Notion", "notion": "Notion", "клод": "Claude", "claude": "Claude",
            "термінал": "Terminal", "калькулятор": "Calculator", "нагадування": "Reminders",
            "повідомлення": "Messages", "zoom": "zoom.us", "зум": "zoom.us", "слек": "Slack", "slack": "Slack",
            "вайбер": "Viber", "viber": "Viber", "ворд": "Microsoft Word", "word": "Microsoft Word",
            "ексель": "Microsoft Excel", "excel": "Microsoft Excel", "vs code": "Visual Studio Code",
            "вскод": "Visual Studio Code", "spotify": "Spotify", "спотіфай": "Spotify",
            "notes": "Notes", "calendar": "Calendar", "mail": "Mail", "music": "Music", "photos": "Photos",
            "settings": "System Settings", "terminal": "Terminal", "calculator": "Calculator",
            "reminders": "Reminders", "messages": "Messages"
        ]
        let cleaned = spoken.replacingOccurrences(of: "програму ", with: "").replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: " app", with: "")
        if cleaned == "claude" || cleaned == "клод" { openClaude(); return }
        let appName = names[cleaned] ?? names.first(where: { cleaned.contains($0.key) })?.value ?? cleaned
        if shell("/usr/bin/open", ["-a", appName]) {
            reply(L("Відкриваю \(appName) 🚀", "Opening \(appName) 🚀"), .wave)
        } else {
            reply(L("Не знайшов програму\n«\(cleaned)» 🤔", "Could not find the app\n\"\(cleaned)\" 🤔"), .idle)
        }
    }

    func askClaude(_ question: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(question, forType: .string)
        openClaude()
        say(L("Питання вже в буфері 📋\nНатисни ⌘V у Claude", "Your question is copied 📋\nPress ⌘V in Claude"), 6)
    }

    // MARK: Допоміжне

    func reply(_ text: String, _ mood: Mood, _ seconds: Double = 2.5) {
        if motion == .grounded { forcedSleep = false; setMood(mood, seconds: max(seconds, 2)) }
        say(text, max(seconds, 3))
    }

    func firstNumber(_ s: String) -> Int? {
        guard let r = s.range(of: "[0-9]+", options: .regularExpression) else { return nil }
        return Int(s[r])
    }

    func apple(_ source: String) -> (String?, String?) {
        var err: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&err)
        if let e = err {
            let num = e[NSAppleScript.errorNumber] as? Int ?? 0
            let msg = e[NSAppleScript.errorMessage] as? String ?? "помилка"
            return (nil, "\(num)|\(msg)")
        }
        return (result?.stringValue, nil)
    }

    func explain(_ error: String) {
        let num = Int(error.components(separatedBy: "|").first ?? "") ?? 0
        if num == -1743 {
            reply(L("Дай мені дозвіл:\nНалаштування → Автоматизація", "Please allow me in\nSettings → Automation"), .idle, 6)
        } else if num == -1719 || num == 1002 || error.contains("assistive") || error.contains("not allowed to send keystrokes") {
            reply(L("Дай мені дозвіл:\nНалаштування → Універсальний доступ", "Please allow me in\nSettings → Accessibility"), .idle, 6)
        } else if num == -600 || num == -1728 {
            reply(L("Схоже, браузер не відкритий 🤔", "Looks like the browser is not open 🤔"), .idle, 4)
        } else {
            reply(L("Щось не вийшло 😕", "Something went wrong 😕"), .idle, 3)
        }
    }

    @discardableResult
    func shell(_ path: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }

    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = L("Що я вмію 🤖", "What I can do 🤖")
        alert.informativeText = appLanguage == "en" ? """
        Click me and type a command:

        • open the last tab in safari
        • open the first / new tab, close tab
        • reopen closed tab
        • how many tabs are open
        • (same for Chrome: "…in chrome")
        • open telegram / notes / notion / …
        • open google.com
        • search for pancake recipe
        • open downloads folder / documents
        • timer 10 min, cancel timer
        • what time is it
        • take a screenshot
        • louder / quieter / mute
        • dance, have a coffee, water the flower, build blocks

        Anything else goes to Claude: your question is copied, just press ⌘V.
        An empty Enter simply opens Claude.
        Commands work in both English and Ukrainian.
        """ : """
        Клацни на мене і напиши команду:

        • відкрий останню вкладку в сафарі
        • відкрий першу / нову вкладку, закрий вкладку
        • поверни закриту вкладку
        • скільки вкладок відкрито
        • (те саме для хрому: «…в хромі»)
        • відкрий телеграм / нотатки / ноушн / …
        • відкрий google.com
        • знайди рецепт борщу
        • відкрий папку завантаження / документи
        • таймер 10 хв, скасуй таймер
        • котра година
        • зроби скрін
        • гучніше / тихіше / без звуку
        • танцюй, попий кави, полий квітку, будуй кубики

        Усе інше я передам Claude: питання опиниться в буфері, натисни ⌘V.
        Порожній Enter просто відкриє Claude.
        Команди працюють українською та англійською.
        """
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

// MARK: - Запуск

let app = NSApplication.shared
let controller = Controller()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
