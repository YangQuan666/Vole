//
//  ReplyThreadOverlay.swift
//  Vole
//

import SwiftUI

/// 关闭评论浮层的方式。
enum ReplyThreadCloseRequest: Equatable {
    /// 直接关闭，浮起的回复落回原位置。
    case dismiss
    /// 关闭并回到指定回复所在的楼层。
    case jump(to: Int)
}

/// 记录回复在屏幕上的位置。引用类型，滚动时写入不会触发视图刷新。
final class ReplyFrameStore {
    var frames: [Int: CGRect] = [:]
}

/// 浮层与列表共享的交互状态。只由浮层和各行的 `replyLiftHidden` 读取，
/// 变化时不会重绘整个详情页。
@Observable
final class ReplyThreadState {
    /// 浮起到浮层、在列表中暂时隐藏的回复。
    var liftedReplyID: Int?
    /// 请求关闭浮层，由浮层播放关闭动画后处理。
    var closeRequest: ReplyThreadCloseRequest?
}

extension View {
    /// 回复浮起到浮层时，在列表中隐藏对应的行。
    func replyLiftHidden(_ replyID: Int, state: ReplyThreadState) -> some View {
        modifier(ReplyLiftHiddenModifier(replyID: replyID, state: state))
    }
}

private struct ReplyLiftHiddenModifier: ViewModifier {
    let replyID: Int
    let state: ReplyThreadState

    func body(content: Content) -> some View {
        content.opacity(state.liftedReplyID == replyID ? 0 : 1)
    }
}

/// 仿 iMessage 回复线程的评论浮层：背景模糊，被点按的回复从列表中浮起到浮层，
/// 其余回复依次淡入；关闭时回复落回列表中的位置。
struct ReplyThreadOverlay<Card: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let items: [ReplyConversationItem]
    /// 从列表中浮起的回复。
    let heroReplyID: Int?
    /// 与列表中回复内容等宽，保证浮起和落回时排版一致。
    let contentWidth: CGFloat?
    /// 列表中各回复的位置。
    let rowFrames: ReplyFrameStore
    let threadState: ReplyThreadState
    let onSelect: (ReplyConversationItem) -> Void
    /// 回复离开列表浮起时传入其 ID，列表据此隐藏对应的行；传入 nil 时恢复显示。
    let onLift: (Int?) -> Void
    let onClosed: () -> Void
    @ViewBuilder let card: (ReplyConversationItem) -> Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardFrames = ReplyFrameStore()
    @State private var offsets: [Int: CGSize] = [:]
    @State private var flyingReplyID: Int?
    @State private var isRevealed = false
    @State private var hasStarted = false
    @State private var isClosing = false

    private var openAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.32, bounce: 0.18)
    }

    private var closeAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.28, bounce: 0)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .opacity(isRevealed ? 1 : 0)
                .ignoresSafeArea()

            GeometryReader { container in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            header
                                .opacity(isRevealed ? 1 : 0)

                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                threadCard(item, index: index)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 24)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: container.size.height,
                            alignment: .top
                        )
                        .background {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { threadState.closeRequest = .dismiss }
                        }
                    }
                    .scrollClipDisabled()
                    .onAppear {
                        if let heroReplyID {
                            proxy.scrollTo(heroReplyID, anchor: .center)
                        }
                        // 浮起的回复未能测得位置时（如不在可视区域），直接淡入。
                        Task {
                            try? await Task.sleep(for: .milliseconds(80))
                            startOpening()
                        }
                    }
                }
            }
        }
        .accessibilityAction(.escape) { threadState.closeRequest = .dismiss }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: hasStarted) { _, started in
            started
        }
        .onChange(of: threadState.closeRequest) { _, request in
            if let request {
                close(request)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .labelStyle(.titleAndIcon)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private func threadCard(_ item: ReplyConversationItem, index: Int) -> some View {
        let id = item.reply.id
        let isVisible = isRevealed || id == flyingReplyID

        return card(item)
            .frame(width: contentWidth)
            .padding(.horizontal, contentWidth == nil ? 12 : 0)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                cardFrames.frames[id] = frame
                if id == heroReplyID, !hasStarted {
                    lift(id, cardFrame: frame)
                }
            }
            .onDisappear { cardFrames.frames[id] = nil }
            .background {
                // 气泡向外延伸，使回复内容与列表中的回复等宽。
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .padding(.horizontal, contentWidth == nil ? 0 : -12)
                    .opacity(isRevealed ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect(item) }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("返回第 \(item.floor + 1) 楼")
            .offset(offsets[id] ?? .zero)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.96)
            .offset(y: isVisible ? 0 : 16)
            .animation(cardAnimation(index: index, isFlying: id == flyingReplyID), value: isRevealed)
            .zIndex(id == flyingReplyID ? 1 : 0)
            .id(id)
    }

    /// 打开时其余回复依次出现；浮起的回复和关闭动画不加延迟。
    private func cardAnimation(index: Int, isFlying: Bool) -> Animation {
        guard isRevealed, !isFlying, !reduceMotion else {
            return isRevealed ? openAnimation : closeAnimation
        }
        return openAnimation.delay(Double(min(index, 6)) * 0.02)
    }

    /// 把浮起的回复先放到它在列表中的位置，再弹到浮层中的位置。
    private func lift(_ id: Int, cardFrame: CGRect) {
        guard !reduceMotion, let rowFrame = rowFrames.frames[id] else {
            startOpening()
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            offsets[id] = rowFrame.origin.distance(from: cardFrame.origin)
            flyingReplyID = id
        }
        onLift(id)
        startOpening()
    }

    private func startOpening() {
        guard !hasStarted else { return }
        hasStarted = true
        // 等待起始位置先渲染一帧，再开始动画。
        Task {
            withAnimation(openAnimation) {
                offsets = [:]
                isRevealed = true
            }
        }
    }

    private func close(_ request: ReplyThreadCloseRequest) {
        guard !isClosing else { return }
        isClosing = true

        let targetID: Int?
        switch request {
        case .dismiss:
            targetID = heroReplyID
        case .jump(let id):
            targetID = id
        }

        Task {
            if case .jump = request {
                // 等待列表滚动到目标楼层并完成布局。
                try? await Task.sleep(for: .milliseconds(60))
            }

            var landing: CGSize?
            if let targetID, !reduceMotion,
                let rowFrame = rowFrames.frames[targetID],
                let cardFrame = cardFrames.frames[targetID]
            {
                landing = rowFrame.origin.distance(from: cardFrame.origin)
            }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                flyingReplyID = landing == nil ? nil : targetID
            }
            if landing == nil {
                // 无法落回原位置时直接淡出，列表中的回复立即恢复显示。
                onLift(nil)
            }

            withAnimation(closeAnimation, completionCriteria: .logicallyComplete) {
                if let targetID, let landing {
                    offsets[targetID] = landing
                }
                isRevealed = false
            } completion: {
                onClosed()
            }
        }
    }
}

private extension CGPoint {
    /// 从 `origin` 移动到当前点所需的偏移量。
    func distance(from origin: CGPoint) -> CGSize {
        CGSize(width: x - origin.x, height: y - origin.y)
    }
}
