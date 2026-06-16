//
//  PopupPositioner.swift
//  Saypick
//
//  弹窗定位：优先选区屏幕矩形，兜底鼠标位置。AX(左上原点) → Cocoa(左下原点)。
//

import ApplicationServices
import AppKit

@MainActor
enum PopupPositioner {
    /// 返回锚点矩形（Cocoa 坐标，文字所在处）。
    static func anchorRect(element: AXUIElement?, range: CFRange?) -> NSRect {
        if let element, let axRect = boundsForSelection(element: element, range: range) {
            return cocoaRect(fromAX: axRect)
        }
        // 兜底：鼠标位置
        let m = NSEvent.mouseLocation
        return NSRect(x: m.x, y: m.y - 4, width: 1, height: 18)
    }

    private static func boundsForSelection(element: AXUIElement, range: CFRange?) -> CGRect? {
        if let range, range.length > 0 {
            var cfRange = range
            if let rangeValue = AXValueCreate(.cfRange, &cfRange) {
                var boundsValue: AnyObject?
                let err = AXUIElementCopyParameterizedAttributeValue(
                    element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeValue, &boundsValue)
                if err == .success, let boundsValue {
                    var rect = CGRect.zero
                    if AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect), rect.width > 0 || rect.height > 0 {
                        return rect
                    }
                }
            }
        }
        // 退化为整个元素的位置
        return elementFrame(element)
    }

    private static func elementFrame(_ element: AXUIElement) -> CGRect? {
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let posValue, let sizeValue else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// AX 矩形（左上原点）→ Cocoa 矩形（左下原点），支持多屏。
    static func cocoaRect(fromAX axRect: CGRect) -> NSRect {
        let globalMaxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? (NSScreen.main?.frame.height ?? 0)
        let cocoaY = globalMaxY - axRect.origin.y - axRect.size.height
        return NSRect(x: axRect.origin.x, y: cocoaY, width: axRect.size.width, height: axRect.size.height)
    }
}
