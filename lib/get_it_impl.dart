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

class _ServiceFactory<T extends Object, P1, P2> {
  final _ServiceFactoryType factoryType;

  final _GetItImplementation _getItInstance;
  final _TypeRegistration registeredIn;
  final _Scope registrationScope;

  late final Type param1Type;
  late final Type param2Type;

  /// Because of the different creation methods we need alternative factory functions
  /// only one of them is always set.
  final FactoryFunc<T>? creationFunction;
  final FactoryFuncAsync<T>? asyncCreationFunction;
  final FactoryFuncParam<T, P1, P2>? creationFunctionParam;
  final FactoryFuncParamAsync<T, P1, P2>? asyncCreationFunctionParam;

  ///  Dispose function that is used when a scope is popped
  final DisposingFunc<T>? disposeFunction;

  /// In case of a named registration the instance name is here stored for easy access
  final String? instanceName;

  /// true if one of the async registration functions have been used
  final bool isAsync;

  /// If an existing Object gets registered or an async/lazy Singleton has finished
  /// its creation, it is stored here
  Object? instance;

  /// the type that was used when registering, used for runtime checks
  late final Type registrationType;

  /// to enable Singletons to signal that they are ready (their initialization is finished)
  late Completer<T> _readyCompleter;

  /// the returned future of pending async factory calls or factory call with dependencies
  Future<T>? pendingResult;

  /// If other objects are waiting for this one
  /// they are stored here
  final List<Type> objectsWaiting = [];

  bool get isReady => _readyCompleter.isCompleted;

  bool get isNamedRegistration => instanceName != null;

  String get debugName => '$instanceName : $registrationType';

  bool get canBeWaitedFor =>
      shouldSignalReady || pendingResult != null || isAsync;

  final bool shouldSignalReady;

  _ServiceFactory(
    this._getItInstance,
    this.factoryType, {
    this.creationFunction,
    this.asyncCreationFunction,
    this.creationFunctionParam,
    this.asyncCreationFunctionParam,
    this.instance,
    this.isAsync = false,
    this.instanceName,
    required this.shouldSignalReady,
    required this.registrationScope,
    required this.registeredIn,
    this.disposeFunction,
  }) : assert(
            !(disposeFunction != null &&
                instance != null &&
                instance is Disposable),
            ' You are trying to register type ${instance.runtimeType} '
            'that implements "Disposable" but you also provide a disposing function') {
    registrationType = T;
    param1Type = P1;
    param2Type = P2;
    _readyCompleter = Completer();
  }

  FutureOr dispose() {
    /// check if we are shadowing an existing Object
    final factoryThatWouldbeShadowed =
        _getItInstance._findFirstFactoryByNameAndTypeOrNull(
      instanceName,
      type: T,
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
    if (instance != null) {
      // this can happen with LazySingletons that were never be used
      return disposeFunction?.call(instance! as T);
    }
  }

  /// returns an instance depending on the type of the registration if [async==false]
  T getObject(dynamic param1, dynamic param2) {
    assert(
      !(factoryType != _ServiceFactoryType.alwaysNew &&
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
        case _ServiceFactoryType.constant:
          return instance! as T;
        case _ServiceFactoryType.lazy:
          if (instance == null) {
            instance = creationFunction!();
            objectsWaiting.clear();
            _readyCompleter.complete(instance! as T);

            /// check if we are shadowing an existing Object
            final factoryThatWouldbeShadowed =
                _getItInstance._findFirstFactoryByNameAndTypeOrNull(
              instanceName,
              type: T,
              lookInScopeBelow: true,
            );

            final objectThatWouldbeShadowed =
                factoryThatWouldbeShadowed?.instance;
            if (objectThatWouldbeShadowed != null &&
                objectThatWouldbeShadowed is ShadowChangeHandlers) {
              objectThatWouldbeShadowed.onGetShadowed(instance!);
            }
          }
          return instance! as T;
        default:
          throw StateError('Impossible factoryType');
      }
    } catch (e, s) {
      _debugOutput('Error while creating $T');
      _debugOutput('Stack trace:\n $s');
      rethrow;
    }
  }

  /// returns an async instance depending on the type of the registration if [async==true] or
  /// if [dependsOn.isnoEmpty].
  Future<R> getObjectAsync<R>(dynamic param1, dynamic param2) async {
    assert(
      !(factoryType != _ServiceFactoryType.alwaysNew &&
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
                _readyCompleter.complete(newInstance);
                objectsWaiting.clear();
              }
              instance = newInstance;

              /// check if we are shadowing an existing Object
              final factoryThatWouldbeShadowed =
                  _getItInstance._findFirstFactoryByNameAndTypeOrNull(
                instanceName,
                type: T,
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
        default:
          throw StateError('Impossible factoryType');
      }
    } catch (e, s) {
      _debugOutput('Error while creating $T}');
      _debugOutput('Stack trace:\n $s');
      rethrow;
    }
  }
}

class _TypeRegistration<T extends Object> {
  final namedFactories =
      // ignore: prefer_collection_literals
      LinkedHashMap<String, _ServiceFactory<T, dynamic, dynamic>>();
  final factories = <_ServiceFactory<T, dynamic, dynamic>>[];

  void dispose() {
    for (final factory in factories.reversed) {
      factory.dispose();
    }
    factories.clear();
    for (final factory in namedFactories.values.toList().reversed) {
      factory.dispose();
    }
    namedFactories.clear();
  }

  _ServiceFactory<T, dynamic, dynamic>? getFactory(String? name) {
    return name != null ? namedFactories[name] : factories.firstOrNull;
  }
}

class _Scope {
  final String? name;
  final ScopeDisposeFunc? disposeFunc;
  bool isFinal = false;
  // ignore: prefer_collection_literals
  final typeRegistrations =
      // ignore: prefer_collection_literals
      LinkedHashMap<Type, _TypeRegistration>();

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
          (sum, x) =>
              sum..addAll([...x.factories, ...x.namedFactories.values]));

  Future<void> dispose() async {
    await disposeFunc?.call();
  }
}

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

  /// Is used by several other functions to retrieve the correct [_ServiceFactory]
  _ServiceFactory<T, dynamic, dynamic>?
      _findFirstFactoryByNameAndTypeOrNull<T extends Object>(
    String? instanceName, {
    Type? type,
    bool lookInScopeBelow = false,
  }) {
    /// We use an assert here instead of an `if..throw` because it gets called on every call
    /// of [get]
    /// `(const Object() is! T)` tests if [T] is a real type and not Object or dynamic
    assert(
      type != null || const Object() is! T,
      'GetIt: The compiler could not infer the type. You have to provide a type '
      'and optionally a name. Did you accidentally do `var sl=GetIt.instance();` '
      'instead of var sl=GetIt.instance;',
    );

    _ServiceFactory<T, dynamic, dynamic>? instanceFactory;

    int scopeLevel = _scopes.length - (lookInScopeBelow ? 2 : 1);

    final lookUpType = type ?? T;
    while (instanceFactory == null && scopeLevel >= 0) {
      final _TypeRegistration? typeRegistration =
          _scopes[scopeLevel].typeRegistrations[lookUpType];

      instanceFactory = typeRegistration?.getFactory(instanceName)
          as _ServiceFactory<T, dynamic, dynamic>?;
      scopeLevel--;
    }

    return instanceFactory;
  }

  /// Is used by several other functions to retrieve the correct [_ServiceFactory]
  _ServiceFactory _findFactoryByNameAndType<T extends Object>(
    String? instanceName, [
    Type? type,
  ]) {
    final instanceFactory =
        _findFirstFactoryByNameAndTypeOrNull<T>(instanceName, type: type);

    throwIfNot(
      instanceFactory != null,
      // ignore: missing_whitespace_between_adjacent_strings
      StateError(
          'GetIt: Object/factory with ${instanceName != null ? 'with name $instanceName and ' : ''}'
          'type $T is not registered inside GetIt. '
          '\n(Did you accidentally do GetIt sl=GetIt.instance(); instead of GetIt sl=GetIt.instance;'
          '\nDid you forget to register it?)'),
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
    assert(
        type == null || type is T,
        'The type you passed is not a $T. This can happen '
        'if the receiving variable is of the wrong type, or you passed a gerenic type and a type parameter');
    final instanceFactory = _findFactoryByNameAndType<T>(instanceName, type);

    final Object instance;
    if (instanceFactory.isAsync || instanceFactory.pendingResult != null) {
      /// We use an assert here instead of an `if..throw` for performance reasons
      assert(
        instanceFactory.factoryType == _ServiceFactoryType.constant ||
            instanceFactory.factoryType == _ServiceFactoryType.lazy,
        "You can't use get with an async Factory of ${instanceName ?? T.toString()}.",
      );
      throwIfNot(
        instanceFactory.isReady,
        StateError(
          'You tried to access an instance of ${instanceName ?? T.toString()} that is not ready yet',
        ),
      );
      instance = instanceFactory.instance!;
    } else {
      instance = instanceFactory.getObject(param1, param2);
    }

    assert(
      instance is T,
      'Object with name $instanceName has a different type '
      '(${instanceFactory.registrationType}) than the one that is inferred '
      '($T) where you call it',
    );

    return instance as T;
  }

  @override
  Iterable<T> getAll<T extends Object>({
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    assert(
        type == null || type is T,
        'The type you passed is not a $T. This can happen '
        'if the receiving variable is of the wrong type, or you passed a generic type and a type parameter');
    final _TypeRegistration<T>? typeRegistration =
        _currentScope.typeRegistrations[T] as _TypeRegistration<T>?;

    throwIf(
      typeRegistration == null,
      StateError('GetIt: No Objects/factories with '
          'type $T are not registered inside GetIt. '
          '\n(Did you accidentally do GetIt sl=GetIt.instance(); instead of GetIt sl=GetIt.instance;'
          '\nDid you forget to register it?)'),
    );

    final factories = [
      ...typeRegistration!.factories,
      ...typeRegistration.namedFactories.values
    ];
    final instances = <T>[];
    for (final instanceFactory in factories) {
      final Object instance;
      if (instanceFactory.isAsync || instanceFactory.pendingResult != null) {
        /// We use an assert here instead of an `if..throw` for performance reasons
        assert(
          instanceFactory.factoryType == _ServiceFactoryType.constant ||
              instanceFactory.factoryType == _ServiceFactoryType.lazy,
          "You can't use getAll with an async Factory of $T.",
        );
        throwIfNot(
          instanceFactory.isReady,
          StateError(
            'You tried to access an instance of $T that is not ready yet',
          ),
        );
        instance = instanceFactory.instance!;
      } else {
        instance = instanceFactory.getObject(param1, param2);
      }

      instances.add(instance as T);
    }
    return instances;
  }

  /// Callable class so that you can write `GetIt.instance<MyType>` instead of
  /// `GetIt.instance.get<MyType>`
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

  /// Returns a Future of an instance that is created by an async factory or a Singleton that is
  /// not ready with its initialization.
  /// for async factories you can pass up to 2 parameters [param1,param2] they have to match
  /// the types given at registration with [registerFactoryParamAsync()]
  @override
  Future<T> getAsync<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) {
    assert(
        type == null || type is T,
        'The type you passed is not a $T. This can happen '
        'if the receiving variable is of the wrong type, or you passed a gerenic type and a type parameter');
    final factoryToGet = _findFactoryByNameAndType<T>(instanceName, type);
    return factoryToGet.getObjectAsync<T>(param1, param2);
  }

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [factoryFunc] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
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

  /// registers a type so that a new instance will be created on each call of [get] on that
  /// type based on up to two parameters provided to [get()]
  /// [T] type to register
  /// [P1] type of param1
  /// [P2] type of param2
  /// if you use only one parameter pass void here
  /// [factoryFunc] factory function for this type that accepts two parameters
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  ///
  /// example:
  ///    getIt.registerFactoryParam<TestClassParam,String,int>((s,i)
  ///        => TestClassParam(param1:s, param2: i));
  ///
  /// if you only use one parameter:
  ///
  ///    getIt.registerFactoryParam<TestClassParam,String,void>((s,_)
  ///        => TestClassParam(param1:s);
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

  /// We use a separate function for the async registration instead of just a new parameter
  /// so make the intention explicit
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

  /// registers a type so that a new instance will be created on each call of [getAsync]
  /// on that type based on up to two parameters provided to [getAsync()]
  /// the creation function is executed asynchronously and has to be accessed with [getAsync]
  /// [T] type to register
  /// [P1] type of param1
  /// [P2] type of param2
  /// if you use only one parameter pass void here
  /// [factoryFunc] factory function for this type that accepts two parameters
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  ///
  /// example:
  ///    getIt.registerFactoryParam<TestClassParam,String,int>((s,i) async
  ///        => TestClassParam(param1:s, param2: i));
  ///
  /// if you only use one parameter:
  ///
  ///    getIt.registerFactoryParam<TestClassParam,String,void>((s,_) async
  ///        => TestClassParam(param1:s);
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

  /// registers a type as Singleton by passing a factory function that will be called
  /// on the first call of [get] on that type
  /// [T] type to register
  /// [factoryFunc] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// [registerLazySingleton] does not influence [allReady] however you can wait
  /// for and be dependent on a LazySingleton.
  @override
  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
  }) {
    _register<T, void, void>(
      type: _ServiceFactoryType.lazy,
      instanceName: instanceName,
      factoryFunc: factoryFunc,
      isAsync: false,
      shouldSignalReady: false,
      disposeFunc: dispose,
    );
  }

  /// registers a type as Singleton by passing an [instance] of that type
  ///  that will be returned on each call of [get] on that type
  /// [T] type to register
  /// If [signalsReady] is set to `true` it means that the future you can get from `allReady()`
  /// cannot complete until this registration was signalled ready by calling
  /// [signalsReady(instance)] [instanceName] if you provide a value here your instance gets
  /// registered with that name instead of a type. This should only be necessary if you need
  /// to register more than one instance of one type.
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
      shouldSignalReady: signalsReady ?? <T>[] is List<WillSignalReady>,
      disposeFunc: dispose,
    );
    return instance;
  }

  /// registers a type as Singleton by passing an factory function of that type
  /// that will be called on each call of [get] on that type
  /// [T] type to register
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// [dependsOn] if this instance depends on other registered Singletons before it can be initialized
  /// you can either orchestrate this manually using [isReady()] or pass a list of the types that the
  /// instance depends on here. [factoryFunc] won't get executed till these types are ready.
  /// [func] is called
  /// If [signalsReady] is set to `true` it means that the future you can get from `allReady()`
  /// cannot complete until this instance was signalled ready by calling [signalsReady(instance)].
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
      shouldSignalReady: signalsReady ?? <T>[] is List<WillSignalReady>,
      disposeFunc: dispose,
    );
  }

  /// registers a type as Singleton by passing an asynchronous factory function which has to
  /// return the instance that will be returned on each call of [get] on that type.
  /// Therefore you have to ensure that the instance is ready before you use [get] on it or use
  /// [getAsync()] to wait for the completion.
  /// You can wait/check if the instance is ready by using [isReady()] and [isReadySync()].
  /// [factoryFunc] is executed immediately if there are no dependencies to other Singletons
  /// (see below). As soon as it returns, this instance is marked as ready unless you don't set
  /// [signalsReady==true] [instanceName] if you provide a value here your instance gets
  /// registered with that name instead of a type. This should only be necessary if you need
  /// to register more than one instance of one type.
  /// [dependsOn] if this instance depends on other registered Singletons before it can be
  /// initialized you can either orchestrate this manually using [isReady()] or pass a list of
  /// the types that the instance depends on here. [factoryFunc] won't get executed till this
  /// types are ready. If [signalsReady] is set to `true` it means that the future you can get
  /// from `allReady()` cannot complete until this instance was signalled ready by calling
  /// [signalsReady(instance)]. In that case no automatic ready signal is made after
  /// completion of [factoryFunc]
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
      shouldSignalReady: signalsReady ?? <T>[] is List<WillSignalReady>,
      disposeFunc: dispose,
    );
  }

  /// registers a type as Singleton by passing an async factory function that will be called
  /// on the first call of [getAsync] on that type
  /// This is a rather esoteric requirement so you should seldom have the need to use it.
  /// This factory function [providerFunc] isn't called immediately but wait till the first call by
  /// [getAsync()] or [isReady()] is made
  /// To control if an async Singleton has completed its [providerFunc] gets a `Completer` passed
  /// as parameter that has to be completed to signal that this instance is ready.
  /// Therefore you have to ensure that the instance is ready before you use [get] on it or
  /// use [getAsync()] to wait for the completion.
  /// You can wait/check if the instance is ready by using [isReady()] and [isReadySync()].
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type.
  /// [registerLazySingletonAsync] does not influence [allReady] however you can wait
  /// for and be dependent on a LazySingleton.
  @override
  void registerLazySingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
  }) {
    _register<T, void, void>(
      isAsync: true,
      type: _ServiceFactoryType.lazy,
      instanceName: instanceName,
      factoryFuncAsync: factoryFunc,
      shouldSignalReady: false,
      disposeFunc: dispose,
    );
  }

  /// Clears all registered types. Handy when writing unit tests.
  @override
  Future<void> reset({bool dispose = true}) async {
    if (dispose) {
      for (int level = _scopes.length - 1; level >= 0; level--) {
        await _scopes[level].dispose();
        await _scopes[level].reset(dispose: dispose);
      }
    }
    _scopes.removeRange(1, _scopes.length);
    await resetScope(dispose: dispose);
  }

  /// Clears all registered types of the current scope in the reverse order in which they were registered.
  @override
  Future<void> resetScope({bool dispose = true}) async {
    if (dispose) {
      await _currentScope.dispose();
    }
    await _currentScope.reset(dispose: dispose);
  }

  /// Creates a new registration scope. If you register types after creating
  /// a new scope they will hide any previous registration of the same type.
  /// Scopes allow you to manage different live times of your Objects.
  /// [scopeName] if you name a scope you can pop all scopes above the named one
  /// by using the name.
  /// [dispose] function that will be called when you pop this scope. The scope
  /// is still valid while it is executed
  /// [init] optional function to register Objects immediately after the new scope is
  /// pushed. This ensures that [onScopeChanged] will be called after their registration
  /// if [isFinal] is set to true, you can't register any new objects in this scope after
  /// this call. In Other words you have to register the objects for this scope inside
  /// [init] if you set [isFinal] to true. This is useful if you want to ensure that
  /// no new objects are registered in this scope by accident which could lead to race conditions
  @override
  void pushNewScope({
    void Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
    bool isFinal = false,
  }) {
    assert(
      scopeName != _baseScopeName,
      'This name is reserved for the real base scope.',
    );
    assert(
      scopeName == null ||
          _scopes.firstWhereOrNull((x) => x.name == scopeName) == null,
      'You already have used the scope name $scopeName',
    );
    _scopes.add(_Scope(name: scopeName, disposeFunc: dispose));
    init?.call(this);
    if (isFinal) {
      _scopes.last.isFinal = true;
    }
    onScopeChanged?.call(true);
  }

  /// Creates a new registration scope. If you register types after creating
  /// a new scope they will hide any previous registration of the same type.
  /// Scopes allow you to manage different live times of your Objects.
  /// [scopeName] if you name a scope you can pop all scopes above the named one
  /// by using the name.
  /// [dispose] function that will be called when you pop this scope. The scope
  /// is still valid while it is executed
  /// [init] optional asynchronous function to register Objects immediately after the new scope is
  /// pushed. This ensures that [onScopeChanged] will be called after their registration
  @override
  Future<void> pushNewScopeAsync({
    Future<void> Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
  }) async {
    assert(
      scopeName != _baseScopeName,
      'This name is reserved for the real base scope.',
    );
    assert(
      scopeName == null ||
          _scopes.firstWhereOrNull((x) => x.name == scopeName) == null,
      'You already have used the scope name $scopeName',
    );
    _scopes.add(_Scope(name: scopeName, disposeFunc: dispose));
    await init?.call(this);
    onScopeChanged?.call(true);
  }

  /// Disposes all factories/Singletons that have been registered in this scope
  /// (in the reverse order in which they were registered)
  /// and pops (destroys) the scope so that the previous scope gets active again.
  /// if you provided dispose functions on registration, they will be called.
  /// if you passed a dispose function when you pushed this scope it will be
  /// called before the scope is popped.
  /// As dispose functions can be async, you should await this function.
  @override
  Future<void> popScope() async {
    throwIfNot(
      _scopes.length > 1,
      StateError(
        "GetIt: You are already on the base scope. you can't pop this one",
      ),
    );
    // make sure that nothing new can be registered in this scope
    // while the scopes async dispose functions are running
    _currentScope.isFinal = true;
    await _currentScope.dispose();
    await _currentScope.reset(dispose: true);
    _scopes.removeLast();
    onScopeChanged?.call(false);
  }

  /// if you have a lot of scopes with names you can pop (see [popScope]) all scopes above
  /// the scope with [scopeName] including that scope
  /// Scopes are popped in order from the top
  /// As dispose functions can be async, you should await this function.
  @override
  Future<bool> popScopesTill(String scopeName, {bool inclusive = true}) async {
    assert(
      scopeName != _baseScopeName || !inclusive,
      "You can't pop the base scope",
    );
    if (_scopes.firstWhereOrNull((x) => x.name == scopeName) == null) {
      return false;
    }
    String? poppedScopeName;
    do {
      poppedScopeName = _currentScope.name;
      await popScope();
    } while (inclusive
        ? (poppedScopeName != scopeName)
        : (_currentScope.name != scopeName));
    onScopeChanged?.call(false);
    return true;
  }

  /// Disposes all registered factories and singletons in the provided scope
  /// (in the reverse order in which they were registered),
  /// then drops (destroys) the scope. If the dropped scope was the last one,
  /// the previous scope becomes active again.
  /// if you provided dispose functions on registration, they will be called.
  /// if you passed a dispose function when you pushed this scope it will be
  /// called before the scope is dropped.
  /// As dispose functions can be async, you should await this function.
  @override
  Future<void> dropScope(String scopeName) async {
    if (currentScopeName == scopeName) {
      return popScope();
    }
    throwIfNot(
      _scopes.length > 1,
      StateError(
        "GetIt: You are already on the base scope. you can't drop this one",
      ),
    );
    final scope = _scopes.lastWhere(
      (s) => s.name == scopeName,
      orElse: () => throw ArgumentError("Scope $scopeName not found"),
    );
    // make sure that nothing new can be registered in this scope
    // while the scopes async dispose functions are running
    scope.isFinal = true;
    await scope.dispose();
    await scope.reset(dispose: true);
    _scopes.remove(scope);
  }

  /// Tests if the scope by name [scopeName] is registered in GetIt
  @override
  bool hasScope(String scopeName) {
    return _scopes.any((x) => x.name == scopeName);
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
  }) {
    throwIfNot(
      const Object() is! T,
      'GetIt: You have to provide type. Did you accidentally do `var sl=GetIt.instance();` '
      'instead of var sl=GetIt.instance;',
    );

    _Scope registrationScope;
    int i = _scopes.length;
    do {
      i--;
      registrationScope = _scopes[i];
    } while (registrationScope.isFinal && i >= 0);
    assert(
      i >= 0,
      'The baseScope should always be open. If you see this error please file an issue at',
    );

    final existingTypeRegistration = registrationScope.typeRegistrations[T];
    // if we already a registration for this type we have to check if its a valid re-registration
    if (existingTypeRegistration != null) {
      if (instanceName != null) {
        throwIf(
          existingTypeRegistration.namedFactories.containsKey(instanceName) &&
              !allowReassignment,
          ArgumentError(
            'Object/factory with name $instanceName and '
            'type $T is already registered inside GetIt. ',
          ),
        );
      } else {
        if (existingTypeRegistration.factories.isNotEmpty) {
          throwIfNot(
            allowReassignment ||
                GetIt.allowRegisterMultipleImplementationsOfoneType,
            ArgumentError('Type $T is already registered inside GetIt. '),
          );
        }
      }
    }

    if (instance != null) {
      /// check if we are shadowing an existing Object
      final factoryThatWouldbeShadowed =
          _findFirstFactoryByNameAndTypeOrNull(instanceName, type: T);

      final objectThatWouldbeShadowed = factoryThatWouldbeShadowed?.instance;
      if (objectThatWouldbeShadowed != null &&
          objectThatWouldbeShadowed is ShadowChangeHandlers) {
        objectThatWouldbeShadowed.onGetShadowed(instance);
      }
    }

    final typeRegistration = registrationScope.typeRegistrations
        .putIfAbsent(T, () => _TypeRegistration<T>());

    final serviceFactory = _ServiceFactory<T, P1, P2>(
      this,
      type,
      registeredIn: typeRegistration,
      registrationScope: registrationScope,
      creationFunction: factoryFunc,
      creationFunctionParam: factoryFuncParam,
      asyncCreationFunctionParam: factoryFuncParamAsync,
      asyncCreationFunction: factoryFuncAsync,
      instance: instance,
      isAsync: isAsync,
      instanceName: instanceName,
      shouldSignalReady: shouldSignalReady,
      disposeFunction: disposeFunc,
    );

    if (instanceName != null) {
      typeRegistration.namedFactories[instanceName] = serviceFactory;
    } else {
      if (GetIt.allowRegisterMultipleImplementationsOfoneType) {
        typeRegistration.factories.add(serviceFactory);
      } else {
        if (typeRegistration.factories.isNotEmpty) {
          typeRegistration.factories[0] = serviceFactory;
        } else {
          typeRegistration.factories.add(serviceFactory);
        }
      }
    }

    // simple Singletons get are already created, nothing else has to be done
    if (type == _ServiceFactoryType.constant &&
        !shouldSignalReady &&
        !isAsync &&
        (dependsOn?.isEmpty ?? true)) {
      return;
    }

    // if it's an async or a dependent Singleton we start its creation function here after we check if
    // it is dependent on other registered Singletons.
    if ((isAsync || (dependsOn?.isNotEmpty ?? false)) &&
        type == _ServiceFactoryType.constant) {
      /// Any client awaiting the completion of this Singleton
      /// Has to wait for the completion of the Singleton itself as well
      /// as for the completion of all the Singletons this one depends on
      /// For this we use [outerFutureGroup]
      /// A `FutureGroup` completes only if it's closed and all contained
      /// Futures have completed
      final outerFutureGroup = FutureGroup();
      Future dependentFuture;

      if (dependsOn?.isNotEmpty ?? false) {
        /// To wait for the completion of all Singletons this one is depending on
        /// before we start to create itself we use [dependentFutureGroup]
        final dependentFutureGroup = FutureGroup();

        for (final dependency in dependsOn!) {
          late final _ServiceFactory<Object, dynamic, dynamic>?
              dependentFactory;
          if (dependency is InitDependency) {
            dependentFactory = _findFirstFactoryByNameAndTypeOrNull(
              dependency.instanceName,
              type: dependency.type,
            );
          } else {
            dependentFactory =
                _findFirstFactoryByNameAndTypeOrNull(null, type: dependency);
          }
          throwIf(
            dependentFactory == null,
            ArgumentError(
              'Dependent Type $dependency is not registered in GetIt',
            ),
          );
          throwIfNot(
            dependentFactory!.canBeWaitedFor,
            ArgumentError(
              'Dependent Type $dependency is not an async Singleton',
            ),
          );
          dependentFactory.objectsWaiting.add(serviceFactory.registrationType);
          dependentFutureGroup.add(dependentFactory._readyCompleter.future);
        }
        dependentFutureGroup.close();

        dependentFuture = dependentFutureGroup.future;
      } else {
        /// if we have no dependencies we still create a dummy Future so that
        /// we can use the same code path further down
        dependentFuture = Future.sync(() {}); // directly execute then
      }
      outerFutureGroup.add(dependentFuture);

      /// if someone uses getAsync on an async Singleton that has not be started to get created
      /// because its dependent on other objects this doesn't work because [pendingResult] is
      /// not set in that case. Therefore we have to set [outerFutureGroup] as [pendingResult]
      dependentFuture.then((_) {
        Future<T> isReadyFuture;
        if (!isAsync) {
          /// SingletonWithDependencies
          serviceFactory.instance = factoryFunc!();

          /// check if we are shadowing an existing Object
          final factoryThatWouldbeShadowed =
              _findFirstFactoryByNameAndTypeOrNull(
            instanceName,
            type: T,
            lookInScopeBelow: true,
          );

          final objectThatWouldbeShadowed =
              factoryThatWouldbeShadowed?.instance;
          if (objectThatWouldbeShadowed != null &&
              objectThatWouldbeShadowed is ShadowChangeHandlers) {
            objectThatWouldbeShadowed.onGetShadowed(serviceFactory.instance!);
          }

          if (!serviceFactory.shouldSignalReady) {
            /// As this isn't an async function we declare it as ready here
            /// if wasn't marked that it will signalReady
            isReadyFuture = Future<T>.value(serviceFactory.instance! as T);
            serviceFactory._readyCompleter
                .complete(serviceFactory.instance! as T);
            serviceFactory.objectsWaiting.clear();
          } else {
            isReadyFuture = serviceFactory._readyCompleter.future;
          }
        } else {
          /// Async Singleton with dependencies
          final asyncResult = factoryFuncAsync!();

          isReadyFuture = asyncResult.then((instance) {
            serviceFactory.instance = instance;

            /// check if we are shadowing an existing Object
            final factoryThatWouldbeShadowed =
                _findFirstFactoryByNameAndTypeOrNull(
              instanceName,
              type: T,
              lookInScopeBelow: true,
            );

            final objectThatWouldbeShadowed =
                factoryThatWouldbeShadowed?.instance;
            if (objectThatWouldbeShadowed != null &&
                objectThatWouldbeShadowed is ShadowChangeHandlers) {
              objectThatWouldbeShadowed.onGetShadowed(instance);
            }

            if (!serviceFactory.shouldSignalReady && !serviceFactory.isReady) {
              serviceFactory._readyCompleter.complete(instance);
              serviceFactory.objectsWaiting.clear();
            }

            return instance;
          });
        }
        outerFutureGroup.add(isReadyFuture);
        outerFutureGroup.close();
      });

      /// outerFutureGroup.future returns a Future<List> and not a Future<T>
      /// As we know that the actual factory function was added last to the FutureGroup
      /// we just use that one
      serviceFactory.pendingResult =
          outerFutureGroup.future.then((completedFutures) {
        return completedFutures.last as T;
      });
    }
  }

  /// Tests if an [instance] of an object or aType [T] or a name [instanceName]
  /// is registered inside GetIt
  @override
  bool isRegistered<T extends Object>({
    Object? instance,
    String? instanceName,
  }) {
    if (instance != null) {
      return _findFirstFactoryByInstanceOrNull(instance) != null;
    } else {
      return _findFirstFactoryByNameAndTypeOrNull<T>(instanceName) != null;
    }
  }

  /// Unregister an instance of an object or a factory/singleton by Type [T] or by name [instanceName]
  /// if you need to dispose any resources you can do it using [disposingFunction] function
  /// that provides an instance of your class to be disposed
  @override
  FutureOr unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  }) async {
    final factoryToRemove = instance != null
        ? _findFactoryByInstance(instance)
        : _findFactoryByNameAndType<T>(instanceName);

    throwIf(
      factoryToRemove.objectsWaiting.isNotEmpty,
      StateError(
        'There are still other objects waiting for this instance so signal ready',
      ),
    );

    if (instanceName != null) {
      factoryToRemove.registeredIn.namedFactories.remove(instanceName);
    } else {
      final factories = factoryToRemove.registeredIn.factories;
      if (factories.contains(factoryToRemove)) {
        factories.remove(factoryToRemove);
        if (factories.isEmpty) {
          factoryToRemove.registrationScope.typeRegistrations.remove(T);
        }
      }
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

  /// Clears the instance of a lazy singleton,
  /// being able to call the factory function on the next call
  /// of [get] on that type again.
  /// you select the lazy Singleton you want to reset by either providing
  /// an [instance], its registered type [T] or its registration name.
  /// if you need to dispose some resources before the reset, you can
  /// provide a [disposingFunction]
  @override
  FutureOr resetLazySingleton<T extends Object>({
    T? instance,
    String? instanceName,
    FutureOr Function(T)? disposingFunction,
  }) async {
    _ServiceFactory instanceFactory;

    if (instance != null) {
      instanceFactory = _findFactoryByInstance(instance);
    } else {
      instanceFactory = _findFactoryByNameAndType<T>(instanceName);
    }
    throwIfNot(
      instanceFactory.factoryType == _ServiceFactoryType.lazy,
      StateError(
        'There is no type ${instance.runtimeType} registered as LazySingleton in GetIt',
      ),
    );

    dynamic disposeReturn;
    if (instanceFactory.instance != null) {
      if (disposingFunction != null) {
        disposeReturn = disposingFunction.call(instanceFactory.instance! as T);
      } else {
        disposeReturn = instanceFactory.dispose();
      }
    }

    instanceFactory.instance = null;
    instanceFactory.pendingResult = null;
    instanceFactory._readyCompleter = Completer<T>();
    if (disposeReturn is Future) {
      await disposeReturn;
    }
  }

  List<_ServiceFactory> get _allFactories =>
      _scopes.fold<List<_ServiceFactory>>(
        [],
        (sum, x) => sum..addAll(x.allFactories),
      );

  _ServiceFactory? _findFirstFactoryByInstanceOrNull(Object instance) {
    final registeredFactories =
        _allFactories.where((x) => identical(x.instance, instance));
    return registeredFactories.isEmpty ? null : registeredFactories.first;
  }

  _ServiceFactory _findFactoryByInstance(Object instance) {
    final registeredFactory = _findFirstFactoryByInstanceOrNull(instance);

    throwIf(
      registeredFactory == null,
      StateError(
          'This instance of the type ${instance.runtimeType} is not available in GetIt '
          'If you have registered it as LazySingleton, are you sure you have used '
          'it at least once?'),
    );

    return registeredFactory!;
  }

  /// Used to manually signal the ready state of a Singleton.
  /// If you want to use this mechanism you have to pass [signalsReady==true] when registering
  /// the Singleton.
  /// If [instance] has a value GetIt will search for the responsible Singleton
  /// and completes all futures that might be waited for by [isReady]
  /// If all waiting singletons have signalled ready the future you can get
  /// from [allReady] is automatically completed
  ///
  /// Typically this is used in this way inside the registered objects init
  /// method `GetIt.instance.signalReady(this);`
  ///
  /// if [instance] is `null` and no factory/singleton is waiting to be signalled this
  /// will complete the future you got from [allReady], so it can be used to globally
  /// giving a ready Signal
  ///
  /// Both ways are mutually exclusive, meaning either only use the global `signalReady()` and
  /// don't register a singleton to signal ready or use any async registrations
  ///
  /// Or use async registrations methods or let individual instances signal their ready
  /// state on their own.
  @override
  void signalReady(Object? instance) {
    _ServiceFactory registeredInstance;
    if (instance != null) {
      registeredInstance = _findFactoryByInstance(instance);

      throwIfNot(
        registeredInstance.shouldSignalReady,
        ArgumentError.value(
            instance,
            'This instance of type ${instance.runtimeType} is not supposed to be '
            'signalled.\nDid you forget to set signalsReady==true when registering it?'),
      );

      throwIf(
        registeredInstance.isReady,
        StateError(
          'This instance of type ${instance.runtimeType} was already signalled',
        ),
      );

      registeredInstance._readyCompleter.complete(instance);
      registeredInstance.objectsWaiting.clear();
    } else {
      /// Manual signalReady without an instance

      /// In case that there are still factories that are marked to wait for a signal
      /// but aren't signalled we throw an error with details which objects are concerned
      final notReady = _allFactories
          .where(
            (x) =>
                (x.shouldSignalReady) && (!x.isReady) ||
                (x.pendingResult != null) && (!x.isReady),
          )
          .map<String>((x) => '${x.registrationType}/${x.instanceName}')
          .toList();
      throwIf(
        notReady.isNotEmpty,
        StateError(
            "You can't signal ready manually if you have registered instances that should "
            "signal ready or are async.\n"
            // this lint is stupid because it doesn't recognize newlines
            // ignore: missing_whitespace_between_adjacent_strings
            'Did you forget to pass an object instance?'
            'This registered types/names: $notReady should signal ready but are not ready'),
      );

      _globalReadyCompleter.complete();
    }
  }

  /// returns a Future that completes if all asynchronously created Singletons and any
  /// Singleton that had [signalsReady==true] are ready.
  /// This can be used inside a FutureBuilder to change the UI as soon as all initialization
  /// is done. If you pass a [timeout], a [WaitingTimeOutException] will be thrown if not all
  /// Singletons were ready in the given time. The Exception contains details on which
  /// Singletons are not ready yet.
  @override
  Future<void> allReady({
    Duration? timeout,
    bool ignorePendingAsyncCreation = false,
  }) {
    final futures = FutureGroup();
    _allFactories
        .where(
      (x) =>
          (x.isAsync && !ignorePendingAsyncCreation ||
              (!x.isAsync &&
                  x.pendingResult != null) || // Singletons with dependencies
              x.shouldSignalReady) &&
          !x.isReady &&
          x.factoryType == _ServiceFactoryType.constant,
    )
        .forEach((f) {
      if (f.pendingResult != null) {
        futures.add(f.pendingResult!);
        if (f.shouldSignalReady) {
          futures.add(
            f._readyCompleter.future,
          ); // asyncSingleton with signalReady = true
        }
      } else {
        futures.add(
          f._readyCompleter.future,
        ); // non async singletons that have signalReady == true and not dependencies
      }
    });
    futures.close();
    if (timeout != null) {
      return futures.future
          .timeout(timeout, onTimeout: () async => throw _createTimeoutError());
    } else {
      return futures.future;
    }
  }

  /// Returns if all async Singletons are ready without waiting
  /// if [allReady] should not wait for the completion of async Singletons set
  /// [ignorePendingAsyncCreation==true]
  @override
  bool allReadySync([bool ignorePendingAsyncCreation = false]) {
    final notReadyTypes = _allFactories
        .where(
      (x) =>
          (x.isAsync && !ignorePendingAsyncCreation ||
                  (!x.isAsync &&
                      x.pendingResult !=
                          null) || // Singletons with dependencies
                  x.shouldSignalReady) &&
              !x.isReady &&
              x.factoryType == _ServiceFactoryType.constant ||
          x.factoryType == _ServiceFactoryType.lazy,
    )
        .map<String>((x) {
      if (x.isNamedRegistration) {
        return 'Object ${x.instanceName} has not completed';
      } else {
        return 'Registered object of Type ${x.registrationType} has not completed';
      }
    }).toList();

    /// In debug mode we print the List of not ready types/named instances
    if (notReadyTypes.isNotEmpty) {
      _debugOutput('Not yet ready objects:');
      _debugOutput(notReadyTypes);
    }
    return notReadyTypes.isEmpty;
  }

  WaitingTimeOutException _createTimeoutError() {
    final allFactories = _allFactories;
    final waitedBy = Map.fromEntries(
      allFactories
          .where(
            (x) =>
                (x.shouldSignalReady || x.pendingResult != null) &&
                !x.isReady &&
                x.objectsWaiting.isNotEmpty,
          )
          .map<MapEntry<String, List<String>>>(
            (isWaitedFor) => MapEntry(
              isWaitedFor.debugName,
              isWaitedFor.objectsWaiting
                  .map((waitedByType) => waitedByType.toString())
                  .toList(),
            ),
          ),
    );
    final notReady = allFactories
        .where(
          (x) => (x.shouldSignalReady || x.pendingResult != null) && !x.isReady,
        )
        .map((f) => f.debugName)
        .toList();
    final areReady = allFactories
        .where(
          (x) => (x.shouldSignalReady || x.pendingResult != null) && x.isReady,
        )
        .map((f) => f.debugName)
        .toList();

    return WaitingTimeOutException(waitedBy, notReady, areReady);
  }

  /// Returns a Future that completes if the instance of a Singleton, defined by Type [T] or
  /// by name [instanceName] or by passing an existing [instance], is ready
  /// If you pass a [timeout], a [WaitingTimeOutException] will be thrown if the instance
  /// is not ready in the given time. The Exception contains details on which Singletons are
  /// not ready at that time.
  /// [callee] optional parameter which makes debugging easier. Pass `this` in here.
  @override
  Future<void> isReady<T extends Object>({
    Object? instance,
    String? instanceName,
    Duration? timeout,
    Object? callee,
  }) {
    _ServiceFactory factoryToCheck;
    if (instance != null) {
      factoryToCheck = _findFactoryByInstance(instance);
    } else {
      factoryToCheck = _findFactoryByNameAndType<T>(instanceName);
    }
    throwIfNot(
      factoryToCheck.canBeWaitedFor &&
          factoryToCheck.factoryType != _ServiceFactoryType.alwaysNew,
      ArgumentError(
          'You only can use this function on Singletons that are async, that are marked as '
          'dependent or that are marked with "signalsReady==true"'),
    );
    if (!factoryToCheck.isReady) {
      factoryToCheck.objectsWaiting.add(callee.runtimeType);
    }
    if (factoryToCheck.isAsync &&
        factoryToCheck.factoryType == _ServiceFactoryType.lazy &&
        factoryToCheck.instance == null) {
      if (timeout != null) {
        return factoryToCheck.getObjectAsync(null, null).timeout(
          timeout,
          onTimeout: () {
            throw _createTimeoutError();
          },
        );
      } else {
        return factoryToCheck.getObjectAsync(null, null);
      }
    }
    if (factoryToCheck.pendingResult != null) {
      if (timeout != null) {
        return factoryToCheck.pendingResult!.timeout(
          timeout,
          onTimeout: () {
            throw _createTimeoutError();
          },
        );
      } else {
        return factoryToCheck.pendingResult!;
      }
    }
    if (timeout != null) {
      return factoryToCheck._readyCompleter.future
          .timeout(timeout, onTimeout: () => throw _createTimeoutError());
    } else {
      return factoryToCheck._readyCompleter.future;
    }
  }

  /// Checks if an async Singleton defined by an [instance], a type [T] or an [instanceName]
  /// is ready without waiting.
  @override
  bool isReadySync<T extends Object>({Object? instance, String? instanceName}) {
    _ServiceFactory factoryToCheck;
    if (instance != null) {
      factoryToCheck = _findFactoryByInstance(instance);
    } else {
      factoryToCheck = _findFactoryByNameAndType<T>(instanceName);
    }
    throwIfNot(
      factoryToCheck.canBeWaitedFor &&
          factoryToCheck.factoryType != _ServiceFactoryType.alwaysNew,
      ArgumentError(
          'You only can use this function on async Singletons or Singletons '
          'that have ben marked with "signalsReady" or that they depend on others'),
    );
    return factoryToCheck.isReady;
  }
}
