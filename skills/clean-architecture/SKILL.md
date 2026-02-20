---
name: clean-architecture
description: "Use when implementing Clean Architecture in iOS apps. Covers Domain/Data/Presentation layers, Use Cases, Repository pattern, DTOs, dependency rule, and testing each layer."
---

# Clean Architecture for iOS

Uncle Bob's layered architecture adapted for iOS. Strict dependency rules ensure business logic is independent of frameworks, UI, and external services.

## Structure

```
Feature/
├── Presentation/
│   ├── FeatureViewController.swift
│   ├── FeatureViewModel.swift
│   └── Views/
│       └── FeatureItemCell.swift
├── Domain/
│   ├── UseCases/
│   │   ├── GetItemsUseCase.swift
│   │   └── UpdateItemUseCase.swift
│   ├── Entities/
│   │   └── Item.swift
│   └── Repositories/
│       └── ItemRepositoryProtocol.swift  # Interface only
└── Data/
    ├── Repositories/
    │   └── ItemRepositoryImpl.swift
    ├── DataSources/
    │   ├── ItemRemoteDataSource.swift
    │   └── ItemLocalDataSource.swift
    └── DTOs/
        └── ItemDTO.swift
```

## Dependency Rule

Dependencies point **inward only**:

```
Presentation → Domain ← Data
```

- **Domain** knows nothing about Presentation or Data
- **Presentation** depends on Domain (UseCases, Entities)
- **Data** depends on Domain (implements Repository interfaces)
- **Data** never imports Presentation
- **Presentation** never imports Data directly

## Layers

### Domain Layer (innermost — no dependencies)

Pure business logic. No UIKit, no frameworks, no third-party imports.

#### Entity

```swift
// Domain/Entities/Item.swift
struct Item {
    let id: String
    let title: String
    let description: String
    let status: ItemStatus
    let createdAt: Date
}

enum ItemStatus {
    case active
    case archived
    case deleted
}
```

#### Repository Protocol (interface only)

```swift
// Domain/Repositories/ItemRepositoryProtocol.swift
protocol ItemRepositoryProtocol {
    func getItems() -> Single<[Item]>
    func getItem(id: String) -> Single<Item>
    func save(_ item: Item) -> Completable
    func delete(id: String) -> Completable
}
```

#### Use Case

Single responsibility — one business operation per use case.

```swift
// Domain/UseCases/GetItemsUseCase.swift
protocol GetItemsUseCaseProtocol {
    func execute() -> Single<[Item]>
}

class GetItemsUseCase: GetItemsUseCaseProtocol {
    private let repository: ItemRepositoryProtocol

    init(repository: ItemRepositoryProtocol) {
        self.repository = repository
    }

    func execute() -> Single<[Item]> {
        repository.getItems()
            .map { items in
                items.filter { $0.status == .active }
                    .sorted { $0.createdAt > $1.createdAt }
            }
    }
}

// Domain/UseCases/UpdateItemUseCase.swift
protocol UpdateItemUseCaseProtocol {
    func execute(id: String, title: String, description: String) -> Completable
}

class UpdateItemUseCase: UpdateItemUseCaseProtocol {
    private let repository: ItemRepositoryProtocol

    init(repository: ItemRepositoryProtocol) {
        self.repository = repository
    }

    func execute(id: String, title: String, description: String) -> Completable {
        guard !title.isEmpty else {
            return .error(ValidationError.emptyTitle)
        }

        return repository.getItem(id: id)
            .map { item in
                Item(
                    id: item.id,
                    title: title,
                    description: description,
                    status: item.status,
                    createdAt: item.createdAt
                )
            }
            .flatMapCompletable { [repository] updatedItem in
                repository.save(updatedItem)
            }
    }
}
```

### Data Layer (implements Domain interfaces)

#### DTO (Data Transfer Object)

Maps between external formats and Domain entities:

```swift
// Data/DTOs/ItemDTO.swift
struct ItemDTO: Codable {
    let id: String
    let title: String
    let description: String
    let status: String
    let created_at: String

    func toDomain() -> Item {
        Item(
            id: id,
            title: title,
            description: description,
            status: ItemStatus(rawValue: status) ?? .active,
            createdAt: DateFormatter.iso8601.date(from: created_at) ?? Date()
        )
    }

    static func fromDomain(_ item: Item) -> ItemDTO {
        ItemDTO(
            id: item.id,
            title: item.title,
            description: item.description,
            status: item.status.rawValue,
            created_at: DateFormatter.iso8601.string(from: item.createdAt)
        )
    }
}
```

#### Data Sources

```swift
// Data/DataSources/ItemRemoteDataSource.swift
protocol ItemRemoteDataSourceProtocol {
    func fetchItems() -> Single<[ItemDTO]>
    func fetchItem(id: String) -> Single<ItemDTO>
    func update(_ dto: ItemDTO) -> Completable
    func delete(id: String) -> Completable
}

class ItemRemoteDataSource: ItemRemoteDataSourceProtocol {
    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func fetchItems() -> Single<[ItemDTO]> {
        networkService.request(endpoint: .items, method: .get)
    }

    // ...
}

// Data/DataSources/ItemLocalDataSource.swift
protocol ItemLocalDataSourceProtocol {
    func getCachedItems() -> Single<[ItemDTO]>
    func cache(_ items: [ItemDTO]) -> Completable
}
```

#### Repository Implementation

```swift
// Data/Repositories/ItemRepositoryImpl.swift
class ItemRepositoryImpl: ItemRepositoryProtocol {
    private let remote: ItemRemoteDataSourceProtocol
    private let local: ItemLocalDataSourceProtocol

    init(remote: ItemRemoteDataSourceProtocol, local: ItemLocalDataSourceProtocol) {
        self.remote = remote
        self.local = local
    }

    func getItems() -> Single<[Item]> {
        remote.fetchItems()
            .do(onSuccess: { [local] dtos in
                local.cache(dtos).subscribe().disposed(by: disposeBag)
            })
            .catch { [local] _ in
                local.getCachedItems()  // Fallback to cache
            }
            .map { dtos in dtos.map { $0.toDomain() } }
    }

    func getItem(id: String) -> Single<Item> {
        remote.fetchItem(id: id)
            .map { $0.toDomain() }
    }

    func save(_ item: Item) -> Completable {
        let dto = ItemDTO.fromDomain(item)
        return remote.update(dto)
    }

    func delete(id: String) -> Completable {
        remote.delete(id: id)
    }
}
```

### Presentation Layer

ViewModel depends on UseCases (not Repository directly):

```swift
// Presentation/FeatureViewModel.swift
class FeatureViewModel {
    private let getItemsUseCase: GetItemsUseCaseProtocol
    private let updateItemUseCase: UpdateItemUseCaseProtocol
    private let disposeBag = DisposeBag()

    // Outputs
    let items: Driver<[ItemCellModel]>
    let isLoading: Driver<Bool>
    let error: Signal<String>

    // Navigation
    var onItemSelected: ((Item) -> Void)?

    init(
        getItemsUseCase: GetItemsUseCaseProtocol,
        updateItemUseCase: UpdateItemUseCaseProtocol
    ) {
        self.getItemsUseCase = getItemsUseCase
        self.updateItemUseCase = updateItemUseCase
        // ... setup bindings
    }
}
```

## DI Registration

```swift
class DomainAssembly: Assembly {
    func assemble(container: Container) {
        // Use Cases
        container.register(GetItemsUseCaseProtocol.self) { r in
            GetItemsUseCase(repository: r.resolve(ItemRepositoryProtocol.self)!)
        }

        container.register(UpdateItemUseCaseProtocol.self) { r in
            UpdateItemUseCase(repository: r.resolve(ItemRepositoryProtocol.self)!)
        }
    }
}

class DataAssembly: Assembly {
    func assemble(container: Container) {
        // Data Sources
        container.register(ItemRemoteDataSourceProtocol.self) { r in
            ItemRemoteDataSource(networkService: r.resolve(NetworkServiceProtocol.self)!)
        }

        container.register(ItemLocalDataSourceProtocol.self) { _ in
            ItemLocalDataSource()
        }

        // Repository (binds Domain interface to Data implementation)
        container.register(ItemRepositoryProtocol.self) { r in
            ItemRepositoryImpl(
                remote: r.resolve(ItemRemoteDataSourceProtocol.self)!,
                local: r.resolve(ItemLocalDataSourceProtocol.self)!
            )
        }.inObjectScope(.container)
    }
}

class PresentationAssembly: Assembly {
    func assemble(container: Container) {
        container.register(FeatureViewModel.self) { r in
            FeatureViewModel(
                getItemsUseCase: r.resolve(GetItemsUseCaseProtocol.self)!,
                updateItemUseCase: r.resolve(UpdateItemUseCaseProtocol.self)!
            )
        }
    }
}
```

## Testing

### Use Case Tests (pure logic, no mocks for frameworks)

```swift
class GetItemsUseCaseTests: XCTestCase {
    func testExecute_filtersArchivedItems() throws {
        let mockRepo = MockItemRepository()
        mockRepo.stubbedItems = [
            Item(id: "1", title: "Active", status: .active, ...),
            Item(id: "2", title: "Archived", status: .archived, ...),
        ]
        let sut = GetItemsUseCase(repository: mockRepo)

        let result = try sut.execute().toBlocking().single()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "1")
    }

    func testExecute_sortsByDateDescending() throws {
        let mockRepo = MockItemRepository()
        mockRepo.stubbedItems = [
            Item(id: "old", createdAt: Date(timeIntervalSinceNow: -100), ...),
            Item(id: "new", createdAt: Date(), ...),
        ]
        let sut = GetItemsUseCase(repository: mockRepo)

        let result = try sut.execute().toBlocking().single()

        XCTAssertEqual(result.first?.id, "new")
    }
}
```

### Repository Tests

```swift
class ItemRepositoryImplTests: XCTestCase {
    func testGetItems_remoteFails_fallsBackToCache() throws {
        let mockRemote = MockRemoteDataSource()
        mockRemote.shouldFail = true
        let mockLocal = MockLocalDataSource()
        mockLocal.cachedItems = [ItemDTO(id: "cached", ...)]

        let sut = ItemRepositoryImpl(remote: mockRemote, local: mockLocal)
        let result = try sut.getItems().toBlocking().single()

        XCTAssertEqual(result.first?.id, "cached")
    }
}
```

## When Appropriate

- Large apps with complex domain logic
- Shared business logic across platforms (iOS + macOS)
- Long-lived projects (5+ years)
- Domain-driven design approach
- Multiple teams working in parallel

## Common Mistakes

1. **Skipping Use Cases** — going directly from ViewModel to Repository. Use Cases are where business rules live.
2. **Domain importing Data** — Domain must have zero external dependencies. Repository protocols live in Domain, implementations in Data.
3. **DTOs leaking into Domain** — always map DTO → Entity at repository boundary.
4. **One Use Case per CRUD** — don't create `GetItemsUseCase`, `GetItemUseCase`, `SaveItemUseCase` if they have no business logic. Group trivial operations or use Repository directly.
5. **Over-engineering simple features** — not every screen needs full Clean Architecture. Simple screens can use MVVM.
