---
name: swinject
description: "Use when working with Swinject dependency injection in iOS apps. Covers container setup, object scopes, Assembly pattern, auto-registration, ViewModel factories, and testing configuration."
---

# Swinject Dependency Injection Patterns

This skill provides guidelines for using Swinject effectively in iOS applications.

## When to Use

**Swinject is the right choice when**:
- Need runtime dependency injection
- Want constructor injection with automatic resolution
- Building modular apps with swappable implementations
- Need different configurations for production/testing
- Complex dependency graphs

**Consider alternatives**:
- Simple apps → Manual DI (pass dependencies in init)
- SwiftUI apps → Environment objects
- Compile-time safety priority → Factory pattern

## Core Concepts

### Container Setup

```swift
import Swinject
import SwinjectAutoregistration

class DIContainer {
    static let shared = DIContainer()
    let container: Container

    private init() {
        container = Container()
        registerServices()
        registerViewModels()
        registerCoordinators()
    }

    private func registerServices() {
        // Services go here
    }

    private func registerViewModels() {
        // ViewModels go here
    }

    private func registerCoordinators() {
        // Coordinators go here
    }
}
```

### Basic Registration

```swift
// Register with explicit factory
container.register(UserServiceProtocol.self) { _ in
    UserService()
}

// Register with dependencies
container.register(ProfileViewModelProtocol.self) { r in
    ProfileViewModel(
        userService: r.resolve(UserServiceProtocol.self)!,
        analyticsService: r.resolve(AnalyticsServiceProtocol.self)!
    )
}
```

### Auto-registration

Using `SwinjectAutoregistration` for cleaner syntax:

```swift
// Auto-resolve dependencies
container.autoregister(ProfileViewModel.self, initializer: ProfileViewModel.init)

// With protocol
container.autoregister(
    ProfileViewModelProtocol.self,
    initializer: ProfileViewModel.init
)
```

## Object Scopes

### `.transient` (Default)

New instance every time. Use for stateful objects.

```swift
container.register(FeatureViewModel.self) { r in
    FeatureViewModel(service: r.resolve(ServiceProtocol.self)!)
}
// Each resolve() creates new instance
```

**Use for**:
- ViewModels (each screen needs fresh state)
- Coordinators (each flow is independent)
- Stateful helpers

### `.container` (Singleton)

Single instance for container lifetime. Use for stateless services.

```swift
container.register(NetworkServiceProtocol.self) { _ in
    NetworkService()
}.inObjectScope(.container)
// Same instance returned every time
```

**Use for**:
- Network clients
- Database managers
- Analytics services
- App settings
- Caches

### `.weak`

Shared while retained, recreated when released.

```swift
container.register(CacheProtocol.self) { _ in
    ImageCache()
}.inObjectScope(.weak)
// Shared if someone holds reference, otherwise recreated
```

**Use for**:
- Optional shared caches
- Resources that can be recreated
- Memory-sensitive singletons

### `.graph` (Default for auto-registration)

Same instance within single resolution graph, new for each top-level resolve.

```swift
container.autoregister(SharedState.self, initializer: SharedState.init)
    .inObjectScope(.graph)

// If A and B both depend on SharedState:
// resolve(A.self) and resolve(B.self) → different SharedState
// But A and B resolved together share same SharedState
```

**Use for**:
- Shared state within a feature but not globally
- Request-scoped objects

## Registration Patterns

### Protocol-Based Registration

Always register protocols, not concrete types:

```swift
// Correct
container.register(UserServiceProtocol.self) { _ in
    UserService()
}

// Avoid
container.register(UserService.self) { _ in
    UserService()
}
```

### Named Registrations

When multiple implementations of same protocol exist:

```swift
container.register(APIClientProtocol.self, name: "production") { _ in
    ProductionAPIClient()
}

container.register(APIClientProtocol.self, name: "staging") { _ in
    StagingAPIClient()
}

// Resolve by name
let client = container.resolve(APIClientProtocol.self, name: "production")!
```

### Registrations with Arguments

When instance needs runtime parameters:

```swift
container.register(DetailViewModel.self) { (r, itemId: String) in
    DetailViewModel(
        itemId: itemId,
        service: r.resolve(ItemServiceProtocol.self)!
    )
}

// Resolve with argument
let viewModel = container.resolve(DetailViewModel.self, argument: "item-123")!
```

### Multiple Arguments

```swift
container.register(ChatViewModel.self) { (r, roomId: String, userId: String) in
    ChatViewModel(
        roomId: roomId,
        userId: userId,
        chatService: r.resolve(ChatServiceProtocol.self)!
    )
}

// Resolve
let viewModel = container.resolve(
    ChatViewModel.self,
    arguments: "room-1", "user-42"
)!
```

## Assembly Pattern

Organize registrations by feature using Assemblies:

```swift
class ServicesAssembly: Assembly {
    func assemble(container: Container) {
        container.register(NetworkServiceProtocol.self) { _ in
            NetworkService()
        }.inObjectScope(.container)

        container.register(DatabaseServiceProtocol.self) { _ in
            DatabaseService()
        }.inObjectScope(.container)
    }
}

class ProfileAssembly: Assembly {
    func assemble(container: Container) {
        container.autoregister(
            ProfileViewModelProtocol.self,
            initializer: ProfileViewModel.init
        )

        container.register(ProfileCoordinator.self) { (r, router: Router) in
            ProfileCoordinator(router: router, container: r)
        }
    }
}

// In DIContainer
let assembler = Assembler([
    ServicesAssembly(),
    ProfileAssembly(),
    SettingsAssembly(),
    // ... more assemblies
])
let container = assembler.resolver
```

## Coordinator Registration Pattern

Coordinators need Router and Container access:

```swift
container.register(FeatureCoordinator.self) { (r, router: Router) in
    FeatureCoordinator(
        router: router,
        container: r as! Container  // Pass container for child resolution
    )
}

// In parent coordinator
func showFeature() {
    let coordinator = container.resolve(
        FeatureCoordinator.self,
        argument: router
    )!
    addChild(coordinator)
    coordinator.start()
}
```

## ViewModel Factory Pattern

For ViewModels that need runtime data:

```swift
protocol ViewModelFactory {
    func makeDetailViewModel(itemId: String) -> DetailViewModelProtocol
    func makeEditViewModel(item: Item) -> EditViewModelProtocol
}

class ViewModelFactoryImpl: ViewModelFactory {
    private let container: Resolver

    init(container: Resolver) {
        self.container = container
    }

    func makeDetailViewModel(itemId: String) -> DetailViewModelProtocol {
        container.resolve(DetailViewModelProtocol.self, argument: itemId)!
    }

    func makeEditViewModel(item: Item) -> EditViewModelProtocol {
        container.resolve(EditViewModelProtocol.self, argument: item)!
    }
}

// Register factory
container.register(ViewModelFactory.self) { r in
    ViewModelFactoryImpl(container: r)
}.inObjectScope(.container)
```

## Testing Configuration

### Test Container

```swift
class TestDIContainer {
    static func makeContainer() -> Container {
        let container = Container()

        // Register mocks
        container.register(NetworkServiceProtocol.self) { _ in
            MockNetworkService()
        }

        container.register(DatabaseServiceProtocol.self) { _ in
            InMemoryDatabase()
        }

        // Real implementations that are safe for tests
        container.autoregister(
            ProfileViewModel.self,
            initializer: ProfileViewModel.init
        )

        return container
    }
}

// In tests
class ProfileViewModelTests: XCTestCase {
    var container: Container!

    override func setUp() {
        container = TestDIContainer.makeContainer()
    }

    func testProfile() {
        let viewModel = container.resolve(ProfileViewModel.self)!
        // Test with mocked dependencies
    }
}
```

### Override Specific Dependencies

```swift
func testWithCustomMock() {
    // Start with test container
    let container = TestDIContainer.makeContainer()

    // Override specific dependency
    container.register(NetworkServiceProtocol.self) { _ in
        MockNetworkService(shouldFail: true)
    }

    let viewModel = container.resolve(ProfileViewModel.self)!
    // Test error handling
}
```

## Common Mistakes

### 1. Force Unwrapping Without Registration

```swift
// Crashes if not registered
let service = container.resolve(ServiceProtocol.self)!

// Defensive approach
guard let service = container.resolve(ServiceProtocol.self) else {
    fatalError("ServiceProtocol not registered")
}
```

### 2. Wrong Scope Selection

```swift
// ViewModel as singleton - shares state between screens!
container.register(FeatureViewModel.self) { ... }
    .inObjectScope(.container)

// ViewModel as transient - fresh state each time
container.register(FeatureViewModel.self) { ... }
    .inObjectScope(.transient)  // or omit (default)
```

### 3. Circular Dependencies

```swift
// A needs B, B needs A → crash
container.register(A.self) { r in A(b: r.resolve(B.self)!) }
container.register(B.self) { r in B(a: r.resolve(A.self)!) }

// Break cycle with property injection
container.register(A.self) { r in
    let a = A()
    a.b = r.resolve(B.self)!
    return a
}
container.register(B.self) { r in B(a: r.resolve(A.self)!) }
```

### 4. Resolving in Initializers

```swift
// Accessing container during init
class BadService {
    let dependency = DIContainer.shared.container.resolve(Dep.self)!
}

// Inject through initializer
class GoodService {
    let dependency: DepProtocol
    init(dependency: DepProtocol) {
        self.dependency = dependency
    }
}
```

### 5. Container as Service Locator

```swift
// Passing container everywhere
class FeatureViewModel {
    func doSomething() {
        let service = container.resolve(Service.self)!  // Hidden dependency
    }
}

// Explicit dependencies in init
class FeatureViewModel {
    private let service: ServiceProtocol
    init(service: ServiceProtocol) {
        self.service = service
    }
}
```

## Debugging Tips

### Check Registration

```swift
#if DEBUG
func validateRegistrations() {
    let requiredTypes: [Any.Type] = [
        NetworkServiceProtocol.self,
        DatabaseServiceProtocol.self,
        ProfileViewModelProtocol.self,
    ]

    for type in requiredTypes {
        if container.resolve(type) == nil {
            print("Missing registration: \(type)")
        }
    }
}
#endif
```

### Log Resolutions

```swift
extension Container {
    func resolveWithLogging<T>(_ type: T.Type) -> T? {
        let result = resolve(type)
        #if DEBUG
        if result == nil {
            print("Failed to resolve: \(type)")
        } else {
            print("Resolved: \(type)")
        }
        #endif
        return result
    }
}
```
