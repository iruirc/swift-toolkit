---
name: di-factory
description: "Use when working with the Factory DI library by hmlongco (FactoryKit) in iOS/macOS apps — registration, property-wrapper injection, scopes, modular containers, contexts, and testing. For Composition Root see di-composition-root; for Coordinator wiring see di-module-assembly."
---

# Factory DI Patterns (hmlongco)

This skill provides Factory-specific guidelines: `Container`/`SharedContainer` model, registration via computed properties, property-wrapper injection, scopes, parameterized factories, modular containers, contexts, and testing.

> **Versions assumed:** Factory 2.5+ (`FactoryKit` is the canonical module name; older code may still import `Factory`). Swift 5.10+, iOS 13+. The Swift Testing trait API requires Factory 2.5+.

> **Related skills:**
> - `di-composition-root` — где живёт Container, как стартует bootstrap, sync vs async, scopes как стратегия (Factory покрывает только сам контейнер; CR — это где он создаётся и эксплуатируется)
> - `di-module-assembly` — как Coordinator-ы получают зависимости через `CoordinatorFactory` / `ModuleFactory`. С Factory эти Factory-объекты сами разрешают зависимости через `Container.shared.foo()` или принимают `Container` в init — но архитектурный pattern идентичен Swinject-варианту
> - `di-swinject` — альтернативный DI-framework. Сравнительная таблица в конце этого скилла
> - `pkg-spm-design` — Factory, как и Swinject, **нельзя импортировать в main target SPM-пакета**. Модульные `extension Container` per feature живут в **app target**, см. раздел «Modular Containers» ниже
> - `arch-tca` — TCA использует свою `@Dependency` систему, не смешивай с Factory в TCA-фичах

## When to Use

**Factory is the right choice when:**
- Хочется compile-time safety регистраций (factory не существует → код не компилируется)
- Нужен property-wrapper стиль (`@Injected`) вместо ручного resolve
- Современный SwiftUI app, активно используется `@Observable` / Observation
- Нужны контексты (preview/test/debug overrides) из коробки
- Граф средний (10–100 сервисов) — Factory масштабируется лучше manual, но без рантайм-overhead Swinject

**Consider alternatives:**
- < 10 сервисов, монолит → Manual DI на `lazy var` (см. `di-composition-root`, секция «Manual DI»)
- Legacy на Swinject, переписывать дороже → Оставить Swinject (см. `di-swinject`)
- TCA-фича целиком → используй `@Dependency` от Point-Free, не Factory
- Нужны runtime-зарегистрированные factories с произвольными аргументами и поиском по имени → Swinject (`name:` параметр и autoregister)

## Installation

Swift Package Manager:

```swift
// Package.swift
.package(url: "https://github.com/hmlongco/Factory.git", from: "2.5.0")

// Targets
.product(name: "FactoryKit", package: "Factory"),               // app target
.product(name: "FactoryTesting", package: "Factory"),           // ONLY test target
```

```swift
import FactoryKit            // в production-коде (НЕ `import Factory` — это устаревшее имя)
import FactoryTesting        // в test-таргетах (даёт `.container` Suite trait для Swift Testing)
```

## Core Concepts

### Container

Регистрации живут как **computed properties в extension Container**. Каждое такое свойство возвращает `Factory<T>`, который умеет резолвить инстанс. Сам `Container` — это финальный класс с `static let shared`, но его можно (и нужно) **наследовать/иметь свой** для модульности — см. ниже «Modular Containers».

```swift
import FactoryKit

extension Container {
    var userService: Factory<UserServiceProtocol> {
        self { UserService(networkClient: self.networkClient(), storage: self.keychainStorage()) }
    }

    var networkClient: Factory<HTTPClient> {
        self { URLSessionHTTPClient() }.singleton
    }

    var keychainStorage: Factory<KeychainStorage> {
        self { KeychainStorage(service: "com.example.app") }.singleton
    }
}
```

**Что важно:**
- `self { … }` — синтаксический сахар над `Factory(self) { … }`. Используй короткую форму.
- Имя свойства **становится ключом** регистрации (`StaticString = #function`). Не переименовывай в production без миграции — старые `register` overrides потеряются.
- Граф собирается **через тот же `self`** внутри замыкания: `self.networkClient()`. НЕ через `Container.shared.networkClient()` — иначе сломается изоляция при создании отдельного `Container()` для тестов или модулей.

### Factory<T>

`Factory<T>` — value-type, не сам инстанс. Резолвится через `callAsFunction`:

```swift
let service = Container.shared.userService()    // эквивалент .resolve()
```

Создание `Factory` дёшево; реальный инстанс возникает только при вызове.

### Composition Root

Factory **не отменяет Composition Root** — она его реализует через `Container`. CR-логика (где создаётся `Container`, что в нём зарегистрировано, когда стартует bootstrap) — в скилле `di-composition-root`.

```swift
// SceneDelegate / @main App
@main
struct MyApp: App {
    init() {
        Container.shared.bootstrap()    // см. AutoRegistering ниже
    }
    var body: some Scene { … }
}
```

**Никогда не дёргай `Container.shared` из доменных слоёв** — только через `@Injected` или явный конструктор. Иначе получаешь Service Locator (см. Common Mistakes).

## Resolution: Property Wrappers

### `@Injected` — eager, sync

Резолвится **в момент создания владельца**. Используй для обязательных зависимостей.

```swift
final class ProfileViewModel: ObservableObject {
    @Injected(\.userService) private var userService
    @Injected(\.analyticsService) private var analytics

    func load() async {
        let user = try await userService.fetchCurrent()
        analytics.track(.profileLoaded)
    }
}
```

`\.userService` — KeyPath на свойство `Container.userService`.

### `@LazyInjected` — lazy, sync

Резолвится при первом обращении. Используй когда зависимость нужна не всегда или владелец создаётся часто.

```swift
final class AuthService {
    @LazyInjected(\.biometricAuthenticator) private var biometric
    // BiometricAuthenticator создаётся только если действительно вызвали биометрию
}
```

### `@WeakLazyInjected` — weak reference

Используй для **разрыва циклов** или для опционально-кэшируемых ресурсов.

```swift
final class CoordinatorRoot {
    @WeakLazyInjected(\.imageCache) private var imageCache: ImageCache?
    // imageCache живёт пока его держит кто-то другой
}
```

### `@InjectedObservable` — для @Observable view models (Factory 2.4+)

```swift
@Observable
final class ContentViewModel {
    @ObservationIgnored @Injected(\.repository) private var repository
}

struct ContentView: View {
    @InjectedObservable(\.contentViewModel) var viewModel
    var body: some View { … }
}
```

`@ObservationIgnored` обязателен на `@Injected` внутри `@Observable` класса — иначе свойство станет частью граф изменений, и каждый resolve будет триггерить обновление UI.

### Direct resolution (без property wrappers)

Когда `@Injected` не подходит (`ParameterFactory`, не-объект, ручная сборка):

```swift
let service = Container.shared.userService()
let detail = Container.shared.detailViewModel(itemId)   // см. ParameterFactory
```

## Scopes

Scope управляется модификатором после `self { … }`. По умолчанию — `.unique` (новый инстанс на каждый resolve).

| Scope | Поведение | Когда использовать |
|---|---|---|
| `.unique` (default) | Новый инстанс каждый раз | ViewModels, Coordinators, stateful |
| `.singleton` | Один глобальный инстанс **на весь процесс** (не привязан к Container) | Один внешний ресурс (Keychain wrapper) |
| `.cached` | Один инстанс **на этот Container**, до `reset()` | Сервисы (NetworkClient, Database) |
| `.shared` | Weak: жив пока кто-то держит strong; иначе пересоздаётся | Опциональные shared caches |
| `.graph` | Один инстанс **в рамках одного top-level resolve** | Shared state в графе одной фичи |

```swift
extension Container {
    var networkClient: Factory<HTTPClient> {
        self { URLSessionHTTPClient() }.cached         // singleton-внутри-этого-Container
    }
    var keychainStorage: Factory<KeychainStorage> {
        self { KeychainStorage(service: "...") }.singleton  // глобально на процесс
    }
    var imageCache: Factory<ImageCache> {
        self { ImageCache() }.shared                   // weak
    }
    var profileViewModel: Factory<ProfileViewModel> {
        self { ProfileViewModel() }                    // .unique по умолчанию
    }
}
```

**`.cached` vs `.singleton`:**
- `.cached` — инстанс живёт в `Container.shared` (или другом `Container`), очищается через `reset()`. **Это то, что обычно нужно** для тестируемости.
- `.singleton` — инстанс **переживает** `Container.reset()`. Используй только для системных ресурсов, у которых разрушение опасно (Keychain handle, OSLog subsystem).

**Time-to-live:** `self { … }.singleton.timeToLive(60 * 5)` — пересоздаст инстанс через N секунд. Полезно для токенов / коротких кэшей.

## Parameterized Factories

Когда инстанс требует runtime-параметр (id экрана, конфиг flow):

```swift
extension Container {
    var detailViewModel: ParameterFactory<String, DetailViewModel> {
        self { itemId in
            DetailViewModel(itemId: itemId, service: self.itemService())
        }
    }
}

// Resolve
let vm = Container.shared.detailViewModel("item-123")
```

**Несколько параметров** — через tuple:

```swift
extension Container {
    var chatViewModel: ParameterFactory<(String, String), ChatViewModel> {
        self { (roomId, userId) in
            ChatViewModel(roomId: roomId, userId: userId, chat: self.chatService())
        }
    }
}

let vm = Container.shared.chatViewModel(("room-1", "user-42"))
```

**Ограничения:**
- `@Injected` НЕ работает с `ParameterFactory` — нет способа передать параметры до инициализации wrapper-а. Используй `Container.shared.foo(arg)` напрямую или явно прокинь зависимость через init.
- Кэширование (`.cached`/`.singleton`) по умолчанию **игнорирует параметры** — тот же инстанс вернётся для разных id. Для key-by-parameters используй `scopeOnParameters` (Factory 2.5+).

### ParameterFactory vs функция-фабрика

`ParameterFactory` — каноничный путь от автора Factory. Используй её **по умолчанию**: получаешь скоупы (`.cached.scopeOnParameters`), контексты (`.onTest`/`.onPreview`), `register` override в тестах, единый стиль с остальными `var foo: Factory<...>`.

Простая функция-фабрика — только когда **ничего из перечисленного не нужно** и хочется именованных аргументов:

```swift
// Допустимо ТОЛЬКО если: нет нужды в .cached/.shared, нет .onTest override, нет register-моков
extension Container {
    func chatViewModel(roomId: String, userId: String) -> ChatViewModel {
        ChatViewModel(roomId: roomId, userId: userId, chat: self.chatService())
    }
}
```

| Критерий | `ParameterFactory` | Функция-фабрика |
|---|---|---|
| Скоупы (`.cached`, `.singleton`) | ✅ через `scopeOnParameters` | ❌ всегда новый инстанс |
| Контексты (`.onTest`, `.onPreview`) | ✅ | ❌ |
| `register` override в тестах | ✅ | ❌ — только подменой реализации |
| Именованные аргументы | ❌ — tuple для 2+ | ✅ |
| Подходит для | ViewModels с runtime id, любой prod-кейс | Однострочные factory без жизненного цикла |

**Правило:** если есть хоть один параметр и нужны кэш/контекст/моки — `ParameterFactory`. Иначе — выбор по эстетике API.

## AutoRegistering — Bootstrap Hook

Если нужно выполнить код **один раз перед первой резолюцией** (зарегистрировать дефолты, прочитать config, подключить контексты):

```swift
extension Container: AutoRegistering {
    public func autoRegister() {
        // Conditional defaults
        #if DEBUG
        analyticsService.register { NoOpAnalytics() }
        #endif

        // Context-bound overrides
        networkClient.onPreview { MockHTTPClient(scenario: .happy) }
        userService.onTest { InMemoryUserService() }
    }
}
```

`autoRegister()` вызывается лениво при первом resolve и только один раз на инстанс `Container`.

**Используй для:**
- Дефолтных override'ов в DEBUG/Test/Preview
- Регистрации factory-методов из подмодулей (см. ниже)
- Конфигурации, которая зависит от bundle / env

**НЕ используй для:**
- Тяжёлой инициализации (БД, сеть) — должно быть в `bootstrap()` CR
- Бизнес-логики

## Modular Containers (организация в app target)

> **Сначала правило:** `import FactoryKit` **в SPM-пакете запрещён** — той же ригидной нормой, что и Swinject. Это требование `pkg-spm-design` (универсальное правило 1). Пакет всегда принимает зависимости через `init(dependencies:)`. То, что описано ниже — **организация в app target**, а не в SPM-пакетах.

Главный modular-pattern Factory: один `Container.shared`, регистрации разбиты по файлам в app target — по одному файлу на feature/слой:

```
App/
├── Composition/
│   ├── Container+Networking.swift      // apiClient, httpMiddleware
│   ├── Container+Persistence.swift     // database, repositories
│   ├── Container+Profile.swift         // profileService, profileViewModel
│   ├── Container+Settings.swift        // settingsService, settingsViewModel
│   └── Container+Bootstrap.swift       // AutoRegistering, context overrides
├── App.swift
└── ...
```

Каждый файл — `extension Container` со своими свойствами:

```swift
// App/Composition/Container+Profile.swift
import FactoryKit
import ProfileFeature       // SPM package — без Factory внутри

extension Container {
    var profileService: Factory<ProfileServiceProtocol> {
        self { ProfileService(api: self.apiClient()) }.cached
    }
    var profileModule: Factory<ProfileModule> {
        self { ProfileModule(dependencies: .init(
            api: self.apiClient(),
            logger: self.logger()
        )) }
    }
}
```

```swift
// App/Composition/Container+Networking.swift
import FactoryKit

extension Container {
    var apiClient: Factory<APIClient> {
        self { URLSessionAPIClient(config: .production) }.cached
    }
}
```

`Container.shared.profileModule()` работает в host app, в превью и в тестах. Внутри SPM-пакета `ProfileFeature` нет ни строчки про Factory — он принимает свои зависимости через `init(dependencies: ProfileFeatureDependencies)`.

**Минус:** все extension'ы делят один namespace `Container`. Конфликт имён — UB (одно из свойств молча перекроет другое, потому что ключ — имя свойства). Решение: префиксы по фиче (`profileService`, `profileViewModel`) или своя `SharedContainer` (см. ниже).

### Свой `SharedContainer` (для очень больших app)

Когда монорепо разрастается до десятков фич и риск name-collision реальный:

```swift
// App/Composition/ProfileContainer.swift
public final class ProfileContainer: SharedContainer {
    public static let shared = ProfileContainer()
    public let manager = ContainerManager()
    public init() {}
}

extension ProfileContainer {
    var service: Factory<ProfileServiceProtocol> {
        self { ProfileService() }.cached
    }
}
```

```swift
// Использование
let svc = ProfileContainer.shared.service()
// или с property wrapper:
@Injected(\ProfileContainer.service) var service
```

`@Injected(\KeyPath)` поддерживает любой `SharedContainer`, не только базовый `Container`. Этот файл тоже **в app target**, не в пакете.

### Когда что выбирать

| Ситуация | Выбор |
|---|---|
| Одна команда, < 30 фич | `extension Container` с префиксами в одном namespace |
| Несколько команд / 30+ фич / реальный риск name-collision | Свой `SharedContainer` per feature group |
| SPM-пакет (любой архетип) | Никогда не Factory внутри. `init(dependencies:)` + регистрация в app target |

См. также `pkg-spm-design` секцию про **library/feature archetypes** — там описан общий контракт, как пакет принимает зависимости через `init`, который работает с любым DI-фреймворком (Swinject / Factory / manual).

## Contexts (preview / test / debug overrides)

Factory умеет переопределять регистрацию **в зависимости от контекста запуска** без модификации production-кода:

```swift
extension Container: AutoRegistering {
    public func autoRegister() {
        analyticsService
            .onTest { NoOpAnalytics() }
            .onPreview { LoggingAnalytics() }
            .onDebug { VerboseAnalytics() }
            .onSimulator { SimulatorOnlyAnalytics() }

        // Аргументы запуска: -mockMode 1
        networkClient.onArg("mockMode") { MockHTTPClient() }
    }
}
```

| Modifier | Когда срабатывает |
|---|---|
| `.onTest { … }` | XCTest / Swift Testing process |
| `.onPreview { … }` | SwiftUI Preview (`XCODE_RUNNING_FOR_PREVIEWS == 1`) |
| `.onDebug { … }` | DEBUG build |
| `.onSimulator { … }` | iOS Simulator |
| `.onDevice { … }` | Реальное устройство |
| `.onArg("name") { … }` | Launch argument `-name 1` |

Контексты **аддитивны** — можно chained несколько. Production-замыкание (то, что в `self { … }`) — fallback, если ни один context не активен.

## Coordinator and Module Assembly

Архитектурный pattern (`AppDependencies` → `CoordinatorFactory` → `ModuleFactory`) **не меняется** — только реализация `AppDependencyContainer`. См. `di-module-assembly` для полного примера. Различие с Swinject:

```swift
// Swinject
final class AppDependencyContainer: AppDependencies {
    private let container: Container
    var userService: UserServiceProtocol { container.resolve(UserServiceProtocol.self)! }
}

// Factory
@MainActor
final class AppDependencyContainer: AppDependencies {
    var userService: UserServiceProtocol { Container.shared.userService() }
    var analyticsService: AnalyticsServiceProtocol { Container.shared.analyticsService() }
    // …
}
```

**Coordinator-ы НЕ дёргают `Container.shared` напрямую** — они получают `CoordinatorFactory` и `ModuleFactory` через init. Это сохраняет тестируемость и компилируемую цепочку зависимостей. См. `di-module-assembly`, секция «CoordinatorFactory».

> **Срез внутри ModuleFactory.** Иногда соблазнительно дать `ModuleFactory` напрямую вызывать `Container.shared.foo()` и убрать фасад `AppDependencyContainer`. Не делай так: это маскирует Service Locator, ломает тесты Coordinator-а (нет init-инъекции — нет mock-а) и обнуляет compile-time видимость dependency surface. Pattern одинаков на 1, 5 и 50 экранов — затраты на фасад окупаются с первой регрессии.

## Testing

### Unit Tests — Direct Injection (preferred)

Как и со Swinject — для ViewModel-ов прямой `init(...)` с моками лучше всего:

```swift
final class ProfileViewModelTests: XCTestCase {
    func test_load_success() async throws {
        let mock = MockUserService(result: .success(.fixture))
        let sut = ProfileViewModel(userService: mock)

        await sut.load()

        XCTAssertEqual(sut.state, .loaded(.fixture))
    }
}
```

Это работает только если ViewModel принимает зависимости через init. Для случая `@Injected` — см. ниже.

### Override через `register` — для @Injected

```swift
final class ProfileViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Container.shared.reset()        // КРИТИЧНО: иначе override из прошлого теста утечёт
    }

    override func tearDown() {
        Container.shared.reset()
        super.tearDown()
    }

    func test_load_success() async {
        Container.shared.userService.register {
            MockUserService(result: .success(.fixture))
        }

        let sut = ProfileViewModel()    // @Injected подхватит mock

        await sut.load()
        XCTAssertEqual(sut.state, .loaded(.fixture))
    }
}
```

### Swift Testing — `.container` trait (Factory 2.5+)

`FactoryTesting` даёт Suite-trait, который автоматически делает scoped Container per test. Не нужно вручную звать `reset()`:

```swift
import Testing
import FactoryTesting
@testable import App

@Suite(.container)
struct ProfileViewModelTests {

    @Test func loadSuccess() async {
        Container.shared.userService.register {
            MockUserService(result: .success(.fixture))
        }
        let sut = ProfileViewModel()
        await sut.load()
        #expect(sut.state == .loaded(.fixture))
    }

    @Test func loadFailure() async {
        Container.shared.userService.register {
            MockUserService(result: .failure(TestError.network))
        }
        let sut = ProfileViewModel()
        await sut.load()
        #expect(sut.state == .error)
    }
}
```

Каждый `@Test` получает свежий `Container.shared` (через `@TaskLocal`). Тесты могут гоняться **параллельно** без интерференции — это главный аргумент перейти на Swift Testing для Factory-проектов.

### Reset gotchas

| Сценарий | Поведение |
|---|---|
| `.unique` | Никаких кэшей — `reset()` ни на что не влияет |
| `.cached` | Сбрасывается через `Container.shared.reset()` |
| `.singleton` | НЕ сбрасывается обычным `reset()`. Используй `reset(options: .all)` |
| Override через `register` | Сбрасывается обычным `reset()` |

**Правило:** в `setUp` всегда `Container.shared.reset(options: .all)`, в `tearDown` — то же самое. Иначе тест-leak гарантирован.

### Preview overrides

**Preferred — централизованно** через `.onPreview` в `autoRegister()`. Один источник правды на все `#Preview`-ы, не мусорит сами View-файлы:

```swift
extension Container: AutoRegistering {
    public func autoRegister() {
        userService.onPreview { MockUserService(result: .success(.fixture)) }
        analytics.onPreview { NoOpAnalytics() }
    }
}

#Preview {
    ProfileView()    // мок подхватится автоматически
}
```

**Локальный override** (одноразовая вариация в конкретном `#Preview`) — через `.preview` modifier (Factory 2.4+) или `register`:

```swift
#Preview("Loading state") {
    Container.shared.userService.register { MockUserService(result: .pending) }
    return ProfileView()
}
```

`return` нужен, потому что в теле `#Preview` появилось statement до View.

## Concurrency (Swift 6 / Strict Concurrency)

`Container` — `Sendable`. Регистрация и резолв thread-safe (внутренний lock). Но **сам инстанс**, который ты возвращаешь, должен быть Sendable / правильно изолирован — Factory не делает магии.

### `@MainActor` view models

Изолируй сам **класс ViewModel**, а не свойство в `Container`. Закрытие фабрики помечается `@MainActor in`, чтобы инициализация прошла на главной очереди:

```swift
@MainActor
@Observable
final class ContentViewModel { /* ... */ }

extension Container {
    var contentViewModel: Factory<ContentViewModel> {
        self { @MainActor in ContentViewModel() }
    }
}
```

**Почему НЕ `@MainActor` на самом `var`:** если пометить свойство `@MainActor`, доступ к нему (включая `Container.shared.contentViewModel`) требует MainActor-контекста — это ломает резолв из background-задач, миграций, `URLSession.delegate`. Изоляция должна жить **на типе, который её требует** (ViewModel), а не на регистрации.

Если Swift 6 ругается на резолв из nonisolated кода — значит, ты резолвишь MainActor-тип не там, где надо. Подними резолв в MainActor-зону (например, в `View.task`/`onAppear`), а не помечай регистрацию.

### `@Injected` в `@Observable` классах

```swift
@MainActor
@Observable
final class FeatureViewModel {
    @ObservationIgnored @Injected(\.repository) private var repository
    @ObservationIgnored @Injected(\.analytics) private var analytics
    
    var state: State = .idle
}
```

`@ObservationIgnored` — обязателен. Без него каждое `@Injected` свойство станет наблюдаемым, и SwiftUI будет лишний раз перерисовывать view.

### `nonisolated` Factory из global actor контекста

Если регистрация чистая (нет UI), оставь её nonisolated — иначе вся фича приедет на MainActor:

```swift
extension Container {
    var repository: Factory<RepositoryProtocol> {
        self { Repository(client: self.apiClient()) }.cached     // nonisolated → ОК
    }
}
```

## Common Mistakes

### 1. `Container.shared` из доменного слоя — Service Locator

```swift
// ❌ Anti-pattern
final class ProfileService {
    func load() {
        let analytics = Container.shared.analytics()     // скрытая зависимость
    }
}

// ✅ Correct: явный init OR @Injected на верхнем уровне (ViewModel/Coordinator)
final class ProfileService {
    private let analytics: AnalyticsProtocol
    init(analytics: AnalyticsProtocol) { self.analytics = analytics }
}
```

`@Injected` допустим в **слое presentation/ViewModel/Coordinator**, где владеет графом фичи. Сервисы и репозитории должны принимать зависимости явно через init.

### 2. Resolve через `Container.shared` внутри Factory-замыкания

```swift
// ❌ Ломает modular containers и тесты
extension Container {
    var profileService: Factory<ProfileService> {
        self { ProfileService(api: Container.shared.apiClient()) }
    }
}

// ✅ Используй self
extension Container {
    var profileService: Factory<ProfileService> {
        self { ProfileService(api: self.apiClient()) }
    }
}
```

Если кто-то создаст отдельный `Container()` для тестов, в первом варианте `apiClient` придёт из `.shared` — тест-изоляция сломана.

### 3. `.singleton` для ViewModel — общий state между экранами

```swift
// ❌ Все экраны увидят одно и то же state
extension Container {
    var profileViewModel: Factory<ProfileViewModel> {
        self { ProfileViewModel() }.singleton
    }
}

// ✅ ViewModel = .unique (default)
extension Container {
    var profileViewModel: Factory<ProfileViewModel> {
        self { ProfileViewModel() }
    }
}
```

### 4. Забыл `reset()` в setUp

```swift
// ❌ Тесты влияют друг на друга
final class Tests: XCTestCase {
    func test_a() {
        Container.shared.foo.register { MockA() }
        // …
    }
    func test_b() {
        // MockA из test_a всё ещё активен → test_b непредсказуем
    }
}

// ✅ ВСЕГДА reset
final class Tests: XCTestCase {
    override func setUp() {
        super.setUp()
        Container.shared.reset(options: .all)
    }
}
```

Лучше — Swift Testing с `@Suite(.container)`, тогда reset не нужен.

### 5. `@Injected` в `@Observable` без `@ObservationIgnored`

```swift
// ❌ Каждый resolve триггерит UI update
@Observable
final class ViewModel {
    @Injected(\.service) var service
}

// ✅
@Observable
final class ViewModel {
    @ObservationIgnored @Injected(\.service) var service
}
```

### 6. ParameterFactory + `.cached` без `scopeOnParameters`

```swift
// ❌ Тот же инстанс для разных itemId
extension Container {
    var detailViewModel: ParameterFactory<String, DetailViewModel> {
        self { DetailViewModel(itemId: $0) }.cached
    }
}

let vm1 = Container.shared.detailViewModel("a")
let vm2 = Container.shared.detailViewModel("b")
// vm1 === vm2, оба смотрят на itemId "a"

// ✅ Либо .unique, либо scopeOnParameters
self { DetailViewModel(itemId: $0) }.cached.scopeOnParameters
```

### 7. Импорт `Factory` вместо `FactoryKit`

```swift
// ❌ Старое имя, deprecation warnings
import Factory

// ✅
import FactoryKit
```

### 8. `register` в production-коде вне `autoRegister()` или тестов

```swift
// ❌ Где-то в SceneDelegate
Container.shared.networkClient.register { CustomClient() }

// Вызвалось ОДИН раз — но любой следующий reset() вернёт оригинал
```

Override-ы должны быть либо в `autoRegister()` (через context-modifiers), либо в тестах. Иначе ты борешься с lifecycle reset-а.

### 9. Конфликт имён в multi-package setup

Два пакета объявили `extension Container { var apiClient: Factory<…> }` с разной реализацией → одно молча перекрыло другое. Проверь grep `var .*: Factory<` по всем пакетам или используй Опцию Б (свой `Container` на пакет).

### 10. `@Injected` сервисов в SwiftUI `View`

```swift
// ❌ Сервис напрямую в View — скрытая зависимость, View нельзя превьюить с моком без AutoRegistering-хака
struct ProfileView: View {
    @Injected(\.userService) var userService
    @Injected(\.analytics) var analytics
    var body: some View { … }
}

// ✅ DI оседает на ViewModel; View получает её через @InjectedObservable или @State
struct ProfileView: View {
    @InjectedObservable(\.profileViewModel) var viewModel
    var body: some View { … }
}

// ✅ Композируемые компоненты — через init, никакого DI:
struct ProfileHeaderView: View {
    let user: User
    let onEdit: () -> Void
    var body: some View { … }
}
```

**Правило:**
- Сервисы (`UserService`, `Analytics`, `Repository`) — **никогда** в `View`. Только в ViewModel через `@Injected` + `@ObservationIgnored`.
- `@InjectedObservable` для root ViewModel экрана — допустимо.
- Компонуемые subview'и — `let`/`@Binding` через init. DI = головная боль для preview и snapshot-тестов.

## Swinject vs Factory: feature comparison

| Аспект | Swinject | Factory |
|---|---|---|
| Регистрация | `container.register(Foo.self) { _ in Foo() }` — runtime, в Assembly | `extension Container { var foo: Factory<Foo> { self { Foo() } } }` — compile-time свойство |
| Type-safety | Runtime: пропущенная регистрация → `resolve(...)!` краш | Compile-time: factory не существует → код не компилируется |
| Биндинг | По типу + опционально `name: String` | По KeyPath на свойство `Container` |
| Резолв в коде | `container.resolve(Foo.self)!` или ручные wrapper-ы | `Container.shared.foo()` или `@Injected(\.foo)` |
| Property wrappers | Нет встроенных (нужно писать свои) | First-class: `@Injected`, `@LazyInjected`, `@WeakLazyInjected`, `@InjectedObservable` |
| SwiftUI / Observation | Ручная интеграция (`StateObject`, EnvironmentObject) | `@InjectedObservable` + `@ObservationIgnored` из коробки |
| Скоупы | `.transient`, `.container`, `.weak`, `.graph`, custom | `.unique`, `.cached`, `.singleton`, `.shared`, `.graph`, `.timeToLive`, `.scopeOnParameters` |
| Параметры в фабрике | `register { (_, arg: String) in … }`, до 9 args | `ParameterFactory<P, T>`, для 2+ — tuple |
| Контексты (test/preview/debug) | Нет — собирай сам через `#if DEBUG` + флаги | `.onTest` / `.onPreview` / `.onDebug` / `.onSimulator` / `.onArg` |
| Bootstrap-хук | Конфигурируешь Assembly + assembler в CR | `AutoRegistering.autoRegister()` лениво на первый resolve |
| Modular setup | `Assembly` per module + `assembler.apply([...])` | `extension Container` per файл, опционально свой `SharedContainer` |
| SPM-пакет | DI-фреймворк **запрещён** в main target → `init(dependencies:)` | То же ограничение → `init(dependencies:)` |
| Тест-изоляция | Свежий `Container()` на каждый тест ИЛИ ручной reset Assembly | `Container.shared.reset(options: .all)` ИЛИ `@Suite(.container)` (FactoryTesting) для параллельных Swift Testing |
| Override моков | `container.register(Foo.self) { _ in Mock() }` (поверх) | `Container.shared.foo.register { Mock() }` |
| Производительность | Runtime dictionary lookup + рефлексия | Static dispatch через property + closure |
| Async / Sendable | Не Sendable из коробки, ручная синхронизация | Container Sendable, register/resolve thread-safe |
| Зрелость | Старее, шире boilerplate, нативно для UIKit-эпохи | Современнее, заточен под SwiftUI/Observation/Swift 6 |

**Когда что выбирать:**

- **Greenfield SwiftUI** + iOS 16+ + `@Observable` → **Factory**
- **Существующий Swinject** в production → не мигрируй ради миграции; см. Migration ниже только если есть конкретная боль (тесты, Swift 6, SwiftUI integration)
- Нужны **именованные регистрации одного типа** (`name: "primary" / "fallback"`) или autoregister-плагины → Swinject
- Нужны контексты (preview/test/debug overrides) **без своего scaffolding** → Factory
- Команда из бывших Spring/Dagger → Swinject ближе ментально (Assembly = Module)

## Migration: Swinject → Factory

| Swinject | Factory |
|---|---|
| `container.register(Foo.self) { _ in Foo() }` | `extension Container { var foo: Factory<Foo> { self { Foo() } } }` |
| `.inObjectScope(.container)` | `.cached` |
| `.inObjectScope(.transient)` (default) | `.unique` (default) |
| `.inObjectScope(.weak)` | `.shared` |
| `.inObjectScope(.graph)` | `.graph` |
| `container.resolve(Foo.self)!` | `Container.shared.foo()` |
| `r.resolve(Foo.self, name: "x")` | Свой ключ через KeyPath или отдельный `var fooX: Factory<Foo>` |
| `Assembly.assemble(container:)` | `extension Container` per feature + `AutoRegistering` |
| `register(Foo.self) { (_, arg: String) in … }` | `var foo: ParameterFactory<String, Foo>` |

**Стратегия миграции:**
1. Переписать сервисы и регистрации feature за фичей (Container extension рядом со старой Assembly).
2. Coordinator-ы оставить как есть — они работают через `AppDependencyContainer` (см. `di-module-assembly`); только реализация фасада меняется.
3. Не оставляй mixed (часть Swinject + часть Factory) дольше одного спринта — два DI-фреймворка одновременно = двойная сложность тестов.

## Debugging Tips

> **Версия API:** примеры ниже опираются на internal `ContainerManager` API из Factory 2.5+. Имена/сигнатуры могут меняться между минорными релизами — сверяйся с README репозитория, если что-то перестало компилироваться.

```swift
// Список зарегистрированных factory-ключей (debug only)
#if DEBUG
Container.shared.manager.registrations.keys.forEach { print($0) }
#endif

// Decorator — log каждый resolve
Container.shared.manager.decorator { resolved in
    print("Resolved: \(type(of: resolved))")
}
```

Decorator вызывается на КАЖДЫЙ resolve — выключай в production.
