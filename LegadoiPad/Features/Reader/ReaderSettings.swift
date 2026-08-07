import SwiftUI
import UIKit

enum ReaderPageMode: String, Codable, CaseIterable, Identifiable {
    case scroll
    case page

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scroll: return "上下滚动"
        case .page: return "左右翻页"
        }
    }
}

enum ReaderOrientationLock: String, Codable, CaseIterable, Identifiable {
    case auto
    case portrait
    case landscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "跟随系统"
        case .portrait: return "锁定竖屏"
        case .landscape: return "锁定横屏"
        }
    }

    var mask: UIInterfaceOrientationMask {
        switch self {
        case .auto: return .all
        case .portrait: return .portrait
        case .landscape: return [.landscapeLeft, .landscapeRight]
        }
    }
}

@MainActor
final class ReaderSettings: ObservableObject {
    static let shared = ReaderSettings()

    @Published var fontSize: Double { didSet { save() } }
    @Published var isNight: Bool { didSet { save() } }
    @Published var pageMode: ReaderPageMode { didSet { save() } }
    @Published var orientationLock: ReaderOrientationLock {
        didSet {
            save()
            OrientationLockController.shared.mask = orientationLock.mask
            OrientationLockController.shared.apply()
        }
    }

    private let storageKey = "legado.readerSettings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Storage.self, from: data) {
            fontSize = decoded.fontSize
            isNight = decoded.isNight
            pageMode = decoded.pageMode
            orientationLock = decoded.orientationLock
        } else {
            fontSize = 20
            isNight = false
            pageMode = .scroll
            orientationLock = .auto
        }
        OrientationLockController.shared.mask = orientationLock.mask
    }

    var pageBackground: Color {
        isNight ? Color(white: 0.11) : Color.white
    }

    var textColor: Color {
        isNight ? Color(white: 0.88) : Color(white: 0.1)
    }

    var chromeBackground: Color {
        isNight ? Color(white: 0.16) : Color(white: 0.96)
    }

    var chromeForeground: Color {
        isNight ? Color(white: 0.9) : Color.primary
    }

    private struct Storage: Codable {
        var fontSize: Double
        var isNight: Bool
        var pageMode: ReaderPageMode
        var orientationLock: ReaderOrientationLock
    }

    private func save() {
        let storage = Storage(
            fontSize: fontSize,
            isNight: isNight,
            pageMode: pageMode,
            orientationLock: orientationLock
        )
        if let data = try? JSONEncoder().encode(storage) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

final class OrientationLockController {
    static let shared = OrientationLockController()
    var mask: UIInterfaceOrientationMask = .all

    func apply() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
        scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLockController.shared.mask
    }
}
