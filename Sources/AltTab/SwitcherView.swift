import SwiftUI

struct SwitcherView: View {
    @ObservedObject var model: SwitcherViewModel

    private let minListWidth: CGFloat = 320
    private let maxVisibleRows = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                            WindowRow(
                                window: window,
                                isSelected: index == model.selectedIndex,
                                folderWidth: folderColumnWidth
                            )
                                .id(index)
                                .onTapGesture { model.onCommit?(index) }
                                .onHover { hovering in
                                    if hovering { model.selectedIndex = index }
                                }
                        }
                    }
                }
                .frame(height: rowsHeight)
                .onChange(of: model.selectedIndex) { newIndex in
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newIndex)
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: minListWidth, alignment: .leading)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var header: some View {
        if let first = model.windows.first {
            HStack(spacing: 6) {
                if let icon = first.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                }
                Text(first.appName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }

    /// Width of the leading folder column: the widest folder name in the list,
    /// so every title starts on the same x. Zero when no window reports a folder.
    private var folderColumnWidth: CGFloat {
        let widest = model.windows
            .compactMap(\.folder)
            .map { ($0 as NSString).size(withAttributes: [.font: WindowRow.folderFont]).width }
            .max() ?? 0
        return widest == 0 ? 0 : min(ceil(widest), 150)
    }

    private var rowsHeight: CGFloat {
        let rowHeight: CGFloat = 30 + 2 // row + spacing
        let visible = min(model.windows.count, maxVisibleRows)
        return max(CGFloat(visible) * rowHeight - 2, rowHeight - 2)
    }
}

private struct WindowRow: View {
    static let folderFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)

    let window: SwitcherWindow
    let isSelected: Bool
    /// Shared width of the leading folder column, so titles line up across rows.
    let folderWidth: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            if folderWidth > 0 {
                Text(window.folder ?? "")
                    .font(Font(WindowRow.folderFont))
                    .lineLimit(1)
                    .truncationMode(.head) // keep the tail, it is the distinctive part
                    .foregroundColor(.primary.opacity(isSelected ? 0.55 : 0.35))
                    .frame(width: folderWidth, alignment: .trailing)

                Rectangle()
                    .fill(Color.primary.opacity(isSelected ? 0.2 : 0.12))
                    .frame(width: 1, height: 16)
            }
            if let icon = window.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            Text(window.displayTitle)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false) // size to full title, never truncate
                .foregroundColor(isSelected ? .primary : .secondary)
            Spacer(minLength: 12)
            if window.isMinimized {
                Image(systemName: "minus.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
