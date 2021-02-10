//
// Copyright (c) Vatsal Manot
//

import Swift
import SwiftUI

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

public class UIHostingCollectionViewCell<ItemType, ItemIdentifierType: Hashable, Content: View>: UICollectionViewCell {
    public var parentViewController: UIViewController?
    public var indexPath: IndexPath?
    public var item: ItemType?
    public var itemID: ItemIdentifierType?
    public var makeContent: ((ItemType) -> Content)!
    
    var collectionViewController: (UICollectionViewController & UICollectionViewDelegateFlowLayout)? {
        parentViewController as? (UICollectionViewController & UICollectionViewDelegateFlowLayout)
    }
    
    var listRowPreferences: _ListRowPreferences?
    
    private var contentHostingController: UICollectionViewCellContentHostingController<ItemType, ItemIdentifierType, Content>?
    
    override public var isHighlighted: Bool {
        didSet {
            contentHostingController?.rootView.manager.isHighlighted = isHighlighted
        }
    }
    
    private var maximumSize: OptionalDimensions {
        guard let parentViewController = collectionViewController else {
            return nil
        }
        
        return OptionalDimensions(
            width: parentViewController.collectionView.contentSize.width - 0.001,
            height: parentViewController.collectionView.contentSize.height - 0.001
        )
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
        backgroundView = .init()
        contentView.backgroundColor = .clear
        contentView.bounds.origin = .zero
        layoutMargins = .zero
        selectedBackgroundView = .init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if let contentHostingController = contentHostingController {
            if contentHostingController.view.frame != contentView.bounds {
                contentHostingController.view.frame = contentView.bounds
                contentHostingController.view.setNeedsLayout()
            }
            
            contentHostingController.view.layoutIfNeeded()
        }
    }
    
    override public func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes.size = systemLayoutSizeFitting(layoutAttributes.size)
        
        return layoutAttributes
    }
    
    override public func prepareForReuse() {
        super.prepareForReuse()
        
        indexPath = nil
        isSelected = false
        listRowPreferences = nil
    }
    
    override public func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        guard let contentHostingController = contentHostingController else  {
            return CGSize(width: 1, height: 1)
        }
        
        contentHostingController.view.setNeedsLayout()
        contentHostingController.view.layoutIfNeeded()
        
        return contentHostingController._fixed_sizeThatFits(in: targetSize)
    }
    
    public func willDisplay() {
        attachContentHostingController()
    }
    
    public func didEndDisplaying() {
        detachContentHostingController()
    }
}

extension UIHostingCollectionViewCell {
    func attachContentHostingController() {
        if let contentHostingController = contentHostingController {
            contentHostingController.rootView.itemID = itemID
        } else {
            contentHostingController = UICollectionViewCellContentHostingController(base: self)
            
            contentHostingController?.view.backgroundColor = .clear
        }
        
        if contentHostingController?.parent == nil {
            contentHostingController!.willMove(toParent: parentViewController)
            parentViewController?.addChild(contentHostingController!)
            contentView.addSubview(contentHostingController!.view)
            contentHostingController!.view.frame = contentView.bounds
            contentHostingController!.didMove(toParent: parentViewController)
        }
    }
    
    func detachContentHostingController() {
        contentHostingController?.willMove(toParent: nil)
        contentHostingController?.view.removeFromSuperview()
        contentHostingController?.removeFromParent()
    }
}

extension UIHostingCollectionViewCell {
    public func reload() {
        guard let indexPath = indexPath else {
            return
        }
        
        invalidateIntrinsicContentSize()
        
        collectionViewController?.collectionView.reloadItems(at: [indexPath])
    }
}

// MARK: - Auxiliary Implementation -

extension String {
    static let hostingCollectionViewCellIdentifier = "UIHostingCollectionViewCell"
}

open class UICollectionViewCellContentHostingController<ItemType, ItemIdentifierType: Hashable, Content: View>: UIHostingController<UIHostingCollectionViewCell<ItemType, ItemIdentifierType, Content>.RootView> {
    unowned let base: UIHostingCollectionViewCell<ItemType, ItemIdentifierType, Content>
    
    init(base: UIHostingCollectionViewCell<ItemType, ItemIdentifierType, Content>) {
        self.base = base
        
        super.init(rootView: .init(base: base))
    }
    
    @objc required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UIHostingCollectionViewCell {
    public struct RootView: View {
        struct _ListRowManager: ListRowManager {
            weak var base: UIHostingCollectionViewCell<ItemType, ItemIdentifierType, Content>?
            
            var isHighlighted: Bool = false
            
            func _animate(_ action: () -> ()) {
                base?.collectionViewController?.collectionViewLayout.invalidateLayout()
            }
            
            func _reload() {
                base?.reload()
            }
        }
        
        var manager: _ListRowManager
        var itemID: ItemIdentifierType?
        
        init(base: UIHostingCollectionViewCell<ItemType, ItemIdentifierType, Content>?) {
            self.manager = .init(base: base)
        }
        
        public var body: some View {
            if let base = self.manager.base, let item = base.item {
                base.makeContent(item)
                    .environment(\.listRowManager, manager)
                    .onPreferenceChange(_ListRowPreferencesKey.self, perform: { base.listRowPreferences = $0 })
            }
        }
    }
}

#endif
