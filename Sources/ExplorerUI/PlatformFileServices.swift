import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
import QuickLookUI
#elseif os(iOS)
import QuickLook
import UIKit
#endif

struct PlatformApplicationChoice: Identifiable, Hashable {
    var id: URL { url }

    let name: String
    let url: URL
}

@MainActor
enum PlatformFileServices {
    static func open(_ url: URL) {
        openItems([url])
    }

    static func openItems(_ urls: [URL]) {
        #if os(macOS)
        for url in urls {
            NSWorkspace.shared.open(url)
        }
        #elseif os(iOS)
        for url in urls {
            UIApplication.shared.open(url)
        }
        #endif
    }

    static func open(_ urls: [URL], with application: PlatformApplicationChoice) {
        #if os(macOS)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.promptsUserIfNeeded = true
        NSWorkspace.shared.open(urls, withApplicationAt: application.url, configuration: configuration) { _, _ in }
        #else
        openItems(urls)
        #endif
    }

    static func applicationsThatCanOpen(_ url: URL) -> [PlatformApplicationChoice] {
        #if os(macOS)
        NSWorkspace.shared.urlsForApplications(toOpen: url).map { applicationURL in
            PlatformApplicationChoice(
                name: FileManager.default.displayName(atPath: applicationURL.path),
                url: applicationURL
            )
        }
        #else
        []
        #endif
    }

    static func reveal(_ url: URL) {
        revealItems([url])
    }

    static func revealItems(_ urls: [URL]) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting(urls)
        #elseif os(iOS)
        if let firstURL = urls.first {
            UIApplication.shared.open(firstURL.deletingLastPathComponent())
        }
        #endif
    }

    static func quickLookItems(_ urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        #if os(macOS)
        guard let panel = QLPreviewPanel.shared() else {
            openItems(urls)
            return
        }

        quickLookDataSource.urls = urls
        panel.dataSource = quickLookDataSource
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        panel.makeKeyAndOrderFront(nil)
        #elseif os(iOS)
        let controller = QLPreviewController()
        quickLookDataSource.urls = urls
        controller.dataSource = quickLookDataSource
        controller.currentPreviewItemIndex = 0
        present(controller)
        #endif
    }

    static func shareItems(_ urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        #if os(macOS)
        guard let contentView = NSApp.keyWindow?.contentView else {
            return
        }

        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
        #elseif os(iOS)
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let presenter = topViewController() {
            controller.popoverPresentationController?.sourceView = presenter.view
            controller.popoverPresentationController?.sourceRect = presenter.view.bounds
            presenter.present(controller, animated: true)
        }
        #endif
    }

    static func copyFileURLsToPasteboard(_ urls: [URL]) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { $0 as NSURL })
        #elseif os(iOS)
        UIPasteboard.general.items = urls.map { [UTType.fileURL.identifier: $0.absoluteString] }
        #endif
    }

    static func readPasteboardFileURLs() -> [URL] {
        #if os(macOS)
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objects = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: options) ?? []
        return objects.compactMap { object in
            if let url = object as? URL {
                return url.standardizedFileURL
            }

            return (object as? NSURL).map { $0 as URL }?.standardizedFileURL
        }
        #elseif os(iOS)
        return UIPasteboard.general.items.compactMap { item in
            guard let value = item[UTType.fileURL.identifier] as? String else {
                return nil
            }

            return URL(string: value)?.standardizedFileURL
        }
        #else
        []
        #endif
    }

    static func copyTextToPasteboard(_ text: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = text
        #endif
    }

    #if os(iOS)
    private static func present(_ controller: UIViewController) {
        guard let presenter = topViewController() else {
            return
        }

        controller.popoverPresentationController?.sourceView = presenter.view
        controller.popoverPresentationController?.sourceRect = presenter.view.bounds
        presenter.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        return topViewController(from: root)
    }

    private static func topViewController(from controller: UIViewController?) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }

        if let tabBarController = controller as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }

        if let presented = controller?.presentedViewController {
            return topViewController(from: presented)
        }

        return controller
    }
    #endif
}

#if os(macOS)
private final class QuickLookDataSource: NSObject, QLPreviewPanelDataSource {
    var urls: [URL] = []

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        urls[index] as NSURL
    }
}

@MainActor
private let quickLookDataSource = QuickLookDataSource()
#elseif os(iOS)
private final class QuickLookDataSource: NSObject, QLPreviewControllerDataSource {
    var urls: [URL] = []

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        urls.count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
        urls[index] as NSURL
    }
}

@MainActor
private let quickLookDataSource = QuickLookDataSource()
#endif
