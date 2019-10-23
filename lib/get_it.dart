library get_it;

import 'dart:async';

import 'package:meta/meta.dart';

typedef FactoryFunc<T> = T Function();

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
class GetIt {
  final _factories = Map<Type, _ServiceFactory<dynamic>>();
  final _factoriesByName = Map<String, _ServiceFactory<dynamic>>();

  final _readySignalStream = StreamController<void>.broadcast();

  Stream<void> get ready => _readySignalStream.stream;

  Future<void> get readyFuture => ready.first;

  GetIt._();

  static GetIt _instance;

  static GetIt get instance {
    _instance ??= GetIt._();
    return _instance;
  }

  static GetIt get I => instance;

  /// You should prefer to use the `instance()` method to access an instance of [GetIt].
  /// If you really, REALLY need more than one [GetIt] instance please set allowMultipleInstances
  /// to true to signal you know what you are doing :-).
  factory GetIt.asNewInstance() {
    throwIfNot(
      allowMultipleInstances,
      StateError(
          'You should prefer to use the `instance()` method to access an instance of GetIt. '
          'If you really need more than one GetIt instance please set allowMultipleInstances to true.'),
    );
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
    throwIfNot(
      !(!(const Object() is! T) && instanceName == null),
      ArgumentError(
          'GetIt: You have to provide either a type or a name. Did you accidentally do  `var sl=GetIt.instance();` instead of var sl=GetIt.instance;'),
    );

    _ServiceFactory<T> object;
    if (instanceName == null) {
      object = _factories[T];
    } else {
      final registeredObject = _factoriesByName[instanceName];
      if (registeredObject != null) {
        if (registeredObject.registrationType is! T) {
          print(T.toString());
          throw ArgumentError(
              "Object with name $instanceName has a different type (${registeredObject.registrationType.toString()}) than the one that is inferred (${T.toString()}) where you call it");
        }
      }
      object = registeredObject;
    }
    if (object == null && instanceName == null) {
      throw ArgumentError.value(
          T, "Object of type ${T.toString()} is not registered inside GetIt");
    }
    if (object == null && instanceName != null) {
      throw ArgumentError.value(instanceName,
          "Object with name $instanceName is not registered inside GetIt");
    }
    return object.getObject();
  }

  T call<T>([String instanceName]) {
    return get<T>(instanceName);
  }

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerFactory<T>(FactoryFunc<T> func, {String instanceName}) {
    _register<T>(
        type: _ServiceFactoryType.alwaysNew,
        instanceName: instanceName,
        factoryFunc: func,
        signalsReady: false);
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
    throwIfNot(
      instanceName != null || allowReassignment || !_factories.containsKey(T),
      ArgumentError.value(T, "Type ${T.toString()} is already registered"),
    );
    throwIfNot(
      instanceName != null ||
          (allowReassignment || !_factoriesByName.containsKey(instanceName)),
      ArgumentError.value(
        instanceName,
        "An object of name $instanceName is already registered",
      ),
    );

    var serviceFactory = _ServiceFactory<T>(type,
        creationFunction: factoryFunc,
        instance: instance,
        shouldSignalReady: signalsReady,
        instanceName: instanceName);
    if (instanceName == null) {
      _factories[T] = serviceFactory;
    } else {
      _factoriesByName[instanceName] = serviceFactory;
    }
  }

  /// Unregister an instance of an object or a factory/singleton by Type [T] or by name [instanceName]
  /// if you need to dispose any resources you can do it using [disposingFunction] function
  /// that provides a instance of your class to be disposed
  void unregister<T>(
      {Object instance,
      String instanceName,
      void Function(T) disposingFunction}) {
    if (instance != null) {
      var registeredInstance = _factories.values
          .followedBy(_factoriesByName.values)
          .where((x) => identical(x.instance, instance));

      throwIf(
        registeredInstance.isEmpty,
        ArgumentError.value(instance,
            'There is no object type ${instance.runtimeType} registered in GetIt'),
      );

      var _factory = registeredInstance.first;
      if (_factory.isNamedRegistration) {
        _factoriesByName.remove(_factory.instanceName);
      } else {
        _factories.remove(_factory.registrationType);
      }
      disposingFunction?.call(_factory.instance);
    } else {
      throwIf(
        (((const Object() is! T) && instanceName != null)),
        ArgumentError(
            'GetIt: You have to provide either a type OR a name not both.'),
      );
      throwIfNot(
        (instanceName != null && _factoriesByName.containsKey(instanceName)) ||
            _factories.containsKey(T),
        ArgumentError(
            'No Type registered ${T.toString()} or instance Name must not be null'),
      );
      if (instanceName == null) {
        disposingFunction?.call(get<T>());
        _factories.remove(T);
      } else {
        disposingFunction?.call(get(instanceName));
        _factoriesByName.remove(instanceName);
      }
    }
  }

  void signalReady([Object instance]) {
    if (instance != null) {
      var registeredInstance = _factories.values
          .followedBy(_factoriesByName.values)
          .where((x) => identical(x.instance, instance));
      throwIf(
          registeredInstance.length > 1,
          StateError(
              'This objects instance of type ${instance.runtimeType} are registered multiple times in GetIt'));

      throwIf(
          registeredInstance.isEmpty,
          ArgumentError.value(instance,
              'There is no object type ${instance.runtimeType} registered in GetIt'));

      throwIf(
          !registeredInstance.first.shouldSignalReady,
          ArgumentError.value(instance,
              'This instance of type ${instance.runtimeType} is not supposed to be signalled'));

      throwIf(
          registeredInstance.first.isReady,
          StateError(
              'This instance of type ${instance.runtimeType} was already signalled'));

      registeredInstance.first.isReady = true;

      /// if all registered instances that should signal ready are ready signal the [ready] and [readyFuture]
      var shouldSignalButNotReady = _factories.values
          .followedBy(_factoriesByName.values)
          .where((x) => x.shouldSignalReady && !x.isReady);
      if (shouldSignalButNotReady.isEmpty) {
        _readySignalStream.add(true);
      }
    } else {
      /// Manual signalReady without an instance

      /// In case that there are still factories that are marked to wait for a signal
      /// but aren't signalled we throw an error with details which objects are concerned
      final notReadyTypes = _factories.entries
          .where((x) => (x.value.shouldSignalReady && !x.value.isReady))
          .map<String>((x) => x.key.toString())
          .toList();
      final notReadyNames = _factoriesByName.entries
          .where((x) => (x.value.shouldSignalReady && !x.value.isReady))
          .map<String>((x) => x.key)
          .toList();
      throwIf(
          notReadyNames.isNotEmpty || notReadyTypes.isNotEmpty,
          StateError(
              'Registered types/names: $notReadyTypes  / $notReadyNames should signal ready but are not ready'));

      ///    signal the [ready] and [readyFuture]
      _readySignalStream.add(true);
    }
  }
}

enum _ServiceFactoryType { alwaysNew, constant, lazy }

class _ServiceFactory<T> {
  final _ServiceFactoryType factoryType;
  final FactoryFunc creationFunction;
  final String instanceName;
  final bool shouldSignalReady;
  bool isReady;
  Object instance;
  Type registrationType;

  bool get isNamedRegistration => instanceName != null;

  _ServiceFactory(this.factoryType,
      {this.creationFunction,
      this.instance,
      this.isReady = false,
      this.shouldSignalReady = false,
      this.instanceName}) {
    registrationType = T;
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
}
