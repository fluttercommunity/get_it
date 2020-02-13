[![Flutter Community: get_it](https://fluttercommunity.dev/_github/header/get_it)](https://github.com/fluttercommunity/community)

# get_it

This is a simple **Service Locator** for Dart and Flutter projects with some additional goodies highly inspired by [Splat](https://github.com/reactiveui/splat). It can be used instead of `InheritedWidget` or `Provider`.


>**Breaking Change with V4.0.0** 
Principle on how to synchronize your registered instances creation has been rethought and improved :-)
Please see [Asynchronous Singletons](#asynchronous-singletons).

Synchronising asynchronous creation of instances

>**Breaking Change with V2.0.0** 
you no longer can directly create instances of the type `GetIt` because `GetIt` is now a singleton please see [Getting Started](#getting-started).


You can find here a [detailed blog post on how to use GetIt](https://www.burkharts.net/apps/blog/one-to-find-them-all-how-to-use-service-locators-with-flutter/)


>If you are not familiar with the concept of Service Locators, its a way to decouple the interface (abstract base class) from a concrete implementation and at the same time allows to access the concrete implementation from everywhere in your App over the interface.
> I can only highly recommend to read this classic article by from Martin Fowler [Inversion of Control Containers and the Dependency Injection  pattern](https://martinfowler.com/articles/injection.html)

Accessing an object from anywhere in an App especially can be done by other ways too but:

* If you use a Singleton you cannot easily switch the implementation to another like a mock version for unit tests
* IoC containers for Dependency Injections offer a similar functionality but with the cost of slow start-up time and less readability because you don't know where the magically injected object come from. As most IoC libs rely on reflection they cannot be used with Flutter. 


Typical usage:
* Accessing service objects like REST API clients, databases so that they easily can be mocked.
* Accessing View/AppModels/Managers from Flutter Views
* Because interface and implementations are decoupled you could also register Flutter Views with different implementations and decide at start-up which one you want to use e.g. depending on screen resolutions

**Extremely important if you use GetIt: ALWAYS use the same style to import your project files either as relative paths OR as package which I recommend. DON'T mix them because currently Dart treats types imported in different ways as two different types although both reference the same file.**


## Getting Started

**Before V2.0.0**
As Dart supports global (or euphemistic ambient) variables I decided after some discussions with Simon Lightfoot and Brian Egan to use just a simple class (so that you can if you really need even create more than one Locator although **I would not advise to do that**  in most cases).

**Since 2.0.0**
Although the approach with a global variable worked well, it has its limitations if you want to use `GetIt` across multiple packages. Therefore now GetIt itself is a singleton and the default way to access an instance of `GetIt` is to call:

```Dart
GetIt getIt = GetIt.instance;

//There is also a shortcut (if you don't like it just ignore it):
GetIt getIt = GetIt.I;
```

Through this any call to `instance` in any package of a project will get the same instance of `GetIt`. I still recommend just to assign the instance to a global variable in your project as it is more convenient and doesn't harm (Also it allows you to give your service locator your own name).


```Dart
GetIt sl = GetIt.instance;
```

> You can use any name you want which makes Brian happy like (`sl, backend, services...`) ;-) 

Before you can access your objects you have to register them within `GetIt` typically direct in your start-up code.

```Dart
sl.registerSingleton<AppModel>(AppModelImplementation());
sl.registerLazySingleton<RESTAPI>(() =>RestAPIImplementation());

// if you want to work just with the singleton:
GetIt.instance.registerSingleton<AppModel>(AppModelImplementation());
GetIt.I.registerLazySingleton<RESTAPI>(() =>RestAPIImplementation());
```

>`AppModel` and `RESTAPI` are both abstract base classes in this example

To access the registered objects call `get<Type>()` on your `GetIt`instance

```Dart
var myAppModel = sl.get<AppModel>();
```

Alternatively as `GetIt` is a callable class depending on the name you choose for your `GetIt`instance you can use the shorter version:

```Dart
var myAppModel = sl<AppModel>();

// as Singleton:
var myAppModel = GetIt.instance<AppModel>();
var myAppModel = GetIt.I<AppModel>();
```


## Different ways of registration

>Although I always would recommend using an abstract base class as registration type so that you can vary the implementations you don't have to do this. You can also register concrete types.

`GetIt` offers different ways how objects are registered that effect the lifetime of this objects.

### Factory

```Dart 
void registerFactory<T>(FactoryFunc<T> func)
```

You have to pass a factory function `func` that returns an NEW instance of an implementation of `T`. Each time you call `get<T>()` you will get a new instance returned.

### Singleton && LazySingleton

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

Additionally you can register asynchronous Singletons which means Singletons that have an initialisation that requires async function calls. To be able to control such asynchronous start-up behaviour GetIt supports mechanisms to ensure the correct initialization sequence. 

## Asynchronous Singletons 

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

If you register any async Singletons `allReady` will complete only after all of them have completed their factory function. Like:




### Manual triggering **allReady**

By calling `signalReady(null)` on your `GetIt` instance the `Future` you can get from `allReady` will be completed.
This is the most basic way to synchronize your start-up. I recommend using one of the other ways as they are more flexible and express your intention more clear.


### Automatic ready signal
In the previous method where you have to call `signalReady` manually  to trigger the *ready* event. Additionally all your registrations have an internal *ready* state if you pass `signalsReady=true` as optional parameter on registration.

The full function definition of `signalReady` looks like this:

```Dart
void signalReady(Object instance) {
```

By calling it with an registered instance you mark its registration as **ready**.
When all registrations are signalled, `ready` automatically emits an items and `readyFuture`is signalled.

Typically the registered service will do that on its own like:

```Dart
`GetIt.instance.signalReady(this)`
```
As GetIt is a singleton this can also be done from external packages if they use GetIt.

**If you have marked any registrations with `signalsReady` and you call `signalReady()` while not all of them are ready, an Exception is thrown.** 
So either you use manual **OR** automatic signalling. You can not mix them because in most cases this would lead to state errors



#### Implicit
Which means `providerFunc` has to return a `Future` and contains the instance creation as well as the initialization. 

A typical pattern would look like this:

```Dart
abstract class Service1{}

class Service1Implementation implements Service1
{
  Future init(){
    // dummy async call
    return Future.delayed(Duration(microseconds: 1));
  }
}

...

var sl = GetIt.instance;

sl.registerSingletonAsync<Service1>((_) async {
  var instance = Service1Implementation();
  await instance.init();
  return instance;
});
```

or a bit shorter and nicer ;-)

```Dart
sl.registerSingletonAsync<Service1>((_) => Service1Implementation()..init());
```

This will automatically complete the internally used `Completer` and mark this Singleton as ready.

#### Manually
In the previous example we ignored the the parameter that the factory function gets passed in when called by GetIt. It is actually the internally used completer, so you can use it to signal manually at any place you want that the instance is ready like in this example:

```Dart
class Service2Implementation implements Service2
{
  Service2(Completer completer)
  {
    _init(completer); // we call _init here without awaiting it.
  }

  Future _init(Completer completer) async
  {
    // dummy async call
    await Future.delayed(Duration(microseconds: 1));
    // From here on we are ready
    completer.complete();  }
}

...
var sl = GetIt.instance;

sl.registerSingletonAsync<Service2>((completer) => Service2Implementation(completer));
```

### Manually Synchronizing of async Singletons
Besides the possibility to provide a list of `Type`s that a Singleton depends on there are additional functions to check the current state of the initialisation to manually synchronize the different instances and the rest of the App. **You only can access such a Singleton with `get()` if it has signalled that it is ready.**

With `isReady` you can wait for the completion of an instance.

```Dart
/// [T] Type of the factory/Singleton to be waited for
/// [instance] registered instance to be waited for
/// [instanceName] factory/Singleton to be waited for that was registered by name instead of a type.
/// You should only use one of the
/// If you pass a [timeout], an [WaitingTimeOutException] will be thrown if not all Singletons
/// were ready in the given time. The Exception contains details on which Singletons are not ready yet.
Future<void> isReady<T>(
    {Object instance, String instanceName, Duration timeout});
```

If you want to wait that all async Singeltons are ready for instance by using a `FutureBuilder` you can use `allReady`:

```Dart
Future<void> allReady({Duration timeout});
```

Additionally GetIt has two complementary functions `isReadySync` and `isAllReadySync` that allows to check the state synchronously without awaiting. 

You also can use `getAsync` to wait and directly access an async Singleton.

### How to make a non async Singleton wait
In some case you might have a normal Singleton that doesn't have an async initialisation function but that depends on other async Singletons. In this case you still use `registerSingletonAsync` in the following way:

```Dart
sl.registerSingletonAsync<Service1>((_) => Future.value(NonAsyncService()), dependsOn: [Service1,Service2]);
```



**You only can synchronize async instances with each other! Not normal Singletons**

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