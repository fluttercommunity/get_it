[![Flutter Community: get_it](https://fluttercommunity.dev/_github/header/get_it)](https://github.com/fluttercommunity/community)

# get_it

>**Breaking Change with V2.0.0** 
you no longer can directly create instances of the type `GetIt` because `GetIt` is now a singleton please see [Getting Started](#getting-started).


### **IMPORTANT: You have to use Dart2 to use this component**

You can find here a [detailed blog post on how to use GetIt](https://www.burkharts.net/apps/blog/one-to-find-them-all-how-to-use-service-locators-with-flutter/)


This is a simple **Service Locator** for Dart and Flutter projects highly inspired by [Splat](https://github.com/reactiveui/splat). 

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

Through this any call to `instance`in any package of a project will get the same instance of `GetIt`. I still recommend just to assign the instance to a global variable in your project as it is more convenient and doesn't harm (Also it allows you to give your service locator your own name).


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

You have to pass a factory function `func` that returns an instance of an implementation of `T`. Each time you call `get<T>()` you will get a new instance returned.

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
If you really have to overwrite a registration, then you can by setting the property `allowReassignment==true`` . 

### Resetting GetIt

```Dart
  /// Clears all registered types. Handy when writing unit tests
  void reset()
```

## Experts region

### Named registration

**DON'T USE THIS IF YOU ARE REALLY KNOW WHAT YOU ARE DOING!!!**

This should only be your last resort as you can loose your type safety and lead the concept of a singleton add absurdum.
This was added following a request at https://github.com/fluttercommunity/get_it/issues/10

Ok you have been warned. All register functions have an optional parameter `instanceName`. If you provide a value here 
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