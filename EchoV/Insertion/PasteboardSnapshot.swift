import AppKit

struct PasteboardSnapshot: @unchecked Sendable {
    private let items: [NSPasteboardItem]

    init(pasteboard: NSPasteboard = .general) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                } else if let string = item.string(forType: type) {
                    copy.setString(string, forType: type)
                }
            }
            return copy
        }
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }
}
