---
name: arch-mvc
description: "Use when implementing classic Apple MVC (Model-View-Controller) in iOS apps. Covers component responsibilities, communication patterns (target-action, delegate, NotificationCenter), Massive ViewController anti-pattern, when MVC is appropriate, and migration paths to MVVM or VIPER."
---

# MVC (Model-View-Controller) — Apple Flavor

The standard pattern of Apple's frameworks (UIKit, AppKit). The View is passive, the Model is independent, the Controller wires them together and handles events. Simple, but without discipline it quickly degenerates into a Massive ViewController.

> **Related skills:**
> - `arch-mvvm` — the next step as logic grows (extract business logic from the VC into a ViewModel)
> - `arch-coordinator` — extract navigation from the VC, orthogonal to MVC (you can use MVC + Coordinator)
> - `arch-clean`, `arch-viper` — for large projects with explicit layers

## When Appropriate

| Scenario | Use MVC |
|---|---|
| Prototype / proof-of-concept | ✅ |
| App with 1–3 screens and no serious business logic | ✅ |
| CRUD utility (form + list) | ✅ |
| Simple settings / preferences screen | ✅ |
| Learning project, demo | ✅ |
| App with 5+ screens and navigation between features | ⚠️ Consider MVVM+Coordinator |
| Reactive data streams, complex state | ❌ MVVM/VIPER/Clean |
| Team > 2 developers, active development > 6 months | ❌ MVVM/VIPER/Clean |

**Rule:** MVC is not a "simplified MVVM". It's a pattern with its own set of trade-offs. Don't be shy about using it for tasks where it fits, but don't drag it into a project that has clearly outgrown it either.

## Structure

```
Feature/
├── FeatureViewController.swift   # Controller
├── FeatureView.swift             # Custom UIView (optional)
├── Models/
│   ├── FeatureModel.swift        # Domain entity
│   └── FeatureModelStore.swift   # Stores/loads the model
└── Cells/
    └── FeatureItemCell.swift
```

## Component Responsibilities

### Model

- Pure data and domain logic
- No UIKit imports (`Foundation` is fine)
- No references to View or Controller
- Notifies about changes via `NotificationCenter`, KVO, delegate, or closure

```swift
struct Item {
    let id: UUID
    var title: String
    var isDone: Bool
}

final class ItemStore {
    private(set) var items: [Item] = []

    var onItemsChanged: (([Item]) -> Void)?

    func add(_ item: Item) {
        items.append(item)
        onItemsChanged?(items)
    }

    func toggle(itemId: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[idx].isDone.toggle()
        onItemsChanged?(items)
    }
}
```

### View

- Display only
- Does not know about the Model
- Reports user actions via target-action / delegate / closure
- Custom subviews are separate UIViews, not baked into the VC

```swift
final class ItemCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let checkmark = UIImageView()

    var onToggleTap: (() -> Void)?

    func configure(with item: Item) {
        titleLabel.text = item.title
        titleLabel.attributedText = item.isDone
            ? NSAttributedString(string: item.title, attributes: [.strikethroughStyle: 1])
            : NSAttributedString(string: item.title)
        checkmark.image = item.isDone ? UIImage(systemName: "checkmark.circle.fill") : UIImage(systemName: "circle")
    }

    @IBAction private func didTapCheckmark() {
        onToggleTap?()
    }
}
```

### Controller (UIViewController)

- Wires together Model and View
- Subscribes to Model changes, updates the View
- Receives View events, updates the Model
- Manages the screen lifecycle (`viewDidLoad`, `viewWillAppear`, ...)
- Coordinates transitions (or delegates to a Coordinator — see below)

```swift
final class ItemListViewController: UIViewController {

    private let store: ItemStore
    private let tableView = UITableView()

    init(store: ItemStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindStore()
    }

    private func setupUI() {
        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.register(ItemCell.self, forCellReuseIdentifier: "Item")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(didTapAdd)
        )
    }

    private func bindStore() {
        store.onItemsChanged = { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    @objc private func didTapAdd() {
        let alert = UIAlertController(title: "New item", message: nil, preferredStyle: .alert)
        alert.addTextField()
        alert.addAction(.init(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let title = alert?.textFields?.first?.text, !title.isEmpty else { return }
            self?.store.add(Item(id: UUID(), title: title, isDone: false))
        })
        present(alert, animated: true)
    }
}

extension ItemListViewController: UITableViewDataSource {
    func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        store.items.count
    }

    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "Item", for: indexPath) as! ItemCell
        let item = store.items[indexPath.row]
        cell.configure(with: item)
        cell.onToggleTap = { [weak self] in
            self?.store.toggle(itemId: item.id)
        }
        return cell
    }
}
```

## Communication Patterns

### View → Controller

| Method | When |
|---|---|
| **Target-action** | UIControl subclasses (UIButton, UISwitch). `addTarget(_:action:for:)` |
| **Delegate** | Complex subviews with many events (UITableView, UICollectionView, custom views) |
| **Closure** | Simple one-shot callback, especially in cells |
| **Notification** | Very rarely — when nothing else fits (system events: keyboard, app lifecycle) |

### Model → Controller

| Method | When |
|---|---|
| **Closure** (`onItemsChanged`) | Single observer, simple dependency |
| **Delegate** | Several distinct events, single observer |
| **NotificationCenter** | Multiple observers, loose coupling |
| **KVO / @Observable** | iOS 17+ — for plain observable fields. But that's already a step toward MVVM |

### Controller → Controller (navigation)

In pure MVC, the VC performs transitions itself:

```swift
private func showDetail(for item: Item) {
    let detailVC = ItemDetailViewController(item: item, store: store)
    navigationController?.pushViewController(detailVC, animated: true)
}
```

For projects with 4+ screens, **prefer using a Coordinator** (see `arch-coordinator` skill) — it does not contradict MVC and solves the problem of navigation logic spreading across controllers.

## Massive ViewController Anti-Pattern

Without discipline, the VC accumulates everything: data source, business logic, network requests, formatting, navigation, validation. Symptoms:

- VC > 500 lines
- > 5 responsibilities in one file (UI setup, data fetch, validation, navigation, formatting, ...)
- Hard to cover with tests — you have to spin up the UIKit stack
- Duplicated code between similar screens
- A change in one feature breaks a neighbor

### What to extract from the VC

| Responsibility | Where |
|---|---|
| Network requests, business logic | Service / Store / Repository |
| Complex formatting | Formatter / Presenter struct |
| TableView/CollectionView data source | Separate `UITableViewDataSource` class |
| Form validation | Validator struct |
| Navigation between features | Coordinator (see `arch-coordinator`) |
| Subscriptions / reactive streams | ViewModel — that's already a migration to MVVM |

Extracting a data source and a validator is **still MVC**. Extracting a ViewModel is **transitioning to MVVM**.

### Signals that MVC has run out of steam

- Any VC > 400 lines after data sources are extracted
- Business logic tests require spinning up the VC and UI
- Reactive streams (RxSwift / Combine / async/await) appear — the Controller can't handle binding
- A team of > 2 people is actively working on the same VC

→ Migrate to MVVM (see `arch-mvvm` skill) or MVVM+Coordinator (for larger apps).

## DI

The VC receives dependencies via init — no singletons, no `MyService.shared`.

```swift
final class ItemListViewController: UIViewController {
    private let store: ItemStore
    private let analytics: AnalyticsServiceProtocol

    init(store: ItemStore, analytics: AnalyticsServiceProtocol) {
        self.store = store
        self.analytics = analytics
        super.init(nibName: nil, bundle: nil)
    }
}
```

The graph is wired up by the Composition Root (see `di-composition-root` skill). For small MVC apps, manual DI without a container is enough.

Storyboard / XIB-based VCs don't allow init injection directly — for those, use either property injection after `instantiateViewController`, or switch to a programmatic init.

## Testing

### Testing the Model — easy

The Model is plain Swift; tests are ordinary:

```swift
final class ItemStoreTests: XCTestCase {
    func test_add_appendsItemAndNotifies() {
        let store = ItemStore()
        var receivedItems: [Item]?
        store.onItemsChanged = { receivedItems = $0 }

        store.add(Item(id: UUID(), title: "Test", isDone: false))

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(receivedItems?.count, 1)
    }
}
```

### Testing the Controller — harder

If the Controller contains business logic, you can't test it without spinning up the VC and UI. That's the price of MVC. Ways to mitigate:

- Extract the logic into separate classes (Validator, Formatter, Store) — tests there are easy
- Don't test the Controller itself — leave it to UI tests or snapshot tests
- If you want to unit-test Controller logic — that's a signal it's time to move to MVVM

## Migration Paths

### MVC → MVVM (gradually)

1. Create a `FeatureViewModel` next to the VC, leave the VC in place
2. Move business logic and event handling from the VC into the ViewModel
3. The VC receives `viewModel: FeatureViewModel` in init and delegates actions to it
4. Subscribe to ViewModel changes (closure / Combine / async stream — see `arch-mvvm`)
5. Strip the VC down to UI code only

### MVC → MVC + Coordinator

1. Extract `pushViewController` / `present` from the VC into the Coordinator
2. The VC reports the navigation intent to the Coordinator via delegate / closure
3. The Coordinator decides where to go
4. See `arch-coordinator` skill

These migrations are **independent** — you can extract the Coordinator first, then the ViewModel, or vice versa.

## Common Mistakes

1. **Massive ViewController** — the primary problem. Apply extract strategies before the VC balloons
2. **VC knows about concrete services** — `URLSession.shared.dataTask(...)` inside a VC = untestable. Use DI and protocols
3. **Model imports UIKit** — kills portability and tests. Formatting with `UIColor`, `UIImage` belongs in the VC or a separate Presenter
4. **Singletons for inter-VC communication** — `AppState.shared`. That's not MVC, it's global state. Use DI
5. **Storyboard segues for all navigation** — loses type safety of transition parameters. For anything beyond the very simplest cases, programmatic push/present is better
6. **Direct references between VCs** — `let parentVC = parent as? ParentVC`. Use delegate or closure instead
7. **Business logic in `prepare(for segue:)`** — the segue should only pass the model to the next VC, not compute it
