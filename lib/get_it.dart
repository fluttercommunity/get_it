library get_it;

import 'dart:async';

import 'package:meta/meta.dart';

typedef FactoryFunc<T> = T Function();

enum _readyStates { noneWaitingToBeReady, allReady, notAllReady }

/// Very simple and easy to use service locator
/// You register your object creation or an instance of an object with [registerFactory],
/// [registerSingleton] or [registerLazySingleton]
/// And retrieve the desired object using [get] or call your locator das as function as its a
/// callable class
class GetIt {
  final _factories = Map<Type, _ServiceFactory<dynamic>>();
  final _factoriesByName = Map<String, _ServiceFactory<dynamic>>();

  final _readySignalStream = StreamController<void>.broadcast();

  Stream<void> get ready => _readySignalStream.stream;

  Future<void> get readyFuture => ready.first;

  GetIt._();

  static GetIt _instance;

  static GetIt get instance {
    if (_instance == null) {
      _instance = GetIt._();
    }
    return _instance;
  }

  static GetIt get I => instance;

  /// You should prefer to use the `instance()` method to access an instance of [GetIt].
  /// If you really, REALLY need more than one [GetIt] instance please set allowMultipleInstances
  /// to true to signal you know what you are doing :-).
  factory GetIt.asNewInstance() {
    assert(allowMultipleInstances,
        'You should prefer to use the `instance()` method to access an instance of GetIt. If you really need more than one GetIt instance please set allowMultipleInstances to true.');
    return GetIt._();
  }

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  bool allowReassignment = false;

  /// By default it's not allowed to create more than one [GetIt] instance.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  static bool allowMultipleInstances = false;

  /// retrieves or creates an instance of a registered type [T] depending on the registration function used for this type or based on a name.
  T get<T>([String instanceName]) {
    assert(!(!(const Object() is! T) && instanceName == null),
        'GetIt: You have to provide either a type or a name. Did you accidentally do  `var sl=GetIt.instance();` instead of var sl=GetIt.instance;');
    assert(!(((const Object() is! T) && instanceName != null)),
        'GetIt: You have to provide either a type OR a name not both.');

    _ServiceFactory<T> object;
    if (instanceName == null) {
      object = _factories[T];
    } else {
      object = _factoriesByName[instanceName];
    }
    if (object == null) {
      if (instanceName == null) {
        throw Exception(
            "Object of type ${T.toString()} is not registered inside GetIt");
      } else {
        throw Exception(
            "Object with name $instanceName is not registered inside GetIt");
      }
    }
    return object.getObject();
  }

  T call<T>([String instanceName]) {
    return get<T>(instanceName);
  }

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// If [signalsReady] is set to `true` it means that the `ready` property cannot emit a ready event until this
  /// registration was signalled ready
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerFactory<T>(FactoryFunc<T> func,
      {String instanceName, bool signalsReady = false}) {
    _register<T>(
        type: _ServiceFactoryType.alwaysNew,
        instanceName: instanceName,
        factoryFunc: func,
        signalsReady: signalsReady);
  }

  /// registers a type as Singleton by passing a factory function that will be called on the first call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// If [signalsReady] is set to `true` it means that the `ready` property cannot emit a ready event until this
  /// registration was signalled ready
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerLazySingleton<T>(FactoryFunc<T> func,
      {String instanceName, bool signalsReady = false}) {
    _register<T>(
        type: _ServiceFactoryType.lazy,
        instanceName: instanceName,
        factoryFunc: func,
        signalsReady: signalsReady);
  }

  /// registers a type as Singleton by passing an [instance] of that type
  ///  that will be returned on each call of [get] on that type
  /// [T] type to register
  /// If [signalsReady] is set to `true` it means that the `ready` property cannot emit a ready event until this
  /// registration was signalled ready
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerSingleton<T>(T instance,
      {String instanceName, bool signalsReady = false}) {
    _register<T>(
        type: _ServiceFactoryType.constant,
        instanceName: instanceName,
        instance: instance,
        signalsReady: signalsReady);
  }

  /// Clears all registered types. Handy when writing unit tests
  void reset() {
    _factories.clear();
    _factoriesByName.clear();
  }

  void _register<T>(
      {@required _ServiceFactoryType type,
      FactoryFunc factoryFunc,
      T instance,
      @required String instanceName,
      @required bool signalsReady}) {
    assert(
        instanceName != null || allowReassignment || !_factories.containsKey(T),
        "Type ${T.toString()} is already registered");
    assert(
      instanceName != null ||
          (allowReassignment || !_factoriesByName.containsKey(instanceName)),
      "An object of name $instanceName is already registered",
    );

    var serviceFactory = _ServiceFactory<T>(type,
        creationFunction: factoryFunc,
        instance: instance,
        shouldSignalReady: signalsReady);
    if (instanceName == null) {
      _factories[T] = serviceFactory;
    } else {
      _factoriesByName[instanceName] = serviceFactory;
    }
  }

  /// Unregister by Type [T] or by name [instanceName]
  /// if you need to dispose any resources you can do it using [disposingFunction] function
  /// that provides a instance of your class to be disposed
  void unregister<T>(
      {String instanceName, void Function(T) disposingFunction}) {
    assert(!(((const Object() is! T) && instanceName != null)),
        'GetIt: You have to provide either a type OR a name not both.');
    assert(
        (instanceName != null && _factoriesByName.containsKey(instanceName)) ||
            _factories.containsKey(T),
        'No Type registered ${T.toString()} or instance Name must not be null');
    if (instanceName == null) {
      disposingFunction(get<T>());
      _factories.remove(T);
    } else {
      disposingFunction(get(instanceName));
      _factoriesByName.remove(instanceName);
    }
  }

  void signalReady<T>([String instanceName]) {
    assert(!(((const Object() is! T) && instanceName != null)),
        'GetIt.signalReady: You have to provide either a type OR a name not both.');
    if ((const Object() is! T) ||
        (instanceName != null && instanceName.isNotEmpty)) {
      /// if (T is not a top level type especially not `dynamic`) or instanceName has a value
      /// which means a specific registered object should be signalled
      _ServiceFactory<T> object;
      if (instanceName != null) {
        object = _factoriesByName[instanceName];
      } else if (const Object() is! T) {
        object = _factories[T];
      }
      if (object == null) {
        if (instanceName == null) {
          throw Exception(
              "GetIt.signalReady: Object of type ${T.toString()} is not registered inside GetIt");
        } else {
          throw Exception(
              "GetIt.signalReady: Object with name $instanceName is not registered inside GetIt");
        }
      }
      if (!object.shouldSignalReady) {
        if (instanceName == null) {
          throw Exception(
              "GetIt.signalReady: Object of type ${T.toString()} does not wait to be signalled");
        } else {
          throw Exception(
              "GetIt.signalReady: Object with name $instanceName does not wait to be signalled");
        }
      }
      object.isReady = true;

      if (_getReadyState() == _readyStates.allReady) {
        _readySignalStream.add(true);
      }
    } else {
      /// signalReady was called without a type or a name means a manual signalReady
      var allReady = _getReadyState();
      if (allReady == _readyStates.allReady ||
          allReady == _readyStates.noneWaitingToBeReady) {
        _readySignalStream.add(true);
        return;
      }

      /// In case that there are still factories that are marked to wait for a signal
      /// but aren't signalled we throw an exception with details which objects are concerned
      final notReadyTypes = _factories.entries
          .where((x) => (x.value.shouldSignalReady && !x.value.isReady))
          .map<String>((x) => x.key.toString())
          .toList();
      final notReadyNames = _factoriesByName.entries
          .where((x) => (x.value.shouldSignalReady && !x.value.isReady))
          .map<String>((x) => x.key)
          .toList();

      throw (Exception(
          'Registered types/names: $notReadyTypes  / $notReadyNames should signal ready but are not ready'));
    }
  }

  _readyStates _getReadyState() {
    var shouldbeSignalled = _factories.values
        .where((x) => x.shouldSignalReady)
        .toList()
          ..addAll(_factoriesByName.values.where((x) => x.shouldSignalReady));
    if (shouldbeSignalled.isEmpty) {
      return _readyStates.noneWaitingToBeReady;
    }
    if (shouldbeSignalled.every((x) => x.isReady)) {
      return _readyStates.allReady;
    }
    return _readyStates.notAllReady;
  }
}

enum _ServiceFactoryType { alwaysNew, constant, lazy }

class _ServiceFactory<T> {
  final _ServiceFactoryType factoryType;
  final FactoryFunc creationFunction;
  Object instance;
  final bool shouldSignalReady;
  bool isReady;

  _ServiceFactory(this.factoryType,
      {this.creationFunction,
      this.instance,
      this.isReady = false,
      this.shouldSignalReady = false});

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
      }
    } catch (e, s) {
      print("Error while creating ${T.toString()}");
      print('Stack trace:\n $s');
      rethrow;
    }
  }
}
