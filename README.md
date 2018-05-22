# get_it

### **IMPORTANT: You have to use Dart2 to use this component**


This is a simple **Service Locator** for Dart and Flutter projects. 

>If you are not familiar with the concept of Service Locators, its a way to decouple the interface (abstract base class) from a concrete implementation and at the same time allows to access the concrete implementation from everywhere in your App over the interface.
> I can only highly recommend to read this classic article by from Martin Fowler [Inversion of Control Containers and the Dependency Injection  pattern](https://martinfowler.com/articles/injection.html)

Accessing an object from anywhere in an App especially can be done by other was too but:

* If you use a Singleton you cannot easily switch the implementation to another like a mock version for unit tests
* IoC containers for Dependency Injections offer a similar functionality but with the cost of slow start-up time and less readability because you don't know where the magically injected object come from. As most IoC libs rely on reflection they cannot be used with Flutter. 


Typical usage:
* Accessing service objects like REST API clients, databases so that they easily can be mocked.
* Accessing View/AppModels from Flutter Views
* Because interface and implementations are decoupled you could also register Flutter Views with different implementations and decide at start-up which one you want to use e.g. depending on screen resolutions




## Getting Started

Most Service Locator libraries are implemented either as Singletons or static classes depending on the features of the programming languages so that they can be easily accessed. As Dart supports global (or euphemistic ambient) variables I decided after some discussions with Simon Lightfoot and Brian Egan to use just a simple class (so that you can if you really need even create more than one Locator although **I would not advise to do that**  in most cases).

So to use `GetIt` you only have to declare an instance of it in  your App, typically as global variable.


```Dart
GetIt getIt = new GetIt();
```

> You can use any name you want which makes Brian happy ;-) 

Before you can access your objects you have to register them within `GetIt` typically direct in your start-up code.

```Dart
getIt.registerSingleton<AppModel>(new AppModelImplementation());
getIt.registerLazySingleton<RESTAPI>(() =>new RestAPIImplementation());
```

>`AppModel` and `RESTAPI` are both abstract base classes in this example

To access the registered objects call `get<Type>()` on your `GetIt`instance

```Dart
var myAppModel = getIt.get<AppModel>();
```

Alternatively as `GetIt` is a callable class depending on the name you choose for your `GetIt`instance you can use the shorter version:

```Dart
var myAppModel = getIt<AppModel>();
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

  