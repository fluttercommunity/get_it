// ignore_for_file: require_trailing_commas

part of 'get_it.dart';

/// Two handy functions that help me to express my intention clearer and shorter to check for runtime
/// errors
// ignore: avoid_positional_boolean_parameters
void throwIf(bool condition, Object error) {
  if (condition) throw error;
}

// ignore: avoid_positional_boolean_parameters
void throwIfNot(bool condition, Object error) {
  if (!condition) throw error;
}

const _isDebugMode = !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile');

void _debugOutput(Object message) {
  if (_isDebugMode) {
    if (!GetIt.noDebugOutput) {
      // ignore: avoid_print
      print(message);
    }
  }
}

/// You will see a rather esoteric looking test `(const Object() is! T)` at several places.
/// It tests if [T] is a real type and not Object or dynamic.

/// For each registered factory/singleton a [_ServiceFactory<T>] is created
/// it holds either the instance of a Singleton or/and the creation functions
/// for creating an instance when [get] is called
///
/// There are three different types:
enum _ServiceFactoryType {
  alwaysNew, // factory which means on every call of [get] a new instance is created
  constant, // normal singleton
  lazy, // lazy singleton
  cachedFactory, // cached factory
}

/// A single entry describing how to build (and possibly cache) an object.
///
/// - If `factoryType == alwaysNew` or `cachedFactory`, it represents a "factory" (create every time)
/// - If `factoryType == constant`, it represents a "singleton"
/// - If `factoryType == lazy`, it is a "lazy singleton"
///
/// The crucial difference in this modified version is that each `_ServiceFactory` is associated
/// with a **string key** (derived from `T.toString()`) rather than a raw `Type`.
class _ServiceFactory<T extends Object, P1, P2> {
  final _ServiceFactoryType factoryType;
  final _GetItImplementation _getItInstance;
  final _TypeRegistration registeredIn;
  final _Scope registrationScope;

  late final Type param1Type;
  late final Type param2Type;

  P1? lastParam1;
  P2? lastParam2;

  /// Because of the different creation methods we need alternative factory functions
  /// only one of them is always set.
  final FactoryFunc<T>? creationFunction;
  final FactoryFuncAsync<T>? asyncCreationFunction;
  final FactoryFuncParam<T, P1, P2>? creationFunctionParam;
  final FactoryFuncParamAsync<T, P1, P2>? asyncCreationFunctionParam;

  ///  Dispose function that is used when a scope is popped
  final DisposingFunc<T>? disposeFunction;

  /// In case of a named registration the instance name is here stored for easy access
  String? instanceName;

  /// true if one of the async registration functions have been used
  final bool isAsync;

  /// If an existing Object gets registered or an async/lazy Singleton has finished
  /// its creation, it is stored here
  T? _instance;
  WeakReference<T>? weakReferenceInstance;
  final bool useWeakReference;

  T? get instance =>
      weakReferenceInstance != null && weakReferenceInstance!.target != null
          ? weakReferenceInstance!.target
          : _instance;

  void resetInstance() {
    if (useWeakReference) {
      weakReferenceInstance = null;
    } else {
      _instance = null;
    }
  }

  /// For debug / sanity checks. Contains `T.toString()`.
  late final String registrationTypeString;

  /// to enable Singletons to signal that they are ready (their initialization is finished)
  late Completer _readyCompleter;

  /// the returned future of pending async factory calls or factory call with dependencies
  Future<T>? pendingResult;

  /// If other objects are waiting for this one
  /// they are stored here
  final List<String> objectsWaiting = [];

  bool get isReady => _readyCompleter.isCompleted;

  bool get isNamedRegistration => instanceName != null;

  String get debugName => '$instanceName : $registrationTypeString';

  bool get canBeWaitedFor =>
      shouldSignalReady || pendingResult != null || isAsync;

  final bool shouldSignalReady;

  int _referenceCount = 0;

  _ServiceFactory(
    this._getItInstance,
    this.factoryType, {
    this.creationFunction,
    this.asyncCreationFunction,
    this.creationFunctionParam,
    this.asyncCreationFunctionParam,
    T? instance,
    this.isAsync = false,
    this.instanceName,
    this.useWeakReference = false,
    required this.shouldSignalReady,
    required this.registrationScope,
    required this.registeredIn,
    this.disposeFunction,
  })  : _instance = instance,
        assert(
            !(disposeFunction != null &&
                instance != null &&
                instance is Disposable),
            ' You are trying to register type ${instance.runtimeType} '
            'that implements "Disposable" but you also provide a disposing function') {
    param1Type = P1;
    param2Type = P2;
    registrationTypeString = T.toString();
    _readyCompleter = Completer();
  }

  FutureOr dispose() {
    /// check if we are shadowing an existing Object
    final factoryThatWouldbeShadowed =
        _getItInstance._findFirstFactoryByNameAndStringKeyOrNull(
      instanceName,
      registrationTypeString,
      lookInScopeBelow: true,
    );

    final objectThatWouldbeShadowed = factoryThatWouldbeShadowed?.instance;
    if (objectThatWouldbeShadowed != null &&
        objectThatWouldbeShadowed is ShadowChangeHandlers) {
      objectThatWouldbeShadowed.onLeaveShadow(instance!);
    }

    if (instance is Disposable) {
      return (instance! as Disposable).onDispose();
    }
    //if a  LazySingletons was never accessed instance is null
    if (instance != null) {
      return disposeFunction?.call(instance!);
    }
  }

  /// returns an instance depending on the type of the registration if [async==false]
  T getObject(dynamic param1, dynamic param2) {
    assert(
      !(![_ServiceFactoryType.alwaysNew, _ServiceFactoryType.cachedFactory]
              .contains(factoryType) &&
          (param1 != null || param2 != null)),
      'You can only pass parameters to factories!',
    );

    try {
      switch (factoryType) {
        case _ServiceFactoryType.alwaysNew:
          if (creationFunctionParam != null) {
            // param1.runtimeType == param1Type should use 'is' but Dart does
            // not support this comparison. For the time being it is therefore
            // disabled
            // assert(
            //     param1 == null || param1.runtimeType == param1Type,
            //     'Incompatible Type passed as param1\n'
            //     'expected: $param1Type actual: ${param1.runtimeType}');
            // assert(
            //     param2 == null || param2.runtimeType == param2Type,
            //     'Incompatible Type passed as param2\n'
            //     'expected: $param2Type actual: ${param2.runtimeType}');
            return creationFunctionParam!(param1 as P1, param2 as P2);
          } else {
            return creationFunction!();
          }
        case _ServiceFactoryType.cachedFactory:
          if (weakReferenceInstance?.target != null &&
              param1 == lastParam1 &&
              param2 == lastParam2) {
            return weakReferenceInstance!.target!;
          } else {
            lastParam1 = param1 as P1?;
            lastParam2 = param2 as P2?;
            T newInstance;
            if (creationFunctionParam != null) {
              newInstance = creationFunctionParam!(param1 as P1, param2 as P2);
            } else {
              newInstance = creationFunction!();
            }
            weakReferenceInstance = WeakReference(newInstance);
            return newInstance;
          }
        case _ServiceFactoryType.constant:
          return instance!;
        case _ServiceFactoryType.lazy:
          if (instance == null) {
            if (useWeakReference) {
              if (weakReferenceInstance != null) {
                /// this means that the instance was already created and disposed
                _readyCompleter = Completer();
              }
              weakReferenceInstance = WeakReference(creationFunction!());
            } else {
              _instance = creationFunction!();
            }
            objectsWaiting.clear();
            _readyCompleter.complete();

            /// check if we are shadowing an existing Object
            final factoryThatWouldbeShadowed =
                _getItInstance._findFirstFactoryByNameAndStringKeyOrNull(
                    instanceName, registrationTypeString,
                    lookInScopeBelow: true);
            final objectThatWouldbeShadowed =
                factoryThatWouldbeShadowed?.instance;
            if (objectThatWouldbeShadowed != null &&
                objectThatWouldbeShadowed is ShadowChangeHandlers) {
              objectThatWouldbeShadowed.onGetShadowed(instance!);
            }
          }
          return instance!;
      }
    } catch (e, s) {
      _debugOutput('Error while creating $registrationTypeString');
      _debugOutput('Stack trace:\n $s');
      rethrow;
    }
  }

  /// returns an async instance depending on the type of the registration if [async==true] or
  /// if [dependsOn.isNotEmpty].
  Future<R> getObjectAsync<R>(dynamic param1, dynamic param2) async {
    assert(
      !(![_ServiceFactoryType.alwaysNew, _ServiceFactoryType.cachedFactory]
              .contains(factoryType) &&
          (param1 != null || param2 != null)),
      'You can only pass parameters to factories!',
    );

    throwIfNot(
      isAsync || pendingResult != null,
      StateError('You can only access registered factories/objects '
          'this way if they are created asynchronously'),
    );
    try {
      switch (factoryType) {
        case _ServiceFactoryType.alwaysNew:
          if (asyncCreationFunctionParam != null) {
            // param1.runtimeType == param1Type should use 'is' but Dart does
            // not support this comparison. For the time being it is therefore
            // disabled
            // assert(
            //     param1 == null || param1.runtimeType == param1Type,
            //     'Incompatible Type passed a param1\n'
            //     'expected: $param1Type actual: ${param1.runtimeType}');
            // assert(
            //     param2 == null || param2.runtimeType == param2Type,
            //     'Incompatible Type passed a param2\n'
            //     'expected: $param2Type actual: ${param2.runtimeType}');
            return asyncCreationFunctionParam!(param1 as P1, param2 as P2)
                as Future<R>;
          } else {
            return asyncCreationFunction!() as Future<R>;
          }
        case _ServiceFactoryType.cachedFactory:
          if (weakReferenceInstance?.target != null &&
              param1 == lastParam1 &&
              param2 == lastParam2) {
            return Future<R>.value(weakReferenceInstance!.target! as R);
          } else {
            if (asyncCreationFunctionParam != null) {
              lastParam1 = param1 as P1?;
              lastParam2 = param2 as P2?;
              return asyncCreationFunctionParam!(param1 as P1, param2 as P2)
                  .then((value) {
                weakReferenceInstance = WeakReference(value);
                return value;
              }) as Future<R>;
            } else {
              return asyncCreationFunction!().then((value) {
                weakReferenceInstance = WeakReference(value);
                return value;
              }) as Future<R>;
            }
          }
        case _ServiceFactoryType.constant:
          if (instance != null) {
            return Future<R>.value(instance as R);
          } else {
            assert(pendingResult != null);
            return pendingResult! as Future<R>;
          }
        case _ServiceFactoryType.lazy:
          if (instance != null) {
            // We already have a finished instance
            return Future<R>.value(instance as R);
          } else {
            if (pendingResult !=
                null) // an async creation is already in progress
            {
              return pendingResult! as Future<R>;
            }

            /// Seems this is really the first access to this async Singleton
            final asyncResult = asyncCreationFunction!();

            pendingResult = asyncResult.then((newInstance) {
              if (!shouldSignalReady) {
                /// only complete automatically if the registration wasn't marked with
                /// [signalsReady==true]
                _readyCompleter.complete();
                objectsWaiting.clear();
              }
              if (useWeakReference) {
                weakReferenceInstance = WeakReference(newInstance);
              } else {
                _instance = newInstance;
              }

              /// check if we are shadowing an existing Object
              final factoryThatWouldbeShadowed =
                  _getItInstance._findFirstFactoryByNameAndStringKeyOrNull(
                instanceName,
                registrationTypeString,
                lookInScopeBelow: true,
              );

              final objectThatWouldbeShadowed =
                  factoryThatWouldbeShadowed?.instance;
              if (objectThatWouldbeShadowed != null &&
                  objectThatWouldbeShadowed is ShadowChangeHandlers) {
                objectThatWouldbeShadowed.onGetShadowed(instance!);
              }
              return newInstance;
            });
            return pendingResult! as Future<R>;
          }
      }
    } catch (e, s) {
      _debugOutput('Error while creating $registrationTypeString');
      _debugOutput('Stack trace:\n $s');
      rethrow;
    }
  }
}

/// A registration group for a single `String key`.
/// Since multiple named factories can exist in one scope for the same base key,
/// we track them in `namedFactories`. There can also be a single "unnamed" factory
/// stored in `factories`.
class _TypeRegistration {
  final namedFactories = <String, _ServiceFactory>{};
  final factories = <_ServiceFactory>[];

  bool get isEmpty => factories.isEmpty && namedFactories.isEmpty;

  void dispose() {
    for (final f in factories.reversed) {
      f.dispose();
    }
    factories.clear();
    for (final f in namedFactories.values.toList().reversed) {
      f.dispose();
    }
    namedFactories.clear();
  }

  _ServiceFactory? getFactory(String? name) {
    return name != null ? namedFactories[name] : factories.firstOrNull;
  }
}

/// Represents one "layer" (scope) in the service locator.
/// Each scope can hide registrations from a scope below it if a new registration
/// for the same (string) key is added.
class _Scope {
  final String? name;
  final ScopeDisposeFunc? disposeFunc;
  bool isFinal = false;
  bool isPopping = false;

  /// keyed by `T.toString()`.
  // ignore: prefer_collection_literals
  final typeRegistrations = LinkedHashMap<String, _TypeRegistration>();

  _Scope({this.name, this.disposeFunc});

  Future<void> reset({required bool dispose}) async {
    if (dispose) {
      for (final factory in allFactories.reversed) {
        await factory.dispose();
      }
    }
    typeRegistrations.clear();
  }

  List<_ServiceFactory> get allFactories =>
      typeRegistrations.values.fold<List<_ServiceFactory>>(
        [],
        (sum, x) => sum..addAll([...x.factories, ...x.namedFactories.values]),
      );

  Future<void> dispose() async {
    await disposeFunc?.call();
  }

  /// Return all instances of a requested generic "key" from this scope
  Iterable<T> getAll<T extends Object>({
    dynamic param1,
    dynamic param2,
  }) {
    final regKey = T.toString();
    final _TypeRegistration? typeRegistration = typeRegistrations[regKey];
    if (typeRegistration == null) return [];

    final fs = [
      ...typeRegistration.factories,
      ...typeRegistration.namedFactories.values
    ];
    final instances = <T>[];
    for (final f in fs) {
      if (f.isAsync || f.pendingResult != null) {
        /// We use an assert here instead of an `if..throw` for performance reasons
        assert(
          f.factoryType == _ServiceFactoryType.constant ||
              f.factoryType == _ServiceFactoryType.lazy,
          "You can't use getAll with an async Factory of $regKey.",
        );
        throwIfNot(
          f.isReady,
          StateError(
            'You tried to access an instance of $regKey that is not ready yet',
          ),
        );
        instances.add(f.instance! as T);
      } else {
        instances.add(f.getObject(param1, param2) as T);
      }
    }
    return instances;
  }

  Future<Iterable<T>> getAllAsync<T extends Object>({
    dynamic param1,
    dynamic param2,
  }) async {
    final regKey = T.toString();
    final _TypeRegistration? typeRegistration = typeRegistrations[regKey];
    if (typeRegistration == null) return [];

    final fs = [
      ...typeRegistration.factories,
      ...typeRegistration.namedFactories.values
    ];
    final instances = <T>[];
    for (final f in fs) {
      final T instance;
      if (f.isAsync || f.pendingResult != null) {
        instance = await f.getObjectAsync<T>(param1, param2);
      } else {
        instance = f.getObject(param1, param2) as T;
      }
      instances.add(instance);
    }
    return instances;
  }
}

/// The core implementation
class _GetItImplementation implements GetIt {
  static const _baseScopeName = 'baseScope';
  final _scopes = [_Scope(name: _baseScopeName)];

  _Scope get _currentScope => _scopes.last;

  _GetItImplementation();

  @override
  void Function(bool pushed)? onScopeChanged;

  /// We still support a global ready signal mechanism for that we use this
  /// Completer.
  final _globalReadyCompleter = Completer();

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  @override
  bool allowReassignment = false;

  /// By default it's throws error when [allowReassignment]= false. and trying to register same type
  /// If you really need, you can disable the Asserts / Error by setting[skipDoubleRegistration]= true
  @visibleForTesting
  @override
  bool skipDoubleRegistration = false;

  @override
  bool allowRegisterMultipleImplementationsOfoneType = false;

  @override
  void enableRegisteringMultipleInstancesOfOneType() {
    allowRegisterMultipleImplementationsOfoneType = true;
  }

  /// Tries to find a factory in any scope from top to bottom for the given
  /// `[typeKey]` (i.e. `T.toString()`) plus an optional `[instanceName]`.
  _ServiceFactory<T, dynamic, dynamic>?
      _findFirstFactoryByNameAndStringKeyOrNull<T extends Object>(
    String? instanceName,
    String typeKey, {
    bool lookInScopeBelow = false,
  }) {
    int scopeLevel = _scopes.length - (lookInScopeBelow ? 2 : 1);

    while (scopeLevel >= 0) {
      final scope = _scopes[scopeLevel];
      final typeRegistration = scope.typeRegistrations[typeKey];
      if (typeRegistration != null) {
        final foundFactory = typeRegistration.getFactory(instanceName);
        if (foundFactory != null) {
          return foundFactory as _ServiceFactory<T, dynamic, dynamic>?;
        }
      }
      scopeLevel--;
    }
    return null;
  }

  /// Same as above but must succeed or throw
  _ServiceFactory _findFactoryByNameAndStringKey<T extends Object>(
      String? instanceName, String typeKey) {
    final instanceFactory = _findFirstFactoryByNameAndStringKeyOrNull<T>(
      instanceName,
      typeKey,
    );
    throwIfNot(
      instanceFactory != null,
      StateError(
        'GetIt: Object/factory with '
        '${instanceName != null ? 'name $instanceName and ' : ''}type $typeKey '
        'is not registered inside GetIt.\n'
        '(Did you forget to register it?)',
      ),
    );
    return instanceFactory!;
  }

  /// retrieves or creates an instance of a registered type [T] depending on the registration
  /// function used for this type or based on a name.
  /// for factories you can pass up to 2 parameters [param1,param2] they have to match the types
  /// given at registration with [registerFactoryParam()]
  @override
  T get<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    final typeKey = (type ?? T).toString();
    final instanceFactory = _findFactoryByNameAndStringKey<T>(
      instanceName,
      typeKey,
    );
    final Object instance;
    if (instanceFactory.isAsync || instanceFactory.pendingResult != null) {
      /// We use an assert here instead of an `if..throw` for performance reasons
      assert(
        instanceFactory.factoryType == _ServiceFactoryType.constant ||
            instanceFactory.factoryType == _ServiceFactoryType.lazy,
        "You can't use get with an async Factory of $typeKey.",
      );
      throwIfNot(
        instanceFactory.isReady,
        StateError(
          'You tried to access an instance of $typeKey that is not ready yet',
        ),
      );
      instance = instanceFactory.instance!;
    } else {
      instance = instanceFactory.getObject(param1, param2);
    }
    return instance as T;
  }

  @override
  Iterable<T> getAll<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
  }) {
    if (!fromAllScopes) {
      return _currentScope.getAll<T>(param1: param1, param2: param2);
    } else {
      final result = <T>[];
      for (final scope in _scopes) {
        result.addAll(scope.getAll<T>(param1: param1, param2: param2));
      }
      throwIf(
        result.isEmpty,
        StateError(
          'GetIt: No Objects/factories of type $T found.',
        ),
      );
      return result;
    }
  }

  @override
  T call<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    return get<T>(
      instanceName: instanceName,
      param1: param1,
      param2: param2,
      type: type,
    );
  }

  @override
  Future<T> getAsync<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    final typeKey = (type ?? T).toString();
    final instanceFactory = _findFactoryByNameAndStringKey<T>(
      instanceName,
      typeKey,
    );
    return instanceFactory.getObjectAsync<T>(param1, param2);
  }

  @override
  Future<Iterable<T>> getAllAsync<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
  }) async {
    if (!fromAllScopes) {
      return _currentScope.getAllAsync<T>(param1: param1, param2: param2);
    } else {
      final result = <T>[];
      for (final scope in _scopes) {
        result
            .addAll(await scope.getAllAsync<T>(param1: param1, param2: param2));
      }
      throwIf(
        result.isEmpty,
        StateError(
          'GetIt: No Objects/factories of type $T found.',
        ),
      );
      return result;
    }
  }

  @override
  bool isRegistered<T extends Object>(
      {Object? instance, String? instanceName}) {
    if (instance != null) {
      return _findFirstFactoryByInstanceOrNull(instance) != null;
    } else {
      final typeKey = T.toString();
      return _findFirstFactoryByNameAndStringKeyOrNull<T>(
              instanceName, typeKey) !=
          null;
    }
  }

  @override
  void changeTypeInstanceName<T extends Object>({
    String? instanceName,
    required String newInstanceName,
    T? instance,
  }) {
    assert(
      instance != null || instanceName != null,
      'You must provide either an instance or an instanceName.',
    );

    final factoryToRename = (instance != null)
        ? _findFactoryByInstance(instance)
        : _findFactoryByNameAndStringKey<T>(instanceName, T.toString());

    throwIfNot(
      factoryToRename.isNamedRegistration,
      StateError('This instance is not registered with a name'),
    );
    final reg = factoryToRename.registeredIn;
    throwIf(
      reg.namedFactories.containsKey(newInstanceName),
      StateError(
        'There is already an instance of type ${factoryToRename.registrationTypeString} '
        'registered with the name $newInstanceName',
      ),
    );
    reg.namedFactories[newInstanceName] = factoryToRename;
    reg.namedFactories.remove(factoryToRename.instanceName);
    factoryToRename.instanceName = newInstanceName;
  }

  @override
  void registerFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, void, void>(
      type: _ServiceFactoryType.alwaysNew,
      instanceName: instanceName,
      factoryFunc: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
    );
  }

  @override
  void registerCachedFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, void, void>(
      type: _ServiceFactoryType.cachedFactory,
      instanceName: instanceName,
      factoryFunc: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
      useWeakReference: true,
    );
  }

  @override
  void registerCachedFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, P1, P2>(
      type: _ServiceFactoryType.cachedFactory,
      instanceName: instanceName,
      factoryFuncParam: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
      useWeakReference: true,
    );
  }

  @override
  void registerCachedFactoryAsync<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, void, void>(
      type: _ServiceFactoryType.cachedFactory,
      instanceName: instanceName,
      factoryFunc: factoryFunc,
      isAsync: true,
      shouldSignalReady: false,
      useWeakReference: true,
    );
  }

  @override
  void registerCachedFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, P1, P2>(
      type: _ServiceFactoryType.cachedFactory,
      instanceName: instanceName,
      factoryFuncParam: factoryFunc,
      isAsync: true,
      shouldSignalReady: false,
      useWeakReference: true,
    );
  }

  @override
  void registerFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, P1, P2>(
      type: _ServiceFactoryType.alwaysNew,
      instanceName: instanceName,
      factoryFuncParam: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
    );
  }

  @override
  void registerFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, void, void>(
      type: _ServiceFactoryType.alwaysNew,
      instanceName: instanceName,
      factoryFuncAsync: factoryFunc,
      isAsync: true,
      shouldSignalReady: false,
    );
  }

  @override
  void registerFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  }) {
    _register<T, P1, P2>(
      type: _ServiceFactoryType.alwaysNew,
      instanceName: instanceName,
      factoryFuncParamAsync: factoryFunc,
      isAsync: true,
      shouldSignalReady: false,
    );
  }

  @override
  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    bool useWeakReference = false,
  }) {
    _register<T, void, void>(
      type: _ServiceFactoryType.lazy,
      instanceName: instanceName,
      factoryFunc: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
      disposeFunc: dispose,
      useWeakReference: useWeakReference,
    );
  }

  @override
  T registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    _register<T, void, void>(
      type: _ServiceFactoryType.constant,
      instanceName: instanceName,
      instance: instance,
      isAsync: false,
      shouldSignalReady: signalsReady ?? false,
      disposeFunc: dispose,
    );
    return instance;
  }

  @override
  T registerSingletonIfAbsent<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
  }) {
    final existingFactory = _findFirstFactoryByNameAndStringKeyOrNull<T>(
      instanceName,
      T.toString(),
    );
    if (existingFactory != null) {
      throwIfNot(
        existingFactory.factoryType == _ServiceFactoryType.constant &&
            !existingFactory.isAsync,
        StateError(
            'registerSingletonIfAbsent can only be called for an existing normal Singleton'),
      );
      existingFactory._referenceCount++;
      return existingFactory.instance!;
    }

    final inst = factoryFunc();
    _register<T, void, void>(
      type: _ServiceFactoryType.constant,
      instance: inst,
      instanceName: instanceName,
      isAsync: false,
      shouldSignalReady: false,
      disposeFunc: dispose,
    );
    return inst;
  }

  @override
  void releaseInstance(Object instance) {
    final factoryReg = _findFactoryByInstance(instance);
    if (factoryReg._referenceCount < 1) {
      unregister(instance: instance);
    } else {
      factoryReg._referenceCount--;
    }
  }

  @override
  void registerSingletonWithDependencies<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    _register<T, void, void>(
      type: _ServiceFactoryType.constant,
      instanceName: instanceName,
      isAsync: false,
      factoryFunc: factoryFunc,
      dependsOn: dependsOn,
      shouldSignalReady: signalsReady ?? false,
      disposeFunc: dispose,
    );
  }

  @override
  void registerSingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    _register<T, void, void>(
      type: _ServiceFactoryType.constant,
      instanceName: instanceName,
      isAsync: true,
      factoryFuncAsync: factoryFunc,
      dependsOn: dependsOn,
      shouldSignalReady: signalsReady ?? false,
      disposeFunc: dispose,
    );
  }

  @override
  void registerLazySingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    bool useWeakReference = false,
  }) {
    _register<T, void, void>(
      isAsync: true,
      type: _ServiceFactoryType.lazy,
      instanceName: instanceName,
      factoryFuncAsync: factoryFunc,
      shouldSignalReady: false,
      disposeFunc: dispose,
      useWeakReference: useWeakReference,
    );
  }

  @override
  FutureOr unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
    bool ignoreReferenceCount = false,
  }) async {
    final factoryToRemove = instance != null
        ? _findFactoryByInstance(instance)
        : _findFactoryByNameAndStringKey<T>(instanceName, T.toString());

    throwIf(
      factoryToRemove.objectsWaiting.isNotEmpty,
      StateError(
          'There are still other objects waiting for this instance to signal ready'),
    );

    if (factoryToRemove._referenceCount > 0 && !ignoreReferenceCount) {
      factoryToRemove._referenceCount--;
      return;
    }
    final typeRegistration = factoryToRemove.registeredIn;
    if (factoryToRemove.isNamedRegistration) {
      typeRegistration.namedFactories.remove(factoryToRemove.instanceName);
    } else {
      typeRegistration.factories.remove(factoryToRemove);
    }
    if (typeRegistration.isEmpty) {
      factoryToRemove.registrationScope.typeRegistrations
          .remove(factoryToRemove.registrationTypeString);
    }

    if (factoryToRemove.instance != null) {
      if (disposingFunction != null) {
        final dispose = disposingFunction.call(factoryToRemove.instance! as T);
        if (dispose is Future) {
          await dispose;
        }
      } else {
        final dispose = factoryToRemove.dispose();
        if (dispose is Future) {
          await dispose;
        }
      }
    }
  }

  _ServiceFactory _findFactoryByInstance(Object instance) {
    final reg = _findFirstFactoryByInstanceOrNull(instance);
    throwIf(
      reg == null,
      StateError(
        'This instance of type ${instance.runtimeType} is not in GetIt.\n'
        'If it is a LazySingleton, did you use it at least once?',
      ),
    );
    return reg!;
  }

  _ServiceFactory? _findFirstFactoryByInstanceOrNull(Object instance) {
    return _allFactories
        .firstWhereOrNull((x) => identical(x.instance, instance));
  }

  List<_ServiceFactory> get _allFactories => _scopes
      .fold<List<_ServiceFactory>>([], (sum, s) => sum..addAll(s.allFactories));

  @override
  Future<void> reset({bool dispose = true}) async {
    if (dispose) {
      for (int i = _scopes.length - 1; i >= 0; i--) {
        await _scopes[i].dispose();
        await _scopes[i].reset(dispose: dispose);
      }
    }
    _scopes.removeRange(1, _scopes.length);
    await resetScope(dispose: dispose);
  }

  @override
  Future<void> resetScope({bool dispose = true}) async {
    if (dispose) {
      await _currentScope.dispose();
    }
    await _currentScope.reset(dispose: dispose);
  }

  bool _pushScopeInProgress = false;

  @override
  void pushNewScope({
    void Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
    bool isFinal = false,
  }) {
    throwIf(
      _pushScopeInProgress,
      StateError(
          'Cannot push a new scope inside the init function of another scope.'),
    );
    assert(scopeName != _baseScopeName,
        'The name "$_baseScopeName" is reserved for the base scope.');
    assert(
      scopeName == null ||
          _scopes.firstWhereOrNull((x) => x.name == scopeName) == null,
      'You already have a scope named $scopeName',
    );
    _pushScopeInProgress = true;
    _scopes.add(_Scope(name: scopeName, disposeFunc: dispose));
    try {
      init?.call(this);
      if (isFinal) {
        _scopes.last.isFinal = true;
      }
      onScopeChanged?.call(true);
    } catch (e) {
      final failedScope = _scopes.last;
      failedScope.isFinal = true;
      failedScope.reset(dispose: true);
      _scopes.removeLast();
      rethrow;
    } finally {
      _pushScopeInProgress = false;
    }
  }

  @override
  Future<void> pushNewScopeAsync({
    Future<void> Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
    bool isFinal = false,
  }) async {
    throwIf(
      _pushScopeInProgress,
      StateError(
          'Cannot push a new scope inside the init function of another scope.'),
    );
    assert(scopeName != _baseScopeName,
        'The name "$_baseScopeName" is reserved for the base scope.');
    assert(
      scopeName == null ||
          _scopes.firstWhereOrNull((x) => x.name == scopeName) == null,
      'You already have a scope named $scopeName',
    );
    _pushScopeInProgress = true;
    _scopes.add(_Scope(name: scopeName, disposeFunc: dispose));
    try {
      await init?.call(this);
      if (isFinal) {
        _scopes.last.isFinal = true;
      }
      onScopeChanged?.call(true);
    } catch (e) {
      final failedScope = _scopes.last;
      failedScope.isFinal = true;
      await failedScope.reset(dispose: true);
      _scopes.removeLast();
      rethrow;
    } finally {
      _pushScopeInProgress = false;
    }
  }

  @override
  Future<void> popScope() async {
    if (_currentScope.isPopping) return;
    throwIf(
      _pushScopeInProgress,
      StateError(
          'Cannot pop a scope inside the init function of another scope.'),
    );
    throwIfNot(
      _scopes.length > 1,
      StateError("You are already on the base scope. You can't pop that."),
    );
    final scopeToPop = _currentScope;
    scopeToPop.isFinal = true;
    scopeToPop.isPopping = true;
    await scopeToPop.dispose();
    await scopeToPop.reset(dispose: true);
    _scopes.remove(scopeToPop);
    onScopeChanged?.call(false);
  }

  @override
  Future<bool> popScopesTill(String name, {bool inclusive = true}) async {
    assert(
      name != _baseScopeName || !inclusive,
      "You can't pop the base scope",
    );
    if (!hasScope(name)) return false;

    var somethingPopped = false;
    var nextScopeToPop = _currentScope;

    while (nextScopeToPop.name != _baseScopeName &&
        hasScope(name) &&
        (nextScopeToPop.name != name || inclusive)) {
      final poppedName = nextScopeToPop.name;
      await dropScope(poppedName!);
      somethingPopped = true;
      nextScopeToPop = _scopes.lastWhere((x) => !x.isPopping);
    }

    if (somethingPopped) {
      onScopeChanged?.call(false);
    }
    return somethingPopped;
  }

  @override
  Future<void> dropScope(String scopeName) async {
    throwIf(
      _pushScopeInProgress,
      StateError(
          'Cannot drop a scope inside the init function of another scope.'),
    );
    if (currentScopeName == scopeName) {
      return popScope();
    }
    throwIfNot(
      _scopes.length > 1,
      StateError("You are already on the base scope. You can't drop that."),
    );
    final scope = _scopes.lastWhere(
      (s) => s.name == scopeName,
      orElse: () => throw ArgumentError("Scope $scopeName not found"),
    );
    if (scope.isPopping) return;
    scope.isFinal = true;
    scope.isPopping = true;
    await scope.dispose();
    await scope.reset(dispose: true);
    _scopes.remove(scope);
  }

  @override
  bool hasScope(String scopeName) {
    return _scopes.any((s) => s.name == scopeName);
  }

  @override
  String? get currentScopeName => _currentScope.name;

  void _register<T extends Object, P1, P2>({
    required _ServiceFactoryType type,
    FactoryFunc<T>? factoryFunc,
    FactoryFuncParam<T, P1, P2>? factoryFuncParam,
    FactoryFuncAsync<T>? factoryFuncAsync,
    FactoryFuncParamAsync<T, P1, P2>? factoryFuncParamAsync,
    T? instance,
    required String? instanceName,
    required bool isAsync,
    Iterable<Type>? dependsOn,
    required bool shouldSignalReady,
    DisposingFunc<T>? disposeFunc,
    bool useWeakReference = false,
  }) {
    final regKey = T.toString();

    _Scope registrationScope;
    int i = _scopes.length;
    do {
      i--;
      registrationScope = _scopes[i];
    } while (registrationScope.isFinal && i >= 0);
    assert(i >= 0, 'The baseScope should always be open.');

    final existingReg = registrationScope.typeRegistrations[regKey];
    if (existingReg != null) {
      if (instanceName != null) {
        throwIf(
          existingReg.namedFactories.containsKey(instanceName) &&
              !allowReassignment &&
              !skipDoubleRegistration,
          ArgumentError(
            'Object/factory with name $instanceName and type $regKey is already registered.',
          ),
        );
        if (skipDoubleRegistration &&
            !allowReassignment &&
            existingReg.namedFactories.containsKey(instanceName)) {
          return;
        }
      } else {
        if (existingReg.factories.isNotEmpty) {
          throwIfNot(
            allowReassignment ||
                allowRegisterMultipleImplementationsOfoneType ||
                skipDoubleRegistration,
            ArgumentError('Type $regKey is already registered.'),
          );
          if (skipDoubleRegistration && !allowReassignment) {
            return;
          }
        }
      }
    }

    if (instance != null) {
      final shadowCheck =
          _findFirstFactoryByNameAndStringKeyOrNull(instanceName, regKey);
      final objThatWouldBeShadowed = shadowCheck?.instance;
      if (objThatWouldBeShadowed != null &&
          objThatWouldBeShadowed is ShadowChangeHandlers) {
        objThatWouldBeShadowed.onGetShadowed(instance);
      }
    }

    final newReg = registrationScope.typeRegistrations
        .putIfAbsent(regKey, () => _TypeRegistration());

    // Check if the type or instance is WillSignalReady:
    bool detectWillSignalReady() {
      if (instance != null) {
        return instance is WillSignalReady;
      } else {
        return <T>[] is List<WillSignalReady>;
      }
    }

    // Combine with the user’s explicitly passed 'shouldSignalReady'
    // We want to ensure that if either is 'true', the final is 'true'.
    final finalShouldSignalReady = shouldSignalReady || detectWillSignalReady();

    final serviceFactory = _ServiceFactory<T, P1, P2>(
      this,
      type,
      registeredIn: newReg,
      registrationScope: registrationScope,
      creationFunction: factoryFunc,
      creationFunctionParam: factoryFuncParam,
      asyncCreationFunctionParam: factoryFuncParamAsync,
      asyncCreationFunction: factoryFuncAsync,
      instance: instance,
      isAsync: isAsync,
      instanceName: instanceName,
      shouldSignalReady: finalShouldSignalReady,
      disposeFunction: disposeFunc,
      useWeakReference: useWeakReference,
    );

    if (instanceName != null) {
      newReg.namedFactories[instanceName] = serviceFactory;
    } else {
      if (allowRegisterMultipleImplementationsOfoneType) {
        newReg.factories.add(serviceFactory);
      } else {
        if (newReg.factories.isNotEmpty) {
          newReg.factories[0] = serviceFactory;
        } else {
          newReg.factories.add(serviceFactory);
        }
      }
    }

    // If it's a normal "constant" singleton with no dependencies, or an immediate one, we are done.
    if (type == _ServiceFactoryType.constant &&
        !shouldSignalReady &&
        !isAsync &&
        (dependsOn?.isEmpty ?? true)) {
      return;
    }

    // If it's an async or a dependent singleton, set up its creation here:
    if ((isAsync || (dependsOn?.isNotEmpty ?? false)) &&
        type == _ServiceFactoryType.constant) {
      final outerGroup = FutureGroup();

      Future dependentFuture;
      if (dependsOn?.isNotEmpty ?? false) {
        final dependentGroup = FutureGroup();
        for (final dep in dependsOn!) {
          // handle "InitDependency"
          late final _ServiceFactory<Object, dynamic, dynamic>? depFactory;
          if (dep is InitDependency) {
            depFactory = _findFirstFactoryByNameAndStringKeyOrNull(
              dep.instanceName,
              dep.type.toString(),
            );
          } else {
            depFactory = _findFirstFactoryByNameAndStringKeyOrNull(
              null,
              dep.toString(),
            );
          }

          throwIf(depFactory == null,
              ArgumentError('Dependent Type $dep is not registered.'));
          throwIfNot(
            depFactory!.canBeWaitedFor,
            ArgumentError(
                'Dependent Type $dep is not an async Singleton or signalsReady.'),
          );
          depFactory.objectsWaiting.add(serviceFactory.registrationTypeString);
          dependentGroup.add(depFactory._readyCompleter.future);
        }
        dependentGroup.close();
        dependentFuture = dependentGroup.future;
      } else {
        dependentFuture = Future.sync(() {});
      }

      outerGroup.add(dependentFuture);
      dependentFuture.then((_) {
        Future isReadyFuture;
        if (!isAsync) {
          // SingletonWithDependencies
          serviceFactory._instance = factoryFunc!();
          final shadowCheck = _findFirstFactoryByNameAndStringKeyOrNull(
            instanceName,
            regKey,
            lookInScopeBelow: true,
          );
          final objShadowed = shadowCheck?.instance;
          if (objShadowed != null && objShadowed is ShadowChangeHandlers) {
            objShadowed.onGetShadowed(serviceFactory.instance!);
          }
          if (!serviceFactory.shouldSignalReady) {
            isReadyFuture = Future<T>.value(serviceFactory.instance!);
            serviceFactory._readyCompleter.complete(serviceFactory.instance!);
            serviceFactory.objectsWaiting.clear();
          } else {
            isReadyFuture = serviceFactory._readyCompleter.future;
          }
        } else {
          // Async Singleton with dependencies
          final asyncResult = factoryFuncAsync!();
          isReadyFuture = asyncResult.then((inst) {
            serviceFactory._instance = inst;
            final shadowCheck = _findFirstFactoryByNameAndStringKeyOrNull(
              instanceName,
              regKey,
              lookInScopeBelow: true,
            );
            final objShadowed = shadowCheck?.instance;
            if (objShadowed != null && objShadowed is ShadowChangeHandlers) {
              objShadowed.onGetShadowed(inst);
            }
            if (!serviceFactory.shouldSignalReady && !serviceFactory.isReady) {
              serviceFactory._readyCompleter.complete();
              serviceFactory.objectsWaiting.clear();
            }
            return inst;
          });
        }
        outerGroup.add(isReadyFuture);
        outerGroup.close();
      });

      serviceFactory.pendingResult =
          outerGroup.future.then((_) => serviceFactory.instance!);
    }
  }

  @override
  Future<void> allReady(
      {Duration? timeout, bool ignorePendingAsyncCreation = false}) {
    final futures = FutureGroup();
    for (final f in _allFactories) {
      if ((f.isAsync && !ignorePendingAsyncCreation) ||
          (!f.isAsync && f.pendingResult != null) ||
          f.shouldSignalReady) {
        if (!f.isReady && f.factoryType == _ServiceFactoryType.constant) {
          if (f.pendingResult != null) {
            // an async or dependent constant
            futures.add(f.pendingResult!);
            if (f.shouldSignalReady) {
              futures.add(f._readyCompleter.future);
            }
          } else {
            // non-async singletons that have signalReady
            futures.add(f._readyCompleter.future);
          }
        } else if (!f.isReady && f.factoryType == _ServiceFactoryType.lazy) {
          // lazy with signal ready => do nothing if not accessed
        }
      }
    }
    futures.close();
    final waitFuture = (timeout != null)
        ? futures.future
            .timeout(timeout, onTimeout: () => throw _createTimeoutError())
        : futures.future;
    return waitFuture;
  }

  @override
  bool allReadySync([bool ignorePendingAsyncCreation = false]) {
    final notReady = _allFactories
        .where((f) {
          final isCandidate = (f.isAsync && !ignorePendingAsyncCreation) ||
              (!f.isAsync && f.pendingResult != null) ||
              f.shouldSignalReady;
          return isCandidate && !f.isReady;
        })
        .where((f) =>
            f.factoryType == _ServiceFactoryType.constant ||
            f.factoryType == _ServiceFactoryType.lazy)
        .toList();

    if (notReady.isNotEmpty) {
      _debugOutput('Not yet ready objects:');
      for (final nr in notReady) {
        _debugOutput(nr.debugName);
      }
    }
    return notReady.isEmpty;
  }

  WaitingTimeOutException _createTimeoutError() {
    final allF = _allFactories;
    final waitedBy = Map.fromEntries(
      allF
          .where((f) =>
              (f.shouldSignalReady || f.pendingResult != null) &&
              !f.isReady &&
              f.objectsWaiting.isNotEmpty)
          .map((fw) => MapEntry(fw.debugName, fw.objectsWaiting.toList())),
    );
    final notReady = allF
        .where((x) =>
            (x.shouldSignalReady || x.pendingResult != null) && !x.isReady)
        .map((x) => x.debugName)
        .toList();
    final areReady = allF
        .where((x) =>
            (x.shouldSignalReady || x.pendingResult != null) && x.isReady)
        .map((x) => x.debugName)
        .toList();
    return WaitingTimeOutException(waitedBy, notReady, areReady);
  }

  @override
  Future<void> isReady<T extends Object>({
    Object? instance,
    String? instanceName,
    Duration? timeout,
    Object? callee,
  }) {
    final factoryToCheck = (instance != null)
        ? _findFactoryByInstance(instance)
        : _findFactoryByNameAndStringKey<T>(instanceName, T.toString());
    if (!factoryToCheck.isReady) {
      factoryToCheck.objectsWaiting.add(callee.runtimeType.toString());
    }
    if (factoryToCheck.isAsync &&
        factoryToCheck.factoryType == _ServiceFactoryType.lazy &&
        factoryToCheck.instance == null) {
      final f = factoryToCheck.getObjectAsync(null, null);
      return (timeout != null)
          ? f.timeout(timeout, onTimeout: () => throw _createTimeoutError())
          : f;
    }
    if (factoryToCheck.pendingResult != null) {
      return (timeout != null)
          ? factoryToCheck.pendingResult!.timeout(
              timeout,
              onTimeout: () => throw _createTimeoutError(),
            )
          : factoryToCheck.pendingResult!;
    }
    final fut = factoryToCheck._readyCompleter.future;
    return (timeout != null)
        ? fut.timeout(timeout, onTimeout: () => throw _createTimeoutError())
        : fut;
  }

  @override
  bool isReadySync<T extends Object>({Object? instance, String? instanceName}) {
    final factoryToCheck = (instance != null)
        ? _findFactoryByInstance(instance)
        : _findFactoryByNameAndStringKey<T>(instanceName, T.toString());
    throwIfNot(
      factoryToCheck.canBeWaitedFor &&
          factoryToCheck.factoryType != _ServiceFactoryType.alwaysNew,
      ArgumentError(
        'You can only use this function on Singletons that are async or that signalReady or have dependencies.',
      ),
    );
    return factoryToCheck.isReady;
  }

  @override
  void signalReady(Object? instance) {
    if (instance != null) {
      final reg = _findFactoryByInstance(instance);
      throwIfNot(
        reg.shouldSignalReady,
        ArgumentError.value(instance,
            'This instance of type ${instance.runtimeType} is not marked signalsReady==true.'),
      );
      throwIf(
        reg.isReady,
        StateError(
            'This instance of type ${instance.runtimeType} was already signalled.'),
      );
      reg._readyCompleter.complete();
      reg.objectsWaiting.clear();
    } else {
      final notReady = _allFactories
          .where((f) =>
              (f.shouldSignalReady || f.pendingResult != null) && !f.isReady)
          .map((f) => '${f.registrationTypeString}/${f.instanceName}')
          .toList();
      throwIf(
        notReady.isNotEmpty,
        StateError(
          "You can't signal ready globally if you have Singletons that must call signalReady themselves.\n"
          'Not ready yet: $notReady',
        ),
      );
      _globalReadyCompleter.complete();
    }
  }

  @override
  FutureOr resetLazySingleton<T extends Object>({
    T? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  }) async {
    final f = (instance != null)
        ? _findFactoryByInstance(instance)
        : _findFactoryByNameAndStringKey<T>(instanceName, T.toString());

    throwIfNot(
      f.factoryType == _ServiceFactoryType.lazy,
      StateError(
          'No type $T (name:$instanceName) registered as LazySingleton.'),
    );

    dynamic disposeReturn;
    if (f.instance != null) {
      if (disposingFunction != null) {
        disposeReturn = disposingFunction.call(f.instance! as T);
      } else {
        disposeReturn = f.dispose();
      }
    }
    f.resetInstance();
    f.pendingResult = null;
    f._readyCompleter = Completer();
    if (disposeReturn is Future) {
      await disposeReturn;
    }
  }

  @override
  bool checkLazySingletonInstanceExists<T extends Object>(
      {String? instanceName}) {
    final f = _findFactoryByNameAndStringKey<T>(instanceName, T.toString());
    throwIfNot(
      f.factoryType == _ServiceFactoryType.lazy,
      StateError(
        'There is no type $T (name:$instanceName) registered as LazySingleton',
      ),
    );
    return f.instance != null;
  }
}
