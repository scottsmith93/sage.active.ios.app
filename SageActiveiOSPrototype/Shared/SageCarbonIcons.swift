import SwiftUI
import UIKit

/// The Carbon icon font from Sage Carbon, exposed through a native SwiftUI API.
///
/// Carbon's React components and web font formats are intentionally not included here.
/// The TTF is bundled as `carbon-icons-webfont.ttf` and registered in the app Info.plist.
/// Its internal family name is `sage-icons` (the filename is a legacy Carbon name).
/// Source: Sage/carbon at commit `d2c2b329ef0bd50dc3e85eaefaa1cd2139628201`.
public struct SageCarbonIcon: RawRepresentable, Hashable, CaseIterable, Sendable {
    public let rawValue: String
    private let codePoint: UInt32

    public init?(rawValue: String) {
        guard let codePoint = Self.codePoints[rawValue] else { return nil }
        self.rawValue = rawValue
        self.codePoint = codePoint
    }

    public init?(_ name: String) {
        self.init(rawValue: name)
    }

    public var glyph: String {
        String(UnicodeScalar(codePoint)!)
    }

    public static let allCases: [SageCarbonIcon] = codePoints.keys.sorted().compactMap(Self.init(rawValue:))

    private static let codePoints: [String: UInt32] = [
        "accessibility_web": 0xf045,
        "add": 0xe940,
        "admin": 0xe94f,
        "airplay": 0xf073,
        "alert": 0xe90b,
        "alert_on": 0xf001,
        "analysis": 0xe912,
        "app_facebook": 0xf052,
        "app_instagram": 0xf046,
        "app_tiktok": 0xf035,
        "app_twitter": 0xf041,
        "app_youtube": 0xf047,
        "apps": 0xf040,
        "arrow": 0xe904,
        "arrow_bottom_right_circle": 0xf014,
        "arrow_down": 0xe901,
        "arrow_left": 0xe902,
        "arrow_left_boxed": 0xe988,
        "arrow_left_right_small": 0xe964,
        "arrow_left_small": 0xe963,
        "arrow_right": 0xe904,
        "arrow_right_small": 0xe962,
        "arrow_top_left_circle": 0xf017,
        "arrow_top_right_circle": 0xf096,
        "arrow_up": 0xe907,
        "arrows_left_right": 0xf027,
        "at_sign": 0xf093,
        "attach": 0xe937,
        "bank": 0xe977,
        "bank_with_card": 0xf019,
        "basket": 0xe90a,
        "basket_with_squares": 0xe975,
        "batch": 0xf074,
        "bed": 0xf010,
        "bill_paid": 0xf049,
        "bill_unpaid": 0xf063,
        "bin": 0xe90c,
        "biometric": 0xf067,
        "block_arrow_right": 0xe97e,
        "blocked": 0xe933,
        "blocked_square": 0xe934,
        "bold": 0xe98c,
        "box_arrow_left": 0xf006,
        "box_arrow_right": 0xf057,
        "boxed_shapes": 0xe982,
        "bulk_destroy": 0xe90c,
        "bullet_list": 0xe95b,
        "bullet_list_dotted": 0xe98a,
        "bullet_list_numbers": 0xe989,
        "business": 0xe90d,
        "calendar": 0xe90e,
        "calendar_pay_date": 0xf038,
        "calendar_today": 0xe970,
        "call": 0xe93d,
        "camera": 0xe90f,
        "car_lock": 0xf021,
        "car_money": 0xf011,
        "car_repair": 0xf022,
        "card_view": 0xe94b,
        "card_wallet": 0xf030,
        "caret_down": 0xe910,
        "caret_large_down": 0xe9a4,
        "caret_large_left": 0xe9a2,
        "caret_large_right": 0xe9a3,
        "caret_large_up": 0xe9a5,
        "caret_left": 0xe9a6,
        "caret_right": 0xe9a7,
        "caret_up": 0xe9a8,
        "caret_up_down": 0xf110,
        "cart": 0xe90a,
        "cash": 0xf020,
        "chart_bar": 0xe911,
        "chart_bar_arrow_up": 0xf106,
        "chart_line": 0xe912,
        "chart_pie": 0xe913,
        "chat": 0xe914,
        "chat_notes": 0xe956,
        "check_all": 0xf028,
        "check_none": 0xf029,
        "chevron_down": 0xe915,
        "chevron_down_thick": 0xe99c,
        "chevron_first": 0xf090,
        "chevron_first_pagination": 0xf108,
        "chevron_last": 0xf091,
        "chevron_last_pagination": 0xf109,
        "chevron_left": 0xe916,
        "chevron_left_thick": 0xe99f,
        "chevron_right": 0xe917,
        "chevron_right_thick": 0xe99e,
        "chevron_up": 0xe918,
        "chevron_up_thick": 0xe99d,
        "chromecast": 0xf075,
        "circle_with_dots": 0xe965,
        "circles_connection": 0xe979,
        "clear": 0xf097,
        "clock": 0xe919,
        "clock_add": 0xf116,
        "close": 0xe91e,
        "cloud_co2": 0xf060,
        "code": 0xf113,
        "coins": 0xe96a,
        "collaborate": 0xe946,
        "computer_clock": 0xe997,
        "connect": 0xe955,
        "connect_circle": 0xf111,
        "connect_off": 0xf053,
        "construction": 0xf008,
        "contact_card": 0xf059,
        "contacts": 0xe93b,
        "copy": 0xe91b,
        "create": 0xe940,
        "credit_card": 0xe91c,
        "credit_card_slash": 0xe966,
        "cross": 0xe91d,
        "cross_circle": 0xe992,
        "csv": 0xe94a,
        "dashboard": 0xf007,
        "delete": 0xe90c,
        "delivery": 0xe959,
        "diagonal_arrows_up": 0xf098,
        "disconnect": 0xe953,
        "disputed": 0xe958,
        "document_right_align": 0xe981,
        "document_tick": 0xe980,
        "document_vertical_lines": 0xe978,
        "double_tick": 0xf099,
        "download": 0xe900,
        "draft": 0xe939,
        "drag": 0xe94c,
        "drag_hover": 0xf092,
        "drag_vertical": 0xe94d,
        "drill": 0xf015,
        "dropdown": 0xe910,
        "duplicate": 0xe921,
        "edit": 0xe93a,
        "edited": 0xe938,
        "ellipsis_horizontal": 0xe960,
        "ellipsis_vertical": 0xe961,
        "email": 0xe922,
        "email_switch": 0xe996,
        "entry": 0xe92c,
        "envelope_dollar": 0xe9ab,
        "envelope_euro": 0xe9a9,
        "error": 0xe923,
        "error_square": 0xe97f,
        "euro": 0xe9a0,
        "expand": 0xe99b,
        "export": 0xf065,
        "factory": 0xe976,
        "favourite": 0xe94f,
        "favourite_lined": 0xe94e,
        "fax": 0xe925,
        "feedback": 0xe930,
        "file_excel": 0xe98e,
        "file_generic": 0xe991,
        "file_image": 0xe98d,
        "file_pdf": 0xe990,
        "file_word": 0xe98f,
        "files_leaning": 0xe97a,
        "filter": 0xe928,
        "filter_new": 0xe954,
        "fit_height": 0xe909,
        "fit_width": 0xe908,
        "flag": 0xe999,
        "flash": 0xf100,
        "folder": 0xe927,
        "form_refresh": 0xf018,
        "framerate": 0xf076,
        "fullscreen": 0xf077,
        "get_quote": 0xf101,
        "gift": 0xe941,
        "go": 0xe903,
        "graduation_hat": 0xf013,
        "graph": 0xe912,
        "grid": 0xe952,
        "hand_cash_coins": 0xf009,
        "hand_cash_note": 0xf024,
        "heart": 0xf102,
        "heart_pulse": 0xf031,
        "help": 0xe951,
        "hide": 0xe998,
        "hierarchy": 0xf088,
        "home": 0xe929,
        "image": 0xe93e,
        "import": 0xf066,
        "in_progress": 0xe920,
        "in_transit": 0xe964,
        "individual": 0xe93c,
        "info": 0xe92a,
        "intranet": 0xf048,
        "ipad": 0xf103,
        "italic": 0xe98b,
        "job_seeked": 0xf037,
        "key": 0xe92b,
        "laptop": 0xf012,
        "leaf": 0xf061,
        "ledger": 0xe973,
        "ledger_arrow_left": 0xe971,
        "ledger_arrow_right": 0xe972,
        "lightbulb_off": 0xe95c,
        "lightbulb_on": 0xe95d,
        "like": 0xf056,
        "like_no": 0xf058,
        "link": 0xe92d,
        "link_card": 0xf094,
        "link_cloud": 0xf036,
        "link_on": 0xf043,
        "list_view": 0xe92c,
        "location": 0xe93f,
        "locked": 0xe935,
        "login": 0xf107,
        "logout": 0xe92e,
        "lookup": 0xe96f,
        "marker": 0xe93f,
        "marker_off": 0xf115,
        "message": 0xe922,
        "microphone": 0xf054,
        "minimise": 0xf062,
        "minus": 0xe931,
        "minus_large": 0xe968,
        "mobile": 0xe932,
        "money_bag": 0xe974,
        "mute": 0xf078,
        "normalscreen": 0xf079,
        "old_warning": 0xe924,
        "page": 0xf080,
        "palm_tree": 0xf002,
        "pause": 0xe96d,
        "pause_circle": 0xe96b,
        "pdf": 0xe91f,
        "people": 0xe93b,
        "people_switch": 0xe995,
        "percentage_boxed": 0xf016,
        "person": 0xe93c,
        "person_info": 0xe994,
        "person_tick": 0xe97b,
        "petrol_pump": 0xf026,
        "phone": 0xe93d,
        "picture_in_picture": 0xf081,
        "piggy_bank": 0xe926,
        "pin": 0xf064,
        "placeholder": 0xe99a,
        "plane": 0xf025,
        "play": 0xe95f,
        "play_circle": 0xe96c,
        "plus": 0xe940,
        "plus_circle": 0xf112,
        "plus_large": 0xe967,
        "pound": 0xe9a1,
        "print": 0xe942,
        "progress": 0xe965,
        "progressed": 0xe903,
        "protect": 0xf044,
        "question": 0xe943,
        "question_hollow": 0xe95e,
        "question_mark": 0xe943,
        "recruiting": 0xf033,
        "refresh": 0xe945,
        "refresh_clock": 0xe986,
        "remove": 0xe931,
        "replay": 0xf082,
        "reset": 0xf104,
        "sage_coin": 0xe9ac,
        "save": 0xe926,
        "scan": 0xe96e,
        "search": 0xe92f,
        "send": 0xf055,
        "services": 0xe940,
        "settings": 0xe91a,
        "settings_old": 0xe91a,
        "share": 0xe946,
        "shield_with_tick": 0xf070,
        "shield_with_tick_outline": 0xf071,
        "shop": 0xe947,
        "sort_down": 0xe948,
        "sort_up": 0xe949,
        "source_code": 0xf114,
        "spanner": 0xe984,
        "speaker": 0xf083,
        "split": 0xe952,
        "split_container": 0xe987,
        "squares_nine": 0xe969,
        "stacked_boxes": 0xe97c,
        "stacked_squares": 0xe983,
        "stop": 0xf068,
        "stop_circle": 0xf069,
        "submitted": 0xe903,
        "subtitles": 0xf084,
        "support_online": 0xf032,
        "sync": 0xe944,
        "system_Android": 0xf118,
        "system_iOS": 0xf117,
        "tag": 0xe985,
        "talk": 0xe95a,
        "target": 0xf042,
        "target_man": 0xf050,
        "theatre_masks": 0xf023,
        "three_boxes": 0xe97d,
        "tick": 0xe950,
        "tick_circle": 0xe993,
        "tick_thick": 0xf003,
        "time_zone": 0xf095,
        "true_tick": 0xe950,
        "u_turn_left": 0xf004,
        "u_turn_right": 0xf005,
        "underline": 0xf089,
        "undo": 0xe9aa,
        "unlocked": 0xe936,
        "upload": 0xe906,
        "uploaded": 0xe905,
        "user_groups": 0xf105,
        "video": 0xe95e,
        "view": 0xe957,
        "volume_high": 0xf087,
        "volume_low": 0xf085,
        "volume_medium": 0xf086,
        "volunteering": 0xf039,
        "warning": 0xe924,
        "website": 0xf051,
        "welfare": 0xf034,
        "worldwide_location": 0xf072,
    ]
}

/// Renders a Carbon icon using the bundled CarbonIcons font.
public struct SageCarbonIconView: View {
    public let icon: SageCarbonIcon
    public var pointSize: CGFloat
    public var color: Color

    public init(_ icon: SageCarbonIcon, pointSize: CGFloat = 24, color: Color = .primary) {
        self.icon = icon
        self.pointSize = pointSize
        self.color = color
    }

    public var body: some View {
        Text(icon.glyph)
            .font(.custom("sage-icons", size: pointSize, relativeTo: .body))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

/// Standard icon-only toolbar action with a Carbon glyph and an accessible text label.
public struct SageCarbonToolbarButton: View {
    public let icon: SageCarbonIcon
    public let accessibilityLabel: String
    public let action: () -> Void

    public init(
        icon: SageCarbonIcon,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            SageCarbonIconView(
                icon,
                pointSize: 20,
                color: SageActiveTheme.primaryText
            )
            .frame(width: 20, height: 20)
        }
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Supplies a template image for system containers, such as `TabView`, that require an `Image`
/// rather than an arbitrary SwiftUI view for their icon slot.
public struct SageCarbonTabIcon: View {
    public let icon: SageCarbonIcon
    public var pointSize: CGFloat

    public init(_ icon: SageCarbonIcon, pointSize: CGFloat = 20) {
        self.icon = icon
        self.pointSize = pointSize
    }

    public var body: some View {
        Image(uiImage: renderedImage)
            .renderingMode(.template)
    }

    private var renderedImage: UIImage {
        let canvasSize = CGSize(width: 25, height: 25)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false

        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            let font = UIFont(name: "sage-icons", size: pointSize)
                ?? UIFont.systemFont(ofSize: pointSize)
            let glyph = icon.glyph as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
            ]
            let glyphSize = glyph.size(withAttributes: attributes)
            glyph.draw(
                at: CGPoint(
                    x: (canvasSize.width - glyphSize.width) / 2,
                    y: (canvasSize.height - glyphSize.height) / 2
                ),
                withAttributes: attributes
            )
        }
        .withRenderingMode(.alwaysTemplate)
    }
}

public extension SageCarbonIcon {
    static let add = SageCarbonIcon(rawValue: "add")!
    static let bank = SageCarbonIcon(rawValue: "bank")!
    static let billPaid = SageCarbonIcon(rawValue: "bill_paid")!
    static let billUnpaid = SageCarbonIcon(rawValue: "bill_unpaid")!
    static let calendar = SageCarbonIcon(rawValue: "calendar")!
    static let cart = SageCarbonIcon(rawValue: "cart")!
    /// Carbon's cart glyph is the branded trolley/cart icon used for purchases.
    static let trolley = SageCarbonIcon(rawValue: "cart")!
    static let chartLine = SageCarbonIcon(rawValue: "chart_line")!
    static let chartBar = SageCarbonIcon(rawValue: "chart_bar")!
    static let chartPie = SageCarbonIcon(rawValue: "chart_pie")!
    static let chartBarArrowUp = SageCarbonIcon(rawValue: "chart_bar_arrow_up")!
    static let boxedShapes = SageCarbonIcon(rawValue: "boxed_shapes")!
    static let caretDown = SageCarbonIcon(rawValue: "caret_down")!
    static let caretLargeLeft = SageCarbonIcon(rawValue: "caret_large_left")!
    static let caretUp = SageCarbonIcon(rawValue: "caret_up")!
    static let caretUpDown = SageCarbonIcon(rawValue: "caret_up_down")!
    static let dragVertical = SageCarbonIcon(rawValue: "drag_vertical")!
    static let arrowUp = SageCarbonIcon(rawValue: "arrow_up")!
    static let arrowDown = SageCarbonIcon(rawValue: "arrow_down")!
    static let chevronRight = SageCarbonIcon(rawValue: "chevron_right")!
    static let chevronRightThick = SageCarbonIcon(rawValue: "chevron_right_thick")!
    static let chevronDown = SageCarbonIcon(rawValue: "chevron_down")!
    static let chevronLeft = SageCarbonIcon(rawValue: "chevron_left")!
    static let close = SageCarbonIcon(rawValue: "close")!
    static let feedback = SageCarbonIcon(rawValue: "feedback")!
    static let help = SageCarbonIcon(rawValue: "help")!
    static let language = SageCarbonIcon(rawValue: "chat")!
    static let listView = SageCarbonIcon(rawValue: "list_view")!
    static let logout = SageCarbonIcon(rawValue: "logout")!
    static let microphone = SageCarbonIcon(rawValue: "microphone")!
    static let plusLarge = SageCarbonIcon(rawValue: "plus_large")!
    static let create = SageCarbonIcon(rawValue: "create")!
    static let cross = SageCarbonIcon(rawValue: "cross")!
    static let crossCircle = SageCarbonIcon(rawValue: "cross_circle")!
    static let dashboard = SageCarbonIcon(rawValue: "dashboard")!
    static let documentTick = SageCarbonIcon(rawValue: "document_tick")!
    static let edit = SageCarbonIcon(rawValue: "edit")!
    static let email = SageCarbonIcon(rawValue: "email")!
    static let ellipsisVertical = SageCarbonIcon(rawValue: "ellipsis_vertical")!
    static let error = SageCarbonIcon(rawValue: "error")!
    static let filter = SageCarbonIcon(rawValue: "filter")!
    static let getQuote = SageCarbonIcon(rawValue: "get_quote")!
    static let info = SageCarbonIcon(rawValue: "info")!
    static let jobSeeked = SageCarbonIcon(rawValue: "job_seeked")!
    static let people = SageCarbonIcon(rawValue: "people")!
    static let person = SageCarbonIcon(rawValue: "person")!
    static let search = SageCarbonIcon(rawValue: "search")!
    static let settings = SageCarbonIcon(rawValue: "settings")!
    static let shieldWithTick = SageCarbonIcon(rawValue: "shield_with_tick")!
    static let switchBusiness = SageCarbonIcon(rawValue: "arrow_left_right_small")!
    static let tickCircle = SageCarbonIcon(rawValue: "tick_circle")!
    static let tickThick = SageCarbonIcon(rawValue: "tick_thick")!
    static let warning = SageCarbonIcon(rawValue: "warning")!
}
