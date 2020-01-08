library get_it;

import 'dart:async';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

typedef FactoryFunc<T> = T Function();
typedef FactoryFuncAsync<T> = Future<T> Function();
typedef SingletonProviderFunc<T> = FutureOr Function(Completer initCompleter);

/// In case of an timeout while waiting for an instance to signal ready
/// This exception is thrown whith information about who is still waiting
class WaitingTimeOutException implements Exception {
  /// if you pass the [callee] parameter to [isReady]
  /// this maps lists which callees is waiting for whom
  final Map<Type, Type> isWaitingFor;

  /// Lists with Types that are still not ready
  final List<Type> notSignaledYet;

  /// Lists with Types that are already ready
  final List<Type> hasSignaled;

  WaitingTimeOutException(
      this.isWaitingFor, this.notSignaledYet, this.hasSignaled)
      : assert(isWaitingFor != null &&
            notSignaledYet != null &&
            hasSignaled != null);

  @override
  String toString() {
    print(
        'GetIt: There was a timeout while waiting for an instance to signal ready');
    print('The following instance types where waiting for completion');
    for (var entry in isWaitingFor.entries) {
      print('${entry.key} is waiting for ${entry.value}');
    }
    print('The following instance types have NOT signaled ready yet');
    for (var entry in notSignaledYet) {
      print('$entry');
    }
    print('The following instance types HAVE signaled ready yet');
    for (var entry in hasSignaled) {
      print('$entry');
    }
    return super.toString();
  }
}

/// Very simple and easy to use service locator
/// You register your object creation or an instance of an object with [registerFactory],
/// [registerSingleton] or [registerLazySingleton]
/// And retrieve the desired object using [get] or call your locator das as function as its a
/// callable class
abstract class GetIt {
  static GetIt _instance;

  static GetIt get instance {
    _instance ??= _GetItImplementation();
    return _instance;
  }

  static GetIt get I => instance;

  /// You should prefer to use the `instance()` method to access an instance of [GetIt].
  factory GetIt.asNewInstance() {
    return _GetItImplementation();
  }

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  bool allowReassignment = false;

  /// retrieves or creates an instance of a registered type [T] depending on the registration function used for this type or based on a name.
  T get<T>([String instanceName]);
  Future<T> getAsync<T>([String instanceName]);

  T call<T>([String instanceName]);

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerFactory<T>(FactoryFunc<T> func, {String instanceName});
  void registerFactoryAsync<T>(FactoryFuncAsync<T> func, {String instanceName});

  /// registers a type as Singleton by passing a factory function that will be called on the first call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// If [signalsReady] is set to `true` it means that the future that you can get from `allReady()`  cannot complete until this
  /// registration was signalled ready by calling [signalsReady(instance)]
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  /// [registerLazySingleton] does not influence [allReady]
  void registerLazySingleton<T>(FactoryFunc<T> func, {String instanceName});

  /// [registerLazySingletonAsync] does not influence [allReady]
  void registerLazySingletonAsync<T>(SingletonProviderFunc<T> func,
      {String instanceName});

  /// registers a type as Singleton by passing an [instance] of that type
  ///  that will be returned on each call of [get] on that type
  /// [T] type to register
  /// If [signalsReady] is set to `true` it means that the future you can get from `allReady()`  cannot complete until this
  /// registration was signalled ready by calling [signalsReady(instance)]
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerSingleton<T>(T instance, {String instanceName});

  /// [providerFunc] is executed immediately. If it returns an object the object has to complete the completer.
  /// if it returns a future the completer will be completed automatically when that future completes
  void registerSingletonAsync<T>(SingletonProviderFunc<T> providerFunc,
      {String instanceName, Iterable<Type> dependsOn});

  /// Clears all registered types. Handy when writing unit tests
  void reset();

  /// Clears the instance of a lazy singleton registered type, being able to call the factory function on the first call of [get] on that type.
  void resetLazySingleton<T>(
      {Object instance,
      String instanceName,
      void Function(T) disposingFunction});

  /// Unregister an [instance] of an object or a factory/singleton by Type [T] or by name [instanceName]
  /// if you need to dispose any resources you can do it using [disposingFunction] function
  /// that provides a instance of your class to be disposed
  void unregister<T>(
      {Object instance,
      String instanceName,
      void Function(T) disposingFunction});

  /// Returns a Future that is completed once all registered Factories/Singletons have signaled that they are ready
  /// Or when the global [signalReady] is called without an instance
  /// [timeout] if this is set and the future wasn't completed within that time period an
  Future<void> allReady({Duration timeout});

  /// Returns a Future that is completed when a given registered Factories/Singletons has signaled that it is ready
  /// [T] Type of the factory/Singleton to be waited for
  /// [instance] registered instance to be waited for
  /// [instanceName] factory/Singleton to be waited for that was registered by name instead of a type.
  /// You should only use one of the
  /// [timeout] if this is set and the future wasn't completed within that time period an
  Future<void> isReady<T>(
      {Object instance, String instanceName, Duration timeout});

  bool isReadySync<T>({Object instance, String instanceName});

  bool allReadySync();

  /// if [instance] is `null` and no factory/singleton is waiting to be signaled this will complete the future you got
  /// from [allReady]
  ///
  /// If [instance] has a value GetIt will search for the responsible factory/singleton and complete all futures you might
  /// have received by calling [isReady]
  /// Typically this is use in this way inside the registered objects init method `GetIt.instance.signalReady(this);`
  /// If all waiting singletons/factories have signaled ready the future you can get from [allReady] is automatically completed
  ///
  /// Both ways are mutual exclusive meaning either only use the global `signalReady()` and don't register a singlton/fatory as signaling ready
  /// Or let indiviual instance signal their ready state on their own.
  void signalReady();
}

void throwIf(bool condition, Object error) {
  if (condition) throw (error);
}

void throwIfNot(bool condition, Object error) {
  if (!condition) throw (error);
}

/// Very simple and easy to use service locator
/// You register your object creation or an instance of an object with [registerFactory],
/// [registerSingleton] or [registerLazySingleton]
/// And retrieve the desired object using [get] or call your locator das as function as its a
/// callable class
class _GetItImplementation implements GetIt {
  final _factories = Map<Type, _ServiceFactory<dynamic>>();
  final _factoriesByName = Map<String, _ServiceFactory<dynamic>>();

  final _globalReadyCompleter = Completer();

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  @override
  bool allowReassignment = false;

  /// retrieves or creates an instance of a registered type [T] depending on the registration function used for this type or based on a name.
  @override
  T get<T>([String instanceName]) {
    var instanceFactory = _findFactoryByNameOrType<T>(instanceName);

    Object instance;
    if (instanceFactory.isAsync) {
      throwIf(
          instanceFactory.factoryType == _ServiceFactoryType.alwaysNew,
          ArgumentError(
              "You can't use get with an async Factory of ${instanceName != null ? instanceName : T.toString()}."));
      throwIfNot(
          instanceFactory._readyCompleter.isCompleted,
          StateError(
              'You tried to access an instance of ${instanceName != null ? instanceName : T.toString()} that was not ready yet'));
      instance = instanceFactory.getObjectAsync();
    } else {
      instance = instanceFactory.getObject();
    }

    assert(instance is T,
        "Object with name $instanceName has a different type (${instanceFactory.registrationType.toString()}) than the one that is inferred (${T.toString()}) where you call it");

    return instance;
  }

  T call<T>([String instanceName]) {
    return get<T>(instanceName);
  }

  _ServiceFactory _findFactoryByNameOrType<T>(String instanceName) {
    print(T.toString());
    print(!(const Object() is! T));
    assert(
      !(!(const Object() is! T) && (instanceName == null)),
      'GetIt: You have to provide either a type or a name. Did you accidentally do  `var sl=GetIt.instance();` instead of var sl=GetIt.instance;',
    );

    _ServiceFactory<T> instanceFactory;
    if (instanceName != null) {
      instanceFactory = _factoriesByName[instanceName];
      assert(instanceFactory != null,
          "Object/factory with name $instanceName is not registered inside GetIt");
    } else {
      instanceFactory = _factories[T];
      assert(instanceFactory != null,
          "No type ${T.toString()} is registered inside GetIt.\n Did you forget to pass an instance name? \n(Did you accidentally do  GetIt sl=GetIt.instance(); instead of GetIt sl=GetIt.instance;)");
    }
    return instanceFactory;
  }

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  @override
  void registerFactory<T>(FactoryFunc<T> func, {String instanceName}) {
    _register<T>(
        type: _ServiceFactoryType.alwaysNew,
        instanceName: instanceName,
        factoryFunc: func,
        isAsync: false);
  }

  @override
  void registerFactoryAsync<T>(FactoryFuncAsync<T> asyncFunc,
      {String instanceName}) {
    _register<T>(
        type: _ServiceFactoryType.alwaysNew,
        instanceName: instanceName,
        factoryFuncAsync: asyncFunc,
        isAsync: true);
  }

  /// registers a type as Singleton by passing a factory function that will be called on the first call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// If [signalsReady] is set to `true` it means that the future you can get from `allReady()`  cannot complete until this
  /// registration was signalled ready by calling [signalsReady(instance)]
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  @override
  void registerLazySingleton<T>(FactoryFunc<T> func,
      {String instanceName, bool signalsReady = false}) {
    _register<T>(
        type: _ServiceFactoryType.lazy,
        instanceName: instanceName,
        factoryFunc: func,
        isAsync: signalsReady);
  }

  /// registers a type as Singleton by passing an [instance] of that type
  ///  that will be returned on each call of [get] on that type
  /// [T] type to register
  /// If [signalsReady] is set to `true` it means that the future you can get from `allReady()`  cannot complete until this
  /// registration was signalled ready by calling [signalsReady(instance)]
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  @override
  void registerSingleton<T>(T instance, {String instanceName}) {
    _register<T>(
        type: _ServiceFactoryType.constant,
        instanceName: instanceName,
        instance: instance,
        isAsync: false);
  }

  @override
  void registerSingletonAsync<T>(SingletonProviderFunc<T> providerFunc,
      {String instanceName, Iterable<Type> dependsOn}) {
    _register<T>(
        type: _ServiceFactoryType.constant,
        instanceName: instanceName,
        isAsync: true,
        singletonFactoryFunc: providerFunc,
        dependsOn: dependsOn);
  }

  /// Clears all registered types. Handy when writing unit tests
  @override
  void reset() {
    _factories.clear();
    _factoriesByName.clear();
  }

  void _register<T>(
      {@required _ServiceFactoryType type,
      FactoryFunc<T> factoryFunc,
      FactoryFuncAsync<T> factoryFuncAsync,
      SingletonProviderFunc<T> singletonFactoryFunc,
      T instance,
      @required String instanceName,
      @required bool isAsync,
      Iterable<Type> dependsOn}) {
    print(T.toString());

    throwIf(
      (!(const Object() is! T) && (instanceName == null)),
      'GetIt: You have to provide either a type or a name. Did you accidentally do  `var sl=GetIt.instance();` instead of var sl=GetIt.instance;',
    );

    throwIf(
      (instanceName != null &&
          (_factoriesByName.containsKey(instanceName) && !allowReassignment)),
      ArgumentError("An object of name $instanceName is already registered"),
    );
    throwIf(
        (instanceName == null &&
            _factories.containsKey(T) &&
            !allowReassignment),
        ArgumentError("Type ${T.toString()} is already registered"));

    var serviceFactory = _ServiceFactory<T>(type,
        creationFunction: factoryFunc,
        asyncCreationFunction: factoryFuncAsync,
        asyncSingletonCreationFunction:
            type == _ServiceFactoryType.lazy && isAsync
                ? singletonFactoryFunc
                : null,
        instance: instance,
        isAsync: isAsync,
        instanceName: instanceName);

    if (instanceName == null) {
      _factories[T] = serviceFactory;
    } else {
      _factoriesByName[instanceName] = serviceFactory;
    }

    // if its an async singleton we start its creation function here after we check if
    // it is depdendent on other registered Singletons.
    if (isAsync) {
      if (type == _ServiceFactoryType.constant) {
        Future dependentFuture;
        if (dependsOn?.isNotEmpty ?? false) {
          var futureGroup = FutureGroup();
          dependsOn.forEach((type) {
            var dependentFactory = _factories[type];
            throwIf(
                dependentFactory == null,
                ArgumentError(
                    'Dependent Type $type is not registered in GetIt'));
            throwIfNot(dependentFactory.isAsync,
                ArgumentError('Dependent Type $type is an async Singleton'));
            futureGroup.add(dependentFactory.readyFuture);
          });
          futureGroup.close();

          dependentFuture = futureGroup.future;
        } else {
          dependentFuture = Future.sync(() {}); // directly execute then
        }
        dependentFuture.then((_) {
          var result = singletonFactoryFunc(serviceFactory._readyCompleter);
          if (result is Future) {
            // In this case we complete the completer automatically
            serviceFactory.result = ResultFuture(result.then((instance) {
              serviceFactory.instance = instance; 
              serviceFactory._readyCompleter.complete();
            }));
          } else {
            serviceFactory.instance = instance;
            // In this case the instance has to complete the completer
            serviceFactory.result = ResultFuture(Future.value(result));
          }
        });
      }
    }
  }

  /// Unregister an instance of an object or a factory/singleton by Type [T] or by name [instanceName]
  /// if you need to dispose any resources you can do it using [disposingFunction] function
  /// that provides a instance of your class to be disposed
  @override
  void unregister<T>(
      {Object instance,
      String instanceName,
      void Function(T) disposingFunction}) {
    _ServiceFactory factoryToRemove;
    if (instance != null) {
      factoryToRemove = _findFactoryByInstance(instance);
    } else {
      factoryToRemove = _findFactoryByNameOrType<T>(instanceName);
    }

    if (factoryToRemove.isNamedRegistration) {
      _factoriesByName.remove(factoryToRemove.instanceName);
    } else {
      _factories.remove(factoryToRemove.registrationType);
    }

    if (factoryToRemove.instance != null) {
      disposingFunction?.call(factoryToRemove.instance);
    }
  }

  /// Clears the instance of a lazy singleton registered type, being able to call the factory function on the first call of [get] on that type.
  @override
  void resetLazySingleton<T>(
      {Object instance,
      String instanceName,
      void Function(T) disposingFunction}) {
    _ServiceFactory instanceFactory;

    if (instance != null) {
      instanceFactory = _findFactoryByInstance(instance);
    } else {
      instanceFactory = _findFactoryByNameOrType<T>(instanceName);
    }
    assert(instanceFactory.factoryType == _ServiceFactoryType.lazy,
        'There is no type ${instance.runtimeType} registered as LazySingleton in GetIt');
    if (instanceFactory.instance != null) {
      disposingFunction?.call(instanceFactory.instance);
      instanceFactory.instance = null;
    }
  }

  _ServiceFactory _findFactoryByInstance(Object instance) {
    var registeredFactories = _factories.values
        .followedBy(_factoriesByName.values)
        .where((x) => identical(x.instance, instance));

    assert(registeredFactories.isNotEmpty,
        'There is no object type ${instance.runtimeType} registered in GetIt');

    assert(registeredFactories.length == 1,
        'One Instance more than once in getIt registered');
    return registeredFactories.first;
  }

  @override
  void signalReady() {
    /// Manual signalReady

    /// In case that there are still factories that are marked to wait for a signal
    /// but aren't signalled we throw an error with details which objects are concerned
    final notReadyTypes = _factories.entries
        .where((x) => (x.value.isAsync && !x.value.isReady))
        .map<String>((x) => x.key.toString())
        .toList();
    final notReadyNames = _factoriesByName.entries
        .where((x) => (x.value.isAsync && !x.value.isReady))
        .map<String>((x) => x.key)
        .toList();
    throwIf(
        notReadyNames.isNotEmpty || notReadyTypes.isNotEmpty,
        StateError(
            'Registered types/names: $notReadyTypes  / $notReadyNames should signal ready but are not ready'));

    _globalReadyCompleter.complete();
  }

  @override
  Future<void> allReady({Duration timeout}) {
    FutureGroup futures = FutureGroup();
    _factories.values
        .followedBy(_factoriesByName.values)
        .where((x) => (x.isAsync && !x._readyCompleter.isCompleted))
        .forEach((f) => futures.add(f.readyFuture));
    futures.close();
    if (timeout != null) {
      return futures.future.timeout(timeout);
    } else {
      return futures.future;
    }
  }

  @override
  Future<T> getAsync<T>([String instanceName]) {
    _ServiceFactory<T> factoryToGet;
    factoryToGet = _findFactoryByNameOrType<T>(instanceName);
    return factoryToGet.getObjectAsync() as Future<T>;
  }

  @override
  Future<void> isReady<T>(
      {Object instance, String instanceName, Duration timeout}) {
    _ServiceFactory factoryToCheck;
    if (instance != null) {
      factoryToCheck = _findFactoryByInstance(instance);
    } else {
      factoryToCheck = _findFactoryByNameOrType<T>(instanceName);
    }
    assert(
        factoryToCheck.isAsync &&
            factoryToCheck.registrationType != _ServiceFactoryType.alwaysNew,
        'You only can use this function on async Singletons');
    if (factoryToCheck.factoryType == _ServiceFactoryType.lazy && !factoryToCheck._readyCompleter.isCompleted)
    {
      return factoryToCheck.getObjectAsync();
    }    
    if (timeout != null) {
      return factoryToCheck._readyCompleter.future.timeout(timeout);
    } else {
      return factoryToCheck._readyCompleter.future;
    }
  }

  @override
  void registerLazySingletonAsync<T>(SingletonProviderFunc<T> func,
      {String instanceName}) {
    _register<T>(
        isAsync: true,
        type: _ServiceFactoryType.lazy,
        instanceName: instanceName,
        singletonFactoryFunc: func);
  }

  @override
  bool allReadySync() {
    final notReadyTypes = _factories.values
        .followedBy(_factoriesByName.values)
        .where((x) => (x.isAsync && !x._readyCompleter.isCompleted))
        .map<String>((x) {
      if (x.isNamedRegistration) {
        return 'Object ${x.instanceName} has not completed';
      } else {
        return 'Registered object of Type ${x.registrationType.toString()} has not completed';
      }
    }).toList();
    if (notReadyTypes.isNotEmpty) {
      // Hack to only output this in debug mode;
      assert(() {
        print(notReadyTypes);
        return true;
      }());
    }
    return notReadyTypes.isEmpty;
  }

  @override
  bool isReadySync<T>({Object instance, String instanceName}) {
    _ServiceFactory factoryToCheck;
    if (instance != null) {
      factoryToCheck = _findFactoryByInstance(instance);
    } else {
      factoryToCheck = _findFactoryByNameOrType<T>(instanceName);
    }
    assert(
        factoryToCheck.isAsync &&
            factoryToCheck.registrationType != _ServiceFactoryType.alwaysNew,
        'You only can use this function on async Singletons');
    return factoryToCheck._readyCompleter.isCompleted;
  }
}

enum _ServiceFactoryType { alwaysNew, constant, lazy }

class _ServiceFactory<T> {
  final _ServiceFactoryType factoryType;
  final FactoryFunc creationFunction;
  final FactoryFuncAsync asyncCreationFunction;
  // We need a separate function type here because it gets passes a completer
  final SingletonProviderFunc asyncSingletonCreationFunction;
  final String instanceName;
  final bool isAsync;
  Object instance;
  Type registrationType;
  Completer _readyCompleter;
  ResultFuture result;

  bool get isReady => _readyCompleter.isCompleted;

  Future<void> get readyFuture {
    if (isAsync) {
      return _readyCompleter.future;
    }
    // TODO check which exeption type is best here or if its an error
    throw (Exception("You can't await this instance"));
  }

  bool get isNamedRegistration => instanceName != null;

  _ServiceFactory(this.factoryType,
      {this.creationFunction,
      this.asyncCreationFunction,
      this.asyncSingletonCreationFunction,
      this.instance,
      this.isAsync = false,
      this.instanceName}) {
    registrationType = T;
    if (isAsync) {
      _readyCompleter = Completer();
    }
  }

  T getObject() {
    try {
      switch (factoryType) {
        case _ServiceFactoryType.alwaysNew:
          return creationFunction() as T;
          break;
        case _ServiceFactoryType.constant:
          return instance as T;
          break;
        case _ServiceFactoryType.lazy:
          if (instance == null) {
            instance = creationFunction();
          }
          return instance as T;
          break;
        default:
          throw (StateError('Impossible factoryType'));
      }
    } catch (e, s) {
      print("Error while creating ${T.toString()}");
      print('Stack trace:\n $s');
      rethrow;
    }
  }

  Future<T> getObjectAsync() async {
    throwIfNot(
        isAsync,
        StateError(
            'You can only access registered factories/objects this way if they are created asynchronously'));
    try {
      switch (factoryType) {
        case _ServiceFactoryType.alwaysNew:
          return asyncCreationFunction() as Future<T>;
          break;
        case _ServiceFactoryType.constant:
          assert(result.isComplete);
          if (result.result.isValue) {
            return result.result.asValue as T;
          }
          if (result.result.isError) {
            throw (result.result.asError);
          }
          break;
        case _ServiceFactoryType.lazy:
          if (result != null && result.isComplete) {
            if (result.result.isValue) {
              return result.result.asValue as T;
            }
            if (result.result.isError) {
              throw (result.result.asError);
            }
          } else {
            var asyncResult = asyncSingletonCreationFunction(_readyCompleter);

            if (asyncResult is Future) {
              // In this case we complete the completer automatically
              result = ResultFuture<T>(asyncResult.then((instance) {
                _readyCompleter.complete();
                return instance;
              }));
              return result;
            } else {
              // In this case the instance has to complete the completer
              instance = asyncResult;
              result = ResultFuture<T>(asyncResult);
              return result;
            }
          }
          break;
        default:
          throw (StateError('Impossible factoryType'));
      }
    } catch (e, s) {
      print("Error while creating ${T.toString()}");
      print('Stack trace:\n $s');
      rethrow;
    }
  }
}
