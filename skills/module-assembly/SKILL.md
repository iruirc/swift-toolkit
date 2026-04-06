---
name: module-assembly
description: "Use when assembling MVVM modules, creating CoordinatorFactory/ModuleFactory, wiring View+ViewModel, or setting up Composition Root in SceneDelegate. Covers Factory pattern that connects DI container with Coordinators without Service Locator."
---

# Module Assembly Pattern

Connects Dependency Injection with Coordinators through explicit Factory objects. Coordinators never touch the DI container directly — they receive pre-built modules from Factories.

## Problem

Without Factories, coordinators become dependency dumps:

```swift
// Anti-pattern: Coordinator as Service Locator
class FeatureCoordinator: BaseCoordinator {
    private let container: Resolver  // knows about DI container

    func start() {
        // Hidden dependencies — impossible to know what's needed without reading body
        let viewModel = container.resolve(FeatureViewModelProtocol.self)!
        let viewController = FeatureViewController(viewModel: viewModel)
        router.push(viewController)
    }
}
```

Problems:
- Coordinator has hidden dependencies (only visible at runtime)
- Crash if registration is missing — no compile-time safety
- Hard to test — need full container setup
- Violates Dependency Inversion — high-level module depends on container

## Architecture Overview

```
SceneDelegate (Composition Root)
    └── AppDependencyContainer (DI facade)
            └── CoordinatorFactory (creates coordinators)
                    └── ModuleFactory (assembles View + ViewModel)
                            └── Assembly (actual wiring per module)
                                    └── ModuleComponents<View, ViewModel>
```

**Rules:**
- Only `AppDependencyContainer` knows about DI container internals
- `CoordinatorFactory` knows about `ModuleFactory` and dependency protocols
- `ModuleFactory` delegates to `Assembly` enums
- `Assembly` receives only the dependency protocol it needs
- Coordinators receive only `CoordinatorFactory` + typed `ModuleFactory` protocol

## ModuleComponents

Type-safe container for assembled module:

```swift
struct ModuleComponents<View, ViewModel> {
    let view: View
    let viewModel: ViewModel
}
```

## Feature Dependency Protocols

Each feature declares **only the dependencies it needs**:

```swift
// Feature declares what it needs — nothing more
protocol ProfileFeatureDependencies {
    var userService: UserServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var imageLoader: ImageLoaderProtocol { get }
}

protocol SettingsFeatureDependencies {
    var appSettingsManager: AppSettingsManagerProtocol { get }
    var userService: UserServiceProtocol { get }
}

// App container conforms to all feature protocols
protocol AppDependencies: ProfileFeatureDependencies,
                          SettingsFeatureDependencies,
                          HomeFeatureDependencies {
    // Composite — no additional requirements
}
```

**Why feature protocols matter:**
- Assembly accepts only its protocol — compile-time guarantee of minimal dependencies
- Adding a dependency to a feature = changing its protocol = compiler shows all affected code
- Easy to create focused test doubles — mock only what the feature needs

## Assembly

Static factory that performs actual wiring. One per module. Receives only its feature dependency protocol:

```swift
enum ProfileAssembly {
    @MainActor
    static func assemble(dependencies: ProfileFeatureDependencies)
        -> ModuleComponents<ProfileViewController, ProfileViewModel> {

        let viewModel = ProfileViewModel(
            userService: dependencies.userService,
            analyticsService: dependencies.analyticsService
        )
        let view = ProfileViewController(viewModel: viewModel)
        return ModuleComponents(view: view, viewModel: viewModel)
    }
}
```

**Why `enum`:** No state, no instances — pure factory function. Prevents accidental instantiation.

For modules that need runtime parameters:

```swift
enum DetailAssembly {
    @MainActor
    static func assemble(
        dependencies: ProfileFeatureDependencies,
        itemId: String
    ) -> ModuleComponents<DetailViewController, DetailViewModel> {

        let viewModel = DetailViewModel(
            itemId: itemId,
            userService: dependencies.userService
        )
        let view = DetailViewController(viewModel: viewModel)
        return ModuleComponents(view: view, viewModel: viewModel)
    }
}
```

## ModuleFactory

Creates modules for Coordinators. Split into feature-specific protocols:

```swift
// Each feature has its own factory protocol
@MainActor
protocol ProfileModuleFactory {
    func makeProfileModule() -> ModuleComponents<ProfileViewController, ProfileViewModel>
    func makeDetailModule(itemId: String) -> ModuleComponents<DetailViewController, DetailViewModel>
    func makeEditProfileModule() -> ModuleComponents<EditProfileViewController, EditProfileViewModel>
}

@MainActor
protocol SettingsModuleFactory {
    func makeSettingsModule() -> ModuleComponents<SettingsViewController, SettingsViewModel>
}

@MainActor
protocol HomeModuleFactory {
    func makeHomeModule() -> ModuleComponents<HomeViewController, HomeViewModel>
}
```

Single implementation conforms to all protocols:

```swift
@MainActor
final class ModuleFactoryImp: ProfileModuleFactory,
                               SettingsModuleFactory,
                               HomeModuleFactory {

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // MARK: - ProfileModuleFactory

    func makeProfileModule() -> ModuleComponents<ProfileViewController, ProfileViewModel> {
        ProfileAssembly.assemble(dependencies: dependencies)
    }

    func makeDetailModule(itemId: String) -> ModuleComponents<DetailViewController, DetailViewModel> {
        DetailAssembly.assemble(dependencies: dependencies, itemId: itemId)
    }

    func makeEditProfileModule() -> ModuleComponents<EditProfileViewController, EditProfileViewModel> {
        EditProfileAssembly.assemble(dependencies: dependencies)
    }

    // MARK: - SettingsModuleFactory

    func makeSettingsModule() -> ModuleComponents<SettingsViewController, SettingsViewModel> {
        SettingsAssembly.assemble(dependencies: dependencies)
    }

    // MARK: - HomeModuleFactory

    func makeHomeModule() -> ModuleComponents<HomeViewController, HomeViewModel> {
        HomeAssembly.assemble(dependencies: dependencies)
    }
}
```

**Why feature-specific protocols:** Coordinator receives only `ProfileModuleFactory`, not the full `ModuleFactoryImp`. It can only create modules it's responsible for.

## CoordinatorFactory

Creates Coordinators with their ModuleFactory and Router:

```swift
@MainActor
protocol CoordinatorFactory {
    func makeProfileCoordinator(router: Router) -> ProfileCoordinator
    func makeSettingsCoordinator(router: Router) -> SettingsCoordinator
    func makeHomeCoordinator(router: Router) -> HomeCoordinator
    func makeTabBarCoordinator(router: Router) -> TabBarCoordinator
}

@MainActor
final class CoordinatorFactoryImp: CoordinatorFactory {
    private let dependencies: AppDependencies
    private let moduleFactory: ModuleFactoryImp

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.moduleFactory = ModuleFactoryImp(dependencies: dependencies)
    }

    func makeProfileCoordinator(router: Router) -> ProfileCoordinator {
        ProfileCoordinator(
            router: router,
            coordinatorFactory: self,
            factory: moduleFactory  // passed as ProfileModuleFactory
        )
    }

    func makeSettingsCoordinator(router: Router) -> SettingsCoordinator {
        SettingsCoordinator(
            router: router,
            coordinatorFactory: self,
            factory: moduleFactory
        )
    }

    func makeHomeCoordinator(router: Router) -> HomeCoordinator {
        HomeCoordinator(
            router: router,
            coordinatorFactory: self,
            factory: moduleFactory
        )
    }

    func makeTabBarCoordinator(router: Router) -> TabBarCoordinator {
        TabBarCoordinator(
            router: router,
            coordinatorFactory: self,
            factory: moduleFactory
        )
    }
}
```

## Coordinator Usage

Coordinator receives typed factory protocols — no container, no resolve calls:

```swift
@MainActor
final class ProfileCoordinator: BaseCoordinator {
    private let router: Router
    private let coordinatorFactory: CoordinatorFactory
    private let view: ProfileViewController
    private let viewModel: ProfileViewModel

    // onFinish signal to parent
    var onFinish: (() -> Void)?

    init(router: Router,
         coordinatorFactory: CoordinatorFactory,
         factory: ProfileModuleFactory) {

        self.router = router
        self.coordinatorFactory = coordinatorFactory

        // Module assembled by factory — Coordinator doesn't know how
        let module = factory.makeProfileModule()
        self.view = module.view
        self.viewModel = module.viewModel
    }

    override func start() {
        viewModel.onEditProfile = { [weak self] in
            self?.showEditProfile()
        }
        viewModel.onOpenSettings = { [weak self] in
            self?.showSettings()
        }
        router.push(view)
    }

    private func showEditProfile() {
        // For child screens within same feature — use moduleFactory
        // (Coordinator keeps reference to its own factory)
    }

    private func showSettings() {
        // For different feature — use coordinatorFactory
        let coordinator = coordinatorFactory.makeSettingsCoordinator(router: router)
        coordinator.onFinish = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }
        addChild(coordinator)
        coordinator.start()
    }
}
```

## Composition Root

Everything wires together in SceneDelegate — the only place that knows about concrete types:

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var appContainer: AppDependencyContainer?
    private var applicationCoordinator: ApplicationCoordinator?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }

        // 1. Create DI container
        let container = AppDependencyContainer()
        container.bootstrap()
        appContainer = container

        // 2. Create window
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // 3. Create factories
        let coordinatorFactory = CoordinatorFactoryImp(dependencies: container)

        // 4. Create root coordinator
        let navigationController = UINavigationController()
        let router = AppRouter(navigationController: navigationController)
        window.rootViewController = navigationController

        let appCoordinator = ApplicationCoordinator(
            router: router,
            coordinatorFactory: coordinatorFactory
        )
        applicationCoordinator = appCoordinator

        // 5. Start
        window.makeKeyAndVisible()
        appCoordinator.start()
    }
}
```

## AppDependencyContainer

Facade over Swinject that conforms to all feature dependency protocols:

```swift
@MainActor
final class AppDependencyContainer: AppDependencies {

    private let container = Container()

    func bootstrap() {
        registerServices()
    }

    // MARK: - AppDependencies conformance

    var userService: UserServiceProtocol {
        container.resolve(UserServiceProtocol.self)!
    }

    var analyticsService: AnalyticsServiceProtocol {
        container.resolve(AnalyticsServiceProtocol.self)!
    }

    var appSettingsManager: AppSettingsManagerProtocol {
        container.resolve(AppSettingsManagerProtocol.self)!
    }

    var imageLoader: ImageLoaderProtocol {
        container.resolve(ImageLoaderProtocol.self)!
    }

    // MARK: - Private

    private func registerServices() {
        container.register(UserServiceProtocol.self) { _ in
            UserService()
        }.inObjectScope(.container)

        container.register(AnalyticsServiceProtocol.self) { _ in
            AnalyticsService()
        }.inObjectScope(.container)

        // ... more registrations
    }
}
```

**Key insight:** Swinject `container.resolve()` calls happen **only inside AppDependencyContainer**. The rest of the app works with typed protocols — no container leaks out.

## File Structure

```
App/
├── SceneDelegate.swift                          # Composition Root
├── DependencyInjection/
│   ├── AppDependencyContainer.swift             # DI facade, conforms to AppDependencies
│   ├── ModuleComponents.swift                   # Generic <View, ViewModel> container
│   ├── Protocols/
│   │   ├── AppDependencies.swift                # Composite protocol
│   │   ├── ProfileFeatureDependencies.swift     # Per-feature dependency protocol
│   │   ├── SettingsFeatureDependencies.swift
│   │   └── HomeFeatureDependencies.swift
│   └── ModuleFactory/
│       ├── ProfileModuleFactory.swift           # Per-feature factory protocol
│       ├── SettingsModuleFactory.swift
│       ├── HomeModuleFactory.swift
│       └── ModuleFactoryImp.swift               # Single implementation
├── Coordinators/
│   ├── Factories/
│   │   ├── CoordinatorFactory.swift             # Protocol
│   │   └── CoordinatorFactoryImp.swift          # Implementation
│   ├── ApplicationCoordinator.swift
│   └── TabBarCoordinator.swift
└── Modules/
    ├── Profile/
    │   ├── ProfileAssembly.swift                # enum, static assemble()
    │   ├── ProfileCoordinator.swift
    │   ├── ProfileViewController.swift
    │   └── ProfileViewModel.swift
    └── Settings/
        ├── SettingsAssembly.swift
        ├── SettingsCoordinator.swift
        ├── SettingsViewController.swift
        └── SettingsViewModel.swift
```

## Testing

### Testing Coordinators (no container needed)

```swift
class ProfileCoordinatorTests: XCTestCase {
    var sut: ProfileCoordinator!
    var mockRouter: MockRouter!
    var mockCoordinatorFactory: MockCoordinatorFactory!
    var mockModuleFactory: MockProfileModuleFactory!

    @MainActor
    override func setUp() {
        mockRouter = MockRouter()
        mockCoordinatorFactory = MockCoordinatorFactory()
        mockModuleFactory = MockProfileModuleFactory()
        sut = ProfileCoordinator(
            router: mockRouter,
            coordinatorFactory: mockCoordinatorFactory,
            factory: mockModuleFactory
        )
    }

    @MainActor
    func test_start_pushesProfileView() {
        sut.start()
        XCTAssertTrue(mockRouter.pushedViewController is ProfileViewController)
    }
}

// Mock factory returns controlled modules
class MockProfileModuleFactory: ProfileModuleFactory {
    func makeProfileModule() -> ModuleComponents<ProfileViewController, ProfileViewModel> {
        let vm = ProfileViewModel(
            userService: MockUserService(),
            analyticsService: MockAnalyticsService()
        )
        let vc = ProfileViewController(viewModel: vm)
        return ModuleComponents(view: vc, viewModel: vm)
    }
}
```

### Testing Assemblies

```swift
class ProfileAssemblyTests: XCTestCase {
    @MainActor
    func test_assemble_createsConnectedModule() {
        let deps = MockProfileDependencies()
        let module = ProfileAssembly.assemble(dependencies: deps)

        XCTAssertNotNil(module.view)
        XCTAssertNotNil(module.viewModel)
    }
}

class MockProfileDependencies: ProfileFeatureDependencies {
    var userService: UserServiceProtocol = MockUserService()
    var analyticsService: AnalyticsServiceProtocol = MockAnalyticsService()
    var imageLoader: ImageLoaderProtocol = MockImageLoader()
}
```

## When to Use

**Use this pattern when:**
- App has 5+ screens with navigation between features
- Using Coordinator pattern for navigation
- Using Swinject or other DI container
- Want compile-time safety for dependency graph
- Need testable coordinators without DI container in tests

**Skip for:**
- Simple apps with 2-3 screens — manual DI in Coordinator is fine
- SwiftUI-only apps with NavigationStack — use Environment instead
- Prototypes — overhead not justified

## Scaling

**Growing number of modules:** Split `ModuleFactoryImp` into feature-grouped partial implementations using extensions, or separate factory classes per feature group.

**Shared sub-modules:** If two features share a sub-screen, create a shared factory protocol that both coordinators accept.

**Runtime parameters:** Assembly accepts parameters alongside dependencies:
```swift
static func assemble(dependencies: ProfileFeatureDependencies, userId: String)
    -> ModuleComponents<ProfileViewController, ProfileViewModel>
```

## Common Mistakes

1. **Coordinator resolving from container** — Coordinator should never import Swinject or call `resolve()`. It receives factories.
2. **Fat ModuleFactoryImp** — If it has 30+ methods, split by feature group using extensions or separate classes.
3. **Assembly with side effects** — Assembly should only wire objects. No analytics, no logging, no network calls.
4. **Skipping feature dependency protocols** — Passing `AppDependencies` everywhere defeats the purpose. Each Assembly should accept its minimal protocol.
5. **Creating ModuleFactory inside Coordinator** — Factory is created once in CoordinatorFactory and passed down. Coordinator doesn't create factories.
