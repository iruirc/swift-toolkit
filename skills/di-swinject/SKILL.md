---
name: di-swinject
description: "Use when working with Swinject dependency injection in iOS apps. Covers Swinject-specific patterns: object scopes, registrations (basic, autoregister, named, with arguments), Assembly pattern, testing configuration. For Composition Root design see di-composition-root skill; for connecting DI to Coordinators see di-module-assembly skill."
---

# Swinject Dependency Injection Patterns

This skill provides Swinject-specific guidelines: scopes, registration techniques, autoregistration, testing.

> **Related skills:**
> - `di-composition-root` — где создаётся Swinject `Container`, как живёт его lifetime, sync/async bootstrap, scope-стратегии
> - `di-module-assembly` — как Coordinator-ы получают сервисы из Swinject через Factory-паттерн без Service Locator
> - `pkg-spm-design` — почему Swinject **не должен** импортироваться в SPM-пакетах
> - `di-factory` — альтернативный DI-framework (Factory by hmlongco): compile-time safety, property-wrapper injection, SPM-friendly. Сравнительная таблица в конце этого скилла

## When to Use

**Swinject is the right choice when**:
- Need runtime dependency injection
- Want constructor injection with automatic resolution
- Building modular apps with swappable implementations
- Need different configurations for production/testing
- Complex dependency graphs

**Consider alternatives**:
- Simple apps → Manual DI (pass dependencies in init, см. `di-composition-root` секция «Manual AppDependencyContainer»)
- SwiftUI apps без runtime-binding-а → **Factory** (см. `di-factory`) — property-wrapper injection, preview/test contexts из коробки, compile-time safety
- Compile-time safety priority → `di-factory` (factory-замыкание не существует → код не компилируется) или manual DI
- TCA-фича целиком → `@Dependency` от Point-Free (см. `arch-tca`), не Swinject

## Core Concepts

### Container Setup

Swinject `Container` создаётся в Composition Root и оборачивается в `AppDependencyContainer` фасад — никогда не используется как глобальный `static let shared`. **Подробности про CR — в скилле `di-composition-root`.**

Минимум для контекста:

```swift
import Swinject
import SwinjectAutoregistration

@MainActor
final class AppDependencyContainer {
    private let container = Container()

    func bootstrap() {
        registerServices()
        registerViewModels()
    }
}
```

> **`static let shared` запрещён** — превращает контейнер в Service Locator (скрытые зависимости, нет testability). См. `di-composition-root` skill про правильное место и lifetime контейнера.

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

## Coordinator and Module Assembly

Coordinators should **not** receive the Swinject container directly — this creates a Service Locator anti-pattern. Instead, use the Factory pattern described in the `di-module-assembly` skill:

- `AppDependencyContainer` wraps Swinject and conforms to feature dependency protocols
- `ModuleFactory` assembles View + ViewModel using dependency protocols
- `CoordinatorFactory` creates Coordinators with their ModuleFactory
- Coordinators never import Swinject

See `di-module-assembly` skill for complete examples.

## Testing Configuration

### Unit Tests — Direct Injection (Preferred)

For ViewModels and services, inject mock dependencies directly — no container needed:

```swift
class ProfileViewModelTests: XCTestCase {
    func test_loadProfile_success() {
        let mockService = MockUserService(result: .success(testUser))
        let viewModel = ProfileViewModel(userService: mockService)

        viewModel.loadProfile()

        XCTAssertEqual(viewModel.state, .loaded(testUser))
    }

    func test_loadProfile_failure() {
        let mockService = MockUserService(result: .failure(TestError.network))
        let viewModel = ProfileViewModel(userService: mockService)

        viewModel.loadProfile()

        XCTAssertEqual(viewModel.state, .error("Network error"))
    }
}
```

### Integration Tests — Test Container

When testing the DI graph itself or integration between components:

```swift
class TestDIContainer {
    static func makeContainer() -> Container {
        let container = Container()

        container.register(NetworkServiceProtocol.self) { _ in
            MockNetworkService()
        }

        container.register(DatabaseServiceProtocol.self) { _ in
            InMemoryDatabase()
        }

        return container
    }
}
```

### Override Specific Dependencies

```swift
func testWithCustomMock() {
    let container = TestDIContainer.makeContainer()

    container.register(NetworkServiceProtocol.self) { _ in
        MockNetworkService(shouldFail: true)
    }

    let viewModel = container.resolve(ProfileViewModel.self)!
    // Test error handling path
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
// Accessing container during init — hidden dependency
class BadService {
    let dependency = appContainer.resolve(Dep.self)!
}

// Inject through initializer — explicit, testable
class GoodService {
    let dependency: DepProtocol
    init(dependency: DepProtocol) {
        self.dependency = dependency
    }
}
```

### 5. Container as Service Locator

```swift
// Anti-pattern: passing container to Coordinator/ViewModel
class FeatureCoordinator {
    private let container: Resolver
    func start() {
        let vm = container.resolve(FeatureViewModel.self)!  // Hidden dependency
    }
}

// Correct: use Factory pattern (see di-module-assembly skill)
class FeatureCoordinator {
    init(router: Router,
         coordinatorFactory: CoordinatorFactory,
         factory: FeatureModuleFactory) {
        let module = factory.makeFeatureModule()  // Explicit, testable
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

## Swinject vs Factory: когда что

Swinject и Factory (см. `di-factory`) решают одну задачу разными способами. Выбор:

| Критерий | Swinject | Factory |
|---|---|---|
| Compile-time safety | ❌ Resolve-crash в runtime | ✅ Не компилируется без factory |
| Стиль injection | Constructor через `r.resolve(...)` | Property wrapper `@Injected` или `Container.shared.foo()` |
| Регистрации | `register` / `autoregister` в Assembly | Computed property `var foo: Factory<Foo> { self { Foo() } }` |
| Runtime-параметры | `register { (r, arg) in ... }` + `name:` | `ParameterFactory` (один тип параметров на ключ) |
| Multiple impls одного типа | `name:` параметр | Отдельные computed-properties или modular containers |
| Autoregister (avtores'olve init args) | ✅ Через `SwinjectAutoregistration` | ❌ Нет (явно прописать deps в замыкании) |
| Внутри SPM-пакета | ❌ Запрещено | ❌ Запрещено в main target. Модульные `extension Container` per feature — в app target |
| Preview/Test context overrides | Вручную (отдельный test-Assembly) | ✅ `.onPreview` / `.onTest` modifier из коробки |
| Параллельные тесты | Ручной reset между тестами | ✅ Swift Testing `@Suite(.container)` через `@TaskLocal` |
| Зрелость | 10+ лет в production, де-факто стандарт | Современная библиотека (2.x с 2023), активно развивается |
| SwiftUI-специфика | Нейтрален | Заточен под SwiftUI/Observation |
| Размер | ~3000 LOC + SwinjectAutoregistration | <1000 LOC, single dependency |

**Когда Swinject лучше:**
- Многомодульное legacy уже на нём — переписывать дороже
- Нужен autoregister (`r.autoregister(...)` без явной выписки конструктора)
- Нужны **многоисполняемые** биндинги по `name:` с разными аргументами
- UIKit-first проект, SwiftUI используется редко

**Когда Factory лучше:**
- Новый SwiftUI-first проект
- Граф 10–100 сервисов, монорепо или SPM-модули
- Хочется compile-time видеть всю dependency surface
- Команда любит property-wrapper стиль
- Critical: тесты должны гоняться параллельно без reset-headache

**Когда ни тот, ни другой:**
- < 10 сервисов → manual DI на `lazy var` (см. `di-composition-root`)
- TCA-фича целиком → `@Dependency` от Point-Free
