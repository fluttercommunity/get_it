[![Flutter Community: get_it](https://fluttercommunity.dev/_github/header/get_it)](https://github.com/fluttercommunity/community)

# get_it

This is a simple **Service Locator** for Dart and Flutter projects with some additional goodies highly inspired by [Splat](https://github.com/reactiveui/splat). It can be used instead of `InheritedWidget` or `Provider` to access objects e.g. from your UI.

Typical usage:
* Accessing service objects like REST API clients, databases so that they easily can be mocked.
* Accessing View/AppModels/Managers/BLoCs from Flutter Views

>**Breaking Change with V4.0.0** 
Principle on how to synchronize your registered instances creation has been rethought and improved :-)
Please see [Synchronizing asynchronous initialisations of Singletons](#synchronizing-asynchronous-initialisations-of-singletons).

## Why GetIt

When your App grows at some point you you will start to put your app's logic in classes that are separated from your Widgets and have no dependency to Flutter which makes your code better organized and easier to test and maintain.
But now you need a way how to access these objects from your UI code. When I came to Flutter from the .Net world the only way to do this was the use of InheritedWidgets. I found the way to use them by wrapping them in a StatefulWidget quite cumbersome and had always problems getting it updating the widgets to work. Also:

* I was missing the ability to easily switch the implementation for a business object for a mocked one without changing the UI.
* The fact that you need a `BuildContext` to access your objects made it unusable to use them from inside the Business layer. 

Accessing an object from anywhere in an App can be done by other ways too but:

* If you use a Singleton you cannot easily switch the implementation to another like a mock version for unit tests
* IoC containers for Dependency Injections offer a similar functionality but with the cost of slow start-up time and less readability because you don't know where the magically injected object come from. As most IoC libs rely on reflection they cannot be used with Flutter.

As I was used to use the Service Locator _Splat_ from .Net I decided to port it to Dart. Since then It got a lot more features.

>If you are not familiar with the concept of Service Locators, its a way to decouple the interface (abstract base class) from a concrete implementation and at the same time allows to access the concrete implementation from everywhere in your App over the interface.
> I can only highly recommend to read this classic article by from Martin Fowler [Inversion of Control Containers and the Dependency Injection  pattern](https://martinfowler.com/articles/injection.html)

GetIt is:
* Extremely fast (O(1))
* Easy to learn/use
* Doesn't clutter your UI tree with special Widgets to access your data like provider or Redux does.

**GetIt isn't a state management solution!** It's a locator for your objects so you need some other way to notify your UI about changes like `Streams` or `ValueNotifiers`.

## Getting Started

At your start-up you register all the objects you want to access later like this:

```Dart
final getIt = GetIt.instance;

void setup() {
  getIt.registerSingleton<AppModel>(AppModel());

// Alternatively you could write it if you don't like global variables 
  GetIt.I.registerSingleton<AppModel>(AppModel());
}
```

After that you can access your `AppModel` class from anywhere like this:

```Dart
MaterialButton(
  child: Text("Update"),
  onPressed: getIt<AppModel>().update   // given that your AppModel has a method update
),
```


You can find here a [detailed blog post on how to use GetIt](https://www.burkharts.net/apps/blog/one-to-find-them-all-how-to-use-service-locators-with-flutter/)


## GetIt in Detail

As Dart supports global (or euphemistic ambient) variables I often assign my GetIt instance to a global variable to make the access to it as easy as possible

Although the approach with a global variable worked well, it has its limitations if you want to use `GetIt` across multiple packages. Therefore GetIt itself is a singleton and the default way to access an instance of `GetIt` is to call:

```Dart
GetIt getIt = GetIt.instance;

//There is also a shortcut (if you don't like it just ignore it):
GetIt getIt = GetIt.I;
```

Through this any call to `instance` in any package of a project will get the same instance of `GetIt`. I still recommend just to assign the instance to a global variable in your project as it is more convenient and doesn't harm (Also it allows you to give your service locator your own name).


```Dart
GetIt getIt = GetIt.instance;
```

> You can use any name you want which makes Brian happy like (`sl, backend, services...`) ;-) 

Before you can access your objects you have to register them within `GetIt` typically direct in your start-up code.

```Dart
getIt.registerSingleton<AppModel>(AppModelImplementation());
getIt.registerLazySingleton<RESTAPI>(() =>RestAPIImplementation());

// if you want to work just with the singleton:
GetIt.instance.registerSingleton<AppModel>(AppModelImplementation());
GetIt.I.registerLazySingleton<RESTAPI>(() =>RestAPIImplementation());

/// `AppModel` and `RESTAPI` are both abstract base classes in this example
```


To access the registered objects call `get<Type>()` on your `GetIt` instance

```Dart
var myAppModel = getIt.get<AppModel>();
```

Alternatively as `GetIt` is a [callable class](https://www.w3adda.com/dart-tutorial/dart-callable-classes) depending on the name you choose for your `GetIt`instance you can use the shorter version:

```Dart
var myAppModel = getIt<AppModel>();

// as Singleton:
var myAppModel = GetIt.instance<AppModel>();
var myAppModel = GetIt.I<AppModel>();
```


## Different ways of registration


`GetIt` offers different ways how objects are registered that effect the lifetime of this objects.

#### Factory

```Dart 
void registerFactory<T>(FactoryFunc<T> func)
```

You have to pass a factory function `func` that returns an NEW instance of an implementation of `T`. Each time you call `get<T>()` you will get a new instance returned. How to pass parameters to a factory you can find [here](#passing-parameters-to-factories)

#### Singleton & LazySingleton
>Although I always would recommend using an abstract base class as registration type so that you can vary the implementations you don't have to do this. You can also register concrete types.

```Dart
void registerSingleton<T>(T instance) 
```

You have to pass an instance of `T` or a derived class of `T` that you will always get returned on a call to `get<T>()`.

As creating this instance can be time consuming at app start-up you can shift the creation to the time the object is the first time requested with:

```Dart
void registerLazySingleton<T>(FactoryFunc<T> func)
```
  
You have to pass a factory function `func` that returns an instance of an implementation of `T`. Only the first time you call `get<T>()` this factory function will be called to create a new instance. After that you will always get the same instance returned.



### Overwriting registrations
If you try to register a type more than once you will get an assertion in debug mode because normally this is not needed and not advised and probably a bug.
If you really have to overwrite a registration, then you can by setting the property `allowReassignment==true`. 

### Testing if a Singleton is already registered
You can check if a certain Type or instance is already registered in GetIt with:

```Dart
 /// Tests if an [instance] of an object or aType [T] or a name [instanceName]
 /// is registered inside GetIt
 bool isRegistered<T>({Object instance, String instanceName});
```

### Unregistering Singletons or Factories
If you need to you can also unregister your registered singletons and factories and pass a optional `disposingFunction` for clean-up.

```Dart
/// Unregister a factory/ singletons by Type [T] or by name [instanceName]
/// If its a singleton/lazySingleton you can unregister an existing registered object instance 
/// by passing it as [instance]. If a lazysingleton wasn't used before expect 
/// this to throw an `ArgumentError`
/// if you need to dispose any resources you can do it using [disposingFunction] function
/// that provides a instance of your class to be disposed
void unregister<T>({Object instance,String instanceName, void Function(T) disposingFunction})
```  

### Resetting LazySingletons

In some cases you might not want to unregister a LazySingleton but instead to reset its instance so that it gets newly created on the next access to it.

```Dart
  /// Clears the instance of a lazy singleton registered type, being able to call the factory function on the first call of [get] on that type.
void resetLazySingleton<T>({Object instance,
                            String instanceName,
                            void Function(T) disposingFunction}) 
```                            


### Resetting GetIt completely

```Dart
/// Clears all registered types. Handy when writing unit tests
void reset()
```


## Asynchronous Factories
If a factory needs to call an async function you can use `registerFactoryAsync()`

```Dart
/// [T] type to register
/// [func] factory function for this type
/// [instanceName] if you provide a value here your factory gets registered with that
/// name instead of a type. This should only be necessary if you need to register more
/// than one instance of one type. Its highly not recommended
void registerFactoryAsync<T>(FactoryFuncAsync<T> func, {String instanceName});
```

To access instances created by such a factory you can't use `get()` but you have to use `getAsync()` so that
you can await the creation of the requested new instance.

```Dart
/// Returns an Future of an instance that is created by an async factory or a Singleton that is
/// not ready with its initialization.
Future<T> getAsync<T>([String instanceName]);
```


## Asynchronous Singletons 

Additionally you can register asynchronous Singletons which means Singletons that have an initialisation that requires async function calls. To be able to control such asynchronous start-up behaviour GetIt supports mechanisms to ensure the correct initialization sequence. 

You create an Singleton with an asynchronous creation function 

```Dart
  void registerSingletonAsync<T>(FactoryFuncAsync<T> factoryfunc,
      {String instanceName,
      Iterable<Type> dependsOn,
      bool signalsReady = false});
```

The difference to a normal Singleton is that you don't pass an existing instance but provide an factory function
that returns a `Future` that completes at the end of `factoryFunc` and signals that the Singleton is ready to use unless `true` is passed for `signalsReady`. (see next chapter) 
To synchronize with other "async Singletons" you can pass a list of `Type`s in `dependsOn` that have to be ready before the passed factory is executed.

There are two possible ways to signal the system that an instance is ready.

## Synchronizing asynchronous initialisations of Singletons

Often your registered services need to do asynchronous initialization work before they can be used from the rest of the app. As this is such a common task and its closely related to registration/initialization GetIt supports you here too.

`GetIt` has the function `allReady` which returns `Future<void>` that can be used e.g. with a Flutter FutureBuilder to await that all asynchronous initialization is finished.

```Dart
  Future<void> allReady({Duration timeout, bool ignorePendingAsyncCreation = false});
```
There are different approaches how the returned Future can be completed:

### Using async Singletons

If you register any async Singletons `allReady` will complete only after all of them have completed their factory functions. Like:

```Dart
  class RestService {
    Future<RestService> init() async {
      Future.delayed(Duration(seconds: 1));
      return this;
    }
  }

  final getIt = GetIt.instance;

  /// in your setup function:
  getIt.registerSingletonAsync<ConfigService>(() async {
    final configService = ConfigService();
    await configService.init();
    return configService;
  });

  getIt.registerSingletonAsync<RestService>(() async => RestService().init());
  // here we asume an async factory function `createDbServiceAsync`
  getIt.registerSingletonAsync<DbService>(createDbServiceAsync); 


  /// ... in your startup page:
  return FutureBuilder(
      future: getIt.allReady(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Text('The first real Page of your App'),
            ),
          );
        } else {
          return CircularProgressIndicator();
        }
      });
```

The above example shows you different ways to register async Singletons. The start-up page will display a `CircularProgressIndicator` until all services have been created.

### Solving dependencies

### Automatic using `dependsOn`
In case that this services have to be initialized in a certain order because they depend on that other services are already ready to be used you can use the `dependsOn` parameter of `registerFactoryAsync`. If you have a non async Singleton that depends on other Singletons we have added the `registerSingletonWithDependencies`. In the following example depends `DbService` on `ConfigService` and `AppModel` on `ConfigService` and `RestService`


```Dart
  getIt.registerSingletonAsync<ConfigService>(() async {
    final configService = ConfigService();
    await configService.init();
    return configService;
  });

  getIt.registerSingletonAsync<RestService>(() async => RestService().init());

  getIt.registerSingletonAsync<DbService>(createDbServiceAsync,
      dependsOn: [ConfigService]);

  getIt.registerSingletonWithDependencies<AppModel>(
      () => AppModelImplmentation(),
      dependsOn: [ConfigService, DbService, RestService]);
```

When using `dependsOn` you ensure that the registration waits with creating its singleton on the completion of the type defined in `dependsOn`.  


### Manually signalling the ready state of a Singleton
Sometimes the mechanism of `dependsOn` might not give you enough control. For this case you can use `isReady` to wait for a certain singelton:

```Dart
  /// Returns a Future that completes if the instance of an Singleton, defined by Type [T] or 
  /// by name [instanceName] or by passing the an existing [instance], is ready
  /// If you pass a [timeout], an [WaitingTimeOutException] will be thrown if the instance
  /// is not ready in the given time. The Exception contains details on which Singletons are 
  /// not ready at that time.
  /// [callee] optional parameter which makes debugging easier. Pass `this` in here.
  Future<void> isReady<T>({
    Object instance,
    String instanceName,
    Duration timeout,
    Object callee,
  });
```

To signal that it is ready a singleton can use `signalReady` to be able to use that you have to set the optional `signalsReady` parameter when registering it OR make your registration type implement the empty abstract class `WillSignalReady`. In that case `allReady` will wait on a call to signalsReady. No automatic signalling will happen in that case.

```Dart
/// Typically this is used in this way inside the registered objects init 
/// method `GetIt.instance.signalReady(this);`
void signalReady(Object instance);
```

For instance you can use this to initialize your Singletons without async registration by using a fire and forget async function from your constructors like

```Dart
class ConfigService {
  ConfigService()
  {
    init();
  }
  Future init() async {
    // do your async initialisation...

    GetIt.instance.signalReady(this);
  }
}
```


### Manual triggering **allReady** (almost deprecated)

By calling `signalReady(null)` on your `GetIt` instance the `Future` you can get from `allReady` will be completed.
This is the most basic way to synchronize your start-up. If you want to do that **don't use `signalsReady` or async Singeltons**!!!
I recommend using one of the other ways because they are more flexible and express your intention more clear.

You can find here a [detailed blog post on async factories and startup synchronization](https://www.burkharts.net/apps/blog/one-to-find-them-all-how-to-use-service-locators-with-flutter/)


## Passing Parameters to factories

In some cases its handy if you could pass changing values to factories when calling `get()`. For that there are two variants for registering factories:

```Dart
  /// registers a type so that a new instance will be created on each call of [get] on that type based on
  /// up to two parameters provided to [get()]
  /// [T] type to register
  /// [P1] type of  param1
  /// [P2] type of  param2
  /// if you use only one parameter pass void here
  /// [factoryfunc] factory function for this type that accepts two parameters
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  /// 
  /// example:
  ///    getIt.registerFactoryParam<TestClassParam,String,int>((s,i) 
  ///        => TestClassParam(param1:s, param2: i));
  /// 
  /// if you only use one parameter:
  /// 
  ///    getIt.registerFactoryParam<TestClassParam,String,void>((s,_) 
  ///        => TestClassParam(param1:s);
  void registerFactoryParam<T,P1,P2>(FactoryFuncParam<T,P1,P2> factoryfunc, {String instanceName});
```

and 

```Dart
  void registerFactoryParamAsync<T,P1,P2>(FactoryFuncParamAsync<T,P1,P2> factoryfunc, {String instanceName});
```

The reason why I settled to use two parameters is that I can imagine some scenarios where you might want to register a builder function for Flutter Widgets that need to get passed a `BuildContext` and some data object. 

When accessing these factories you pass the parameters a optional arguments to `get()`:

```Dart
  var instance = getIt<TestClassParam>(param1: 'abc',param2:3);
```

These parameters are passed as `dynamics` (otherwise I would have had add more generic parameters to `get`()), but they are checked at runtime to be the correct types.

## Testing with GetIt

### Unit Tests
When you are writing unit tests with GetIt in your App you have two possibilities:

* register all the Objects you need inside your unit Tests so that GetIt can provide its objects to the objects tat you are testing
* pass your dependend objects into the constructor of you test objects like:

```Dart
GetIt getIt = GetIt.instance;

class UserManager {
  AppModel appModel;
  DbService dbService;

  UserManager({AppModel appModel, DbService dbService}) {
    this.appModel = appModel ?? getIt.get<AppModel>();
    this.dbService = dbService ?? getIt.get<DbService>();
  }
}
```

This way you don't need to pass them in the `AppModel` and `dbService` inside your App but you can pass them(or a mocked version) in your Unit tests

### Integration Tests
If you have a mocked version of a Service you can easily switch between that and the real one based on a some flag:

```Dart
  if (testing) {
    getIt.registerSingleton<AppModel>(AppModelMock());
  } else {
    getIt.registerSingleton<AppModel>(AppModelImplmentation());
  }
```

## Experts region

### Named registration

**DON'T USE THIS IF YOU ARE REALLY KNOW WHAT YOU ARE DOING!!!**

This should only be your last resort as you can loose your type safety and lead the concept of a singleton add absurdum.
This was added following a request at https://github.com/fluttercommunity/get_it/issues/10

Ok you have been warned. All register functions have an optional named parameter `instanceName`. If you provide a value here 
your factory/singleton gets registered with that name instead of a type. Consequently `get()` has also an optional parameter `instanceName` to access
factories/singletons that were registered by name.

**IMPORTANT:** Each name for registration can only used once.  
Both way of registration are complete separate from each other. 


### More than one instance of GetIt
Although I don't recommend it, you can create your own independent instance of `GetIt` for instance if you don't want to share your locator with some
other package or because the physics of your planet demands it :-)

```Dart
/// To make sure you really know what you are doing
/// you have to first enable this feature:
GetIt.allowMultipleInstances=true;
GetIt myOwnInstance = GetIt.asNewInstance();
```

This new instance does not share any registrations with the singleton instance

## Acknowledgements
Many thanks to the insightful discussions on the API with [Brian Egan](https://github.com/brianegan) and [Simon Lightfoot](https://github.com/slightfoot)    