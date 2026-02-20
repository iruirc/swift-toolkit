---
name: mvvm
description: "Use when implementing MVVM (Model-View-ViewModel) architecture pattern in iOS apps. Covers ViewModel design, UI binding, Input/Output pattern, and testing."
---

# MVVM (Model-View-ViewModel) Architecture

Separates business logic into a testable ViewModel, keeping ViewController as a thin UI binding layer.

## Structure

```
Feature/
├── FeatureViewController.swift  # UI binding only
├── FeatureViewModel.swift       # Business logic + state
└── Models/
    └── FeatureModel.swift
```

## Component Responsibilities

### Model
- Data structures and business entities
- Persistence and network DTOs
- Pure data — no UIKit, no reactive types

### ViewModel

**Purpose**: Holds business logic, processes user actions, exposes state for View binding.

**Rules**:
- No UIKit imports (except value types like `CGFloat` if unavoidable)
- No reference to ViewController
- All dependencies injected via init
- Define a protocol for testability

```swift
protocol FeatureViewModelProtocol {
    // Inputs
    func viewDidLoad()
    func didSelectItem(at index: Int)
    func didTapRetry()

    // Outputs — choose ONE binding style per project
    // RxSwift:
    var items: Driver<[ItemCellModel]> { get }
    var isLoading: Driver<Bool> { get }
    var error: Signal<String> { get }

    // Navigation signals
    var onItemSelected: ((Item) -> Void)? { get set }
}

class FeatureViewModel: FeatureViewModelProtocol {
    private let service: FeatureServiceProtocol
    private let disposeBag = DisposeBag()

    // Subjects (internal state)
    private let itemsRelay = BehaviorRelay<[Item]>(value: [])
    private let loadingRelay = BehaviorRelay<Bool>(value: false)
    private let errorRelay = PublishRelay<String>()

    // Outputs
    var items: Driver<[ItemCellModel]> {
        itemsRelay
            .map { $0.map(ItemCellModel.init) }
            .asDriver(onErrorJustReturn: [])
    }
    var isLoading: Driver<Bool> { loadingRelay.asDriver() }
    var error: Signal<String> { errorRelay.asSignal() }

    // Navigation
    var onItemSelected: ((Item) -> Void)?

    init(service: FeatureServiceProtocol) {
        self.service = service
    }

    func viewDidLoad() {
        loadData()
    }

    func didSelectItem(at index: Int) {
        let item = itemsRelay.value[index]
        onItemSelected?(item)
    }

    func didTapRetry() {
        loadData()
    }

    private func loadData() {
        loadingRelay.accept(true)
        service.fetchItems()
            .subscribe(
                onSuccess: { [weak self] items in
                    self?.loadingRelay.accept(false)
                    self?.itemsRelay.accept(items)
                },
                onFailure: { [weak self] error in
                    self?.loadingRelay.accept(false)
                    self?.errorRelay.accept(error.localizedDescription)
                }
            )
            .disposed(by: disposeBag)
    }
}
```

### ViewController

**Purpose**: Thin UI layer. Binds ViewModel outputs to UI, forwards user actions to ViewModel inputs.

```swift
class FeatureViewController: UIViewController {
    private let viewModel: FeatureViewModelProtocol
    private let disposeBag = DisposeBag()

    // UI elements
    private let tableView = UITableView()
    private let loadingIndicator = UIActivityIndicatorView()

    init(viewModel: FeatureViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.viewDidLoad()
    }

    private func bindViewModel() {
        // Outputs → UI
        viewModel.items
            .drive(tableView.rx.items(cellIdentifier: "Cell")) { _, model, cell in
                cell.configure(with: model)
            }
            .disposed(by: disposeBag)

        viewModel.isLoading
            .drive(loadingIndicator.rx.isAnimating)
            .disposed(by: disposeBag)

        viewModel.error
            .emit(onNext: { [weak self] message in
                self?.showErrorAlert(message)
            })
            .disposed(by: disposeBag)

        // User actions → ViewModel
        tableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.viewModel.didSelectItem(at: indexPath.row)
            })
            .disposed(by: disposeBag)
    }
}
```

## Input/Output Pattern (Alternative)

For ViewModels where all bindings are set up in init:

```swift
class FeatureViewModel {
    struct Input {
        let viewDidLoad: Observable<Void>
        let itemSelected: Observable<IndexPath>
        let refresh: Observable<Void>
    }

    struct Output {
        let items: Driver<[ItemCellModel]>
        let isLoading: Driver<Bool>
        let error: Signal<String>
    }

    func transform(input: Input) -> Output {
        let loading = BehaviorRelay<Bool>(value: false)
        let errorRelay = PublishRelay<String>()

        let items = Observable.merge(input.viewDidLoad, input.refresh)
            .do(onNext: { loading.accept(true) })
            .flatMapLatest { [service] _ in
                service.fetchItems()
                    .catch { error in
                        errorRelay.accept(error.localizedDescription)
                        return .just([])
                    }
            }
            .do(onNext: { _ in loading.accept(false) })
            .map { $0.map(ItemCellModel.init) }
            .asDriver(onErrorJustReturn: [])

        return Output(
            items: items,
            isLoading: loading.asDriver(),
            error: errorRelay.asSignal()
        )
    }
}
```

## ViewModel Rules Summary

| Do | Don't |
|----|-------|
| Define protocol | Import UIKit |
| Inject all dependencies | Reference ViewController |
| Use reactive outputs | Call `present`/`push` directly |
| Keep state private | Expose mutable subjects |
| Transform data for display | Return raw models to View |

## Testing ViewModel

```swift
class FeatureViewModelTests: XCTestCase {
    var sut: FeatureViewModel!
    var mockService: MockFeatureService!

    override func setUp() {
        mockService = MockFeatureService()
        sut = FeatureViewModel(service: mockService)
    }

    func testViewDidLoad_fetchesItems() {
        mockService.stubbedItems = [Item(id: "1")]

        sut.viewDidLoad()

        let items = try! sut.items.toBlocking().first()
        XCTAssertEqual(items?.count, 1)
    }

    func testViewDidLoad_showsLoading() {
        var states: [Bool] = []
        sut.isLoading
            .drive(onNext: { states.append($0) })
            .disposed(by: disposeBag)

        sut.viewDidLoad()

        XCTAssertEqual(states, [false, true, false])
    }

    func testDidSelectItem_signalsNavigation() {
        var selectedItem: Item?
        sut.onItemSelected = { selectedItem = $0 }
        mockService.stubbedItems = [Item(id: "42")]
        sut.viewDidLoad()

        sut.didSelectItem(at: 0)

        XCTAssertEqual(selectedItem?.id, "42")
    }
}
```

## When Appropriate

- Apps with testable business logic requirements
- Screens with multiple data sources or complex state
- Reactive programming (RxSwift/Combine) projects
- Teams of 2+ developers

## When to Add Coordinator

If navigation becomes complex (conditional flows, deep links, reusable screens), add the `coordinator` pattern on top. See `coordinator` skill.
