part of 'get_it.dart';

/// Two handy function that helps me to express my intention clearer and shorter to check for runtime
/// errors
void throwIf(bool condition, Object error) {
  if (condition) throw (error);
}

void throwIfNot(bool condition, Object error) {
  if (!condition) throw (error);
}

/// You will see a rather esoteric looking test `(const Object() is! T)` at several places
/// /// it tests if [T] is a real type and not Object or dynamic

/// For each registered factory/singleton a [_ServiceFactory<T>] is created
/// it holds either the instance of a Singleton or/and the creation functions
/// for creating an instance when [get] is called
///
/// There are three different types
enum _ServiceFactoryType {
  alwaysNew,

  /// factory which means on every call of [get] a new instance is created
  constant, // normal singleton
  lazy, // lazy
}

/// If I use `Singleton` without specifier in the comments I mean normal and lazy

class _ServiceFactory<T> {
  final _ServiceFactoryType factoryType;

  /// Because of the different creation methods we need alternative factory functions
  /// only one of them is always set.
  final FactoryFunc<T> creationFunction;
  final FactoryFuncAsync<T> asyncCreationFunction;
  // We need a separate function type here because it gets passes a completer
  final SingletonProviderFunc<T> asyncSingletonCreationFunction;

  /// In case of a named registration the instance name is here stored for easy access
  final String instanceName;

  /// true if one of the async registration functions have been used
  final bool isAsync;

  /// If a an existing Object gets registered or an async Singleton has finished its creation it is stored here
  Object instance;

  /// the type that was used when registering. used for runtime checks
  Type registrationType;

  /// to enable async Singletons to signal that they are ready (their initialization is finished)
  /// they get passed this completer in their factory function.
  Completer _readyCompleter;

  /// the returned future of pending async factory calls
  Future<T> pendingResult;

  bool get isReady => _readyCompleter.isCompleted;

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

  /// returns an instance depending on the type of the registration if [async==false]
  T getObject() {
    try {
      switch (factoryType) {
        case _ServiceFactoryType.alwaysNew:
          return creationFunction();
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

  /// returns an instance depending on the type of the registration if [async==true]
  Future<T> getObjectAsync() async {
    throwIfNot(
        isAsync,
        StateError(
            'You can only access registered factories/objects this way if they are created asynchronously'));
    try {
      switch (factoryType) {
        case _ServiceFactoryType.alwaysNew:
          return asyncCreationFunction();
          break;
        case _ServiceFactoryType.constant:
          if (instance != null) {
            return Future<T>.value(instance);
          } else {
            assert(pendingResult != null);
            return pendingResult;
          }
          break;
        case _ServiceFactoryType.lazy:
          if (instance != null) {
            // We already have a finished instance
            return Future<T>.value(instance);
          } else {
            if (pendingResult !=
                null) // an async creation is already in progress
            {
              return pendingResult;
            }

            /// Seems this is really the first access to this async Signleton
            /// `FutureOr` can store either Futures or a simple value
            FutureOr<T> asyncResult =
                asyncSingletonCreationFunction(_readyCompleter);

            if (asyncResult is Future) {
              // This means we really got an async creation function passed that returns a future
              //
              // In this case we complete the completer automatically
              // as soon as the creation function is done
              pendingResult = (asyncResult as Future<T>).then((newInstance) {
                _readyCompleter.complete();
                instance = newInstance;
                return newInstance;
              });
              return pendingResult;
            } else {
              // This means the creation function has directly returned an instance and not a future
              // In this case the instance has to complete the completer
              instance = asyncResult as T;
              return Future<T>.value(instance);
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

class _GetItImplementation implements GetIt {
  /// stores all [_ServiceFactory] that get registered by Type
  final _factories = Map<Type, _ServiceFactory<dynamic>>();

  /// the ones that get registered by name.
  final _factoriesByName = Map<String, _ServiceFactory<dynamic>>();

  /// We still support a global ready signal mechanism for that we use this
  /// Completer. This feature will get deprecated unless users vote for it
  final _globalReadyCompleter = Completer();

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  @override
  bool allowReassignment = false;

  /// Is used by several other functions to retrieve the correct [_ServiceFactory]
  _ServiceFactory _findFactoryByNameOrType<T>(String instanceName) {
    /// We use an assert here instead of an `if..throw` because it gets called on every call
    /// of [get]
    /// `(const Object() is! T)` tests if [T] is a real type and not Object or dynamic
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

  /// retrieves or creates an instance of a registered type [T] depending
  /// on if the registration function used for this type or based on a name.
  @override
  T get<T>([String instanceName]) {
    var instanceFactory = _findFactoryByNameOrType<T>(instanceName);

    Object instance;
    if (instanceFactory.isAsync) {
      /// We use an assert here instead of an `if..throw` for performance reasons
      assert(instanceFactory.factoryType != _ServiceFactoryType.alwaysNew,
          "You can't use get with an async Factory of ${instanceName != null ? instanceName : T.toString()}.");
      assert(instanceFactory.isReady,
          'You tried to access an instance of ${instanceName != null ? instanceName : T.toString()} that was not ready yet');
      instance = instanceFactory.instance;
    } else {
      instance = instanceFactory.getObject();
    }

    assert(
        instance is T, "Object with name $instanceName has a different type (${instanceFactory.registrationType.toString()}) than the one that is inferred (${T.toString()}) where you call it");

    return instance;
  }

  /// Callable class so that you can write `GetIt.instance<MyType>` instead of 
  /// `GetIt.instance.get<MyType>`
  T call<T>([String instanceName]) {
    return get<T>(instanceName);
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

  /// I use a separate function for the async registration instead just a new parameter
  /// so make the intention explicit
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
        FutureGroup outerFutureGroup = FutureGroup();
        Future dependentFuture;
        if (dependsOn?.isNotEmpty ?? false) {
          var dependentFutureGroup = FutureGroup();
          dependsOn.forEach((type) {
            var dependentFactory = _factories[type];
            throwIf(
                dependentFactory == null,
                ArgumentError(
                    'Dependent Type $type is not registered in GetIt'));
            throwIfNot(dependentFactory.isAsync,
                ArgumentError('Dependent Type $type is an async Singleton'));
            dependentFutureGroup.add(dependentFactory._readyCompleter.future);
          });
          dependentFutureGroup.close();

          dependentFuture = dependentFutureGroup.future;
        } else {
          dependentFuture = Future.sync(() {}); // directly execute then
        }
        outerFutureGroup.add(dependentFuture);

        serviceFactory.pendingResult = outerFutureGroup.future
            .then((completedFutures) => completedFutures.last);

        /// if someone uses getAsync on an async Singleton that has not be started to get created
        /// because its dependend on other objects this doesn't wor because PendingResult is not set in
        /// that case
        dependentFuture.then((_) {
          var asyncResult =
              singletonFactoryFunc(serviceFactory._readyCompleter);
          Future<T> isReadyFuture;
          if (asyncResult is Future<T>) {
            // In this case we complete the completer automatically
            isReadyFuture = asyncResult.then((instance) {
              serviceFactory.instance = instance;
              // just in case if anyone has already completed this completer manually
              if (!serviceFactory.isReady) {
                serviceFactory._readyCompleter.complete();
              }
              return instance;
            });
          } else {
            serviceFactory.instance = instance;
            // In this case the instance has to complete the completer
            isReadyFuture = Future.value(asyncResult);
          }
          outerFutureGroup.add(isReadyFuture);
          outerFutureGroup.close();
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
      instanceFactory.pendingResult == null;
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
        .where((x) => (x.isAsync && !x.isReady))
        .forEach((f) => futures.add(f._readyCompleter.future));
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
    return factoryToGet.getObjectAsync();
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
    if (factoryToCheck.factoryType == _ServiceFactoryType.lazy &&
        !factoryToCheck.isReady) {
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
        .where((x) => (x.isAsync && !x.isReady))
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
    return factoryToCheck.isReady;
  }
}
