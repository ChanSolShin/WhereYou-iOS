import SwiftUI
import UIKit

/// A single owner for the transcript, composer and keyboard geometry.
struct ChatKeyboardLayout: UIViewControllerRepresentable {
    var messages: [MeetingChatMessage]
    var memberNames: [String: String]
    var currentUserID: String?
    var hasOlderMessages: Bool
    var isLoadingOlder: Bool
    var showsMessages: Bool
    var canCompose: Bool
    var composer: AnyView
    var emptyState: AnyView
    var messageRow: (MeetingChatMessage) -> AnyView
    var loadOlder: () -> Void
    var reachedLatest: () -> Void
    var dismissKeyboard: () -> Void

    func makeUIViewController(context: Context) -> ChatKeyboardController {
        ChatKeyboardController(content: self)
    }

    func updateUIViewController(_ controller: ChatKeyboardController, context: Context) {
        controller.update(content: self)
    }
}

final class ChatKeyboardController: UIViewController, UICollectionViewDelegate, UIGestureRecognizerDelegate {
    private enum Item: Hashable {
        case older
        case message(String)
    }

    private var content: ChatKeyboardLayout
    private let composerHost: UIHostingController<AnyView>
    private let emptyHost: UIHostingController<AnyView>
    private let transcript: ChatTranscriptCollectionView
    private var dataSource: UICollectionViewDiffableDataSource<Int, Item>!
    private var composerHeight: NSLayoutConstraint!

    init(content: ChatKeyboardLayout) {
        self.content = content
        composerHost = UIHostingController(rootView: content.composer)
        emptyHost = UIHostingController(rootView: content.emptyState)
        let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(88)))
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(88)), subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = .init(top: 12, leading: 16, bottom: 12, trailing: 16)
        transcript = ChatTranscriptCollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        transcript.backgroundColor = .clear
        transcript.accessibilityIdentifier = "chat-transcript"
        transcript.alwaysBounceVertical = true
        transcript.keyboardDismissMode = .interactive
        transcript.contentInsetAdjustmentBehavior = .never
        transcript.delegate = self
        transcript.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(transcript)
        embed(composerHost)
        embed(emptyHost)

        // Child SwiftUI hosts must not apply another keyboard safe area inside
        // the rectangle already supplied by UIKeyboardLayoutGuide.
        composerHost.safeAreaRegions = []
        emptyHost.safeAreaRegions = []
        composerHeight = composerHost.view.heightAnchor.constraint(equalToConstant: 60)
        NSLayoutConstraint.activate([
            composerHost.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            composerHost.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            composerHost.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            composerHeight,
            transcript.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            transcript.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            transcript.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            transcript.bottomAnchor.constraint(equalTo: composerHost.view.topAnchor),
            emptyHost.view.topAnchor.constraint(equalTo: transcript.topAnchor),
            emptyHost.view.bottomAnchor.constraint(equalTo: transcript.bottomAnchor),
            emptyHost.view.leadingAnchor.constraint(equalTo: transcript.leadingAnchor),
            emptyHost.view.trailingAnchor.constraint(equalTo: transcript.trailingAnchor)
        ])

        let cell = UICollectionView.CellRegistration<UICollectionViewCell, Item> { [weak self] cell, _, item in
            guard let self else { return }
            cell.backgroundConfiguration = .clear()
            cell.contentConfiguration = UIHostingConfiguration {
                self.row(for: item)
            }.margins(.all, 0)
        }
        dataSource = UICollectionViewDiffableDataSource<Int, Item>(collectionView: transcript) { collection, indexPath, item in
            collection.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: item)
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
        update(content: content, initial: true)
    }

    private func embed(_ host: UIHostingController<AnyView>) {
        addChild(host)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Measure at the actual available width, including multiline drafts and
        // Dynamic Type. No keyboard height or animation duration is guessed.
        measureComposer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if transcript.isAtLatest { content.reachedLatest() }
    }

    private func measureComposer() {
        let width = view.safeAreaLayoutGuide.layoutFrame.width
        guard width > 0 else { return }
        let height = content.canCompose
            ? ceil(composerHost.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height)
            : 0
        if abs(composerHeight.constant - height) > 0.5 { composerHeight.constant = height }
    }

    func update(content: ChatKeyboardLayout, initial: Bool = false) {
        let previous = self.content
        self.content = content
        guard isViewLoaded else { return }
        composerHost.rootView = content.composer
        emptyHost.rootView = content.emptyState
        composerHost.view.isHidden = !content.canCompose
        emptyHost.view.isHidden = content.showsMessages
        transcript.isHidden = !content.showsMessages
        measureComposer()

        let rowsChanged = initial || previous.messages != content.messages || previous.memberNames != content.memberNames
            || previous.hasOlderMessages != content.hasOlderMessages || previous.isLoadingOlder != content.isLoadingOlder
        guard rowsChanged else { return }

        let appended = previous.messages.last?.id != content.messages.last?.id
        if initial || previous.messages.isEmpty || (appended && content.messages.last?.senderID == content.currentUserID) {
            transcript.followsLatest = true
        }
        // Preserve the first visible message when loading earlier history.
        let anchor = transcript.indexPathsForVisibleItems.sorted().first.flatMap { path -> (Item, CGFloat)? in
            guard let item = dataSource.itemIdentifier(for: path),
                  let frame = transcript.layoutAttributesForItem(at: path)?.frame else { return nil }
            return (item, frame.minY - transcript.contentOffset.y)
        }
        let prepended = !previous.messages.isEmpty && previous.messages.first?.id != content.messages.first?.id && !appended
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        if content.hasOlderMessages { snapshot.appendItems([.older]) }
        snapshot.appendItems(content.messages.map { .message($0.id) })
        let existing = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { existing.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self else { return }
            self.transcript.layoutIfNeeded()
            if prepended, !self.transcript.followsLatest, let (item, distance) = anchor,
               let path = self.dataSource.indexPath(for: item),
               let frame = self.transcript.layoutAttributesForItem(at: path)?.frame {
                self.transcript.contentOffset.y = frame.minY - distance
            } else if self.transcript.followsLatest {
                self.transcript.showLatest()
            }
            if self.transcript.isAtLatest { self.content.reachedLatest() }
        }
    }

    @ViewBuilder
    private func row(for item: Item) -> some View {
        switch item {
        case .older:
            Button(action: content.loadOlder) {
                if content.isLoadingOlder { ProgressView() } else { Text("이전 메시지 보기") }
            }
            .disabled(content.isLoadingOlder)
        case .message(let id):
            if let message = content.messages.first(where: { $0.id == id }) {
                content.messageRow(message)
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isDragging || scrollView.isDecelerating {
            transcript.followsLatest = transcript.isAtLatest
        }
        if transcript.isAtLatest { content.reachedLatest() }
    }

    @objc private func dismissKeyboard() {
        content.dismissKeyboard()
        view.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // A tap on send, the text field, or its selection controls must stay intact.
        guard let touchedView = touch.view else { return false }
        return !touchedView.isDescendant(of: composerHost.view)
    }
}

// Local UI-test data uses the real tab controller and navigation containment,
// without requiring an account or reading/writing production conversations.
enum ChatKeyboardUITest {
    static var isEnabled: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--chat-keyboard-ui-test")
#else
        false
#endif
    }

#if DEBUG
    struct Entry: View {
        @Binding var isTabBarHidden: Bool
        var viaDetail: Bool

        var body: some View {
            NavigationStack {
                Group {
                    if viaDetail {
                        NavigationLink("모임 상세") {
                            NavigationLink("채팅방 열기") { room }
                                .navigationTitle("모임 상세")
                        }
                    } else {
                        NavigationLink("채팅방 열기") { room }
                    }
                }
                .navigationTitle(viaDetail ? "모임" : "채팅")
            }
        }

        private var room: some View {
            MeetingChatView(meetingID: "keyboard-ui-test", meetingTitle: "키보드 테스트")
                .onAppear { isTabBarHidden = true }
                .onDisappear { isTabBarHidden = false }
        }
    }
#endif
}

private final class ChatTranscriptCollectionView: UICollectionView {
    var followsLatest = true
    private var previousHeight: CGFloat = 0
    private var restoringOffset = false

    private var maximumOffset: CGFloat { max(0, contentSize.height - bounds.height) }
    var isAtLatest: Bool { maximumOffset - contentOffset.y <= 24 }

    override func layoutSubviews() {
        guard !restoringOffset else { super.layoutSubviews(); return }
        let oldOffset = contentOffset.y
        let oldHeight = previousHeight
        super.layoutSubviews()
        previousHeight = bounds.height
        guard bounds.height > 0 else { return }
        let resized = oldHeight > 0 && abs(oldHeight - bounds.height) > 0.5
        let shouldFollow = followsLatest && !isDragging && !isDecelerating
        if shouldFollow || resized {
            // This offset change participates in the keyboard's layout transaction.
            // Applying the inverse delta on dismissal prevents a permanent upward gap.
            let offset = shouldFollow ? maximumOffset : min(maximumOffset, max(0, oldOffset + oldHeight - bounds.height))
            restoringOffset = true
            contentOffset.y = offset
            restoringOffset = false
        }
    }

    func showLatest() {
        followsLatest = true
        guard numberOfSections > 0, numberOfItems(inSection: 0) > 0 else { return }
        scrollToItem(at: IndexPath(item: numberOfItems(inSection: 0) - 1, section: 0), at: .bottom, animated: false)
        setNeedsLayout()
        layoutIfNeeded()
    }
}
