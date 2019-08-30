library get_it;

import 'package:meta/meta.dart';

typedef FactoryFunc<T> = T Function();

/// Very simple and easy to use service locator
/// You register your object creation or an instance of an object with [registerFactory],
/// [registerSingleton] or [registerLazySingleton]
/// And retrieve the desired object using [get] or call your locator das as function as its a
/// callable class
class GetIt {
  final _factories = Map<Type, _ServiceFactory<dynamic>>();
  final _factoriesByName = Map<String, _ServiceFactory<dynamic>>();

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
        'You have to provide either a type or a name. Did you accidentally do  `var sl=GetIt.instance();` instead of var sl=GetIt.instance;');

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
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerFactory<T>(FactoryFunc<T> func, [String instanceName]) {
    _register<T>(
        type: _ServiceFactoryType.alwaysNew,
        instanceName: instanceName,
        factoryFunc: func);
  }

  /// registers a type as Singleton by passing a factory function that will be called on the first call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerLazySingleton<T>(FactoryFunc<T> func, [String instanceName]) {
    _register<T>(
        type: _ServiceFactoryType.lazy,
        instanceName: instanceName,
        factoryFunc: func);
  }

  /// registers a type as Singleton by passing an [instance] of that type
  ///  that will be returned on each call of [get] on that type
  /// [T] type to register
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerSingleton<T>(T instance, [String instanceName]) {
    _register<T>(
        type: _ServiceFactoryType.constant,
        instanceName: instanceName,
        instance: instance);
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
      @required String instanceName}) {
    assert(allowReassignment || !_factories.containsKey(T),
        "Type ${T.toString()} is already registered");
    assert(
      instanceName != null ||
          (allowReassignment || !_factoriesByName.containsKey(instanceName)),
      "An object of name $instanceName is already registered",
    );

    var serviceFactory = _ServiceFactory<T>(type,
        creationFunction: factoryFunc, instance: instance);
    if (instanceName == null) {
      _factories[T] = serviceFactory;
    } else {
      _factoriesByName[instanceName] = serviceFactory;
    }
  }
/// Unregister by Type [T] or by name [instanceName]
/// if you need to dispose any resources you can do it using [disposal] function
/// that provides a instance of your class to be disposed
  void unregister<T>({String instanceName, Function(T) disposal}) {
    assert(_factoriesByName.containsKey(instanceName) || _factories.containsKey(T), 'Nor Type ${T.toString()} or instance Name must not be null');
    if (instanceName == null) {
      disposal(get<T>());
      _factories.remove(T);
    } else {
      disposal(get(instanceName));
      _factoriesByName.remove(instanceName);
    }
    _factories.remove(T);
  }
}

enum _ServiceFactoryType { alwaysNew, constant, lazy }

class _ServiceFactory<T> {
  _ServiceFactoryType type;
  FactoryFunc creationFunction;
  Object instance;

  _ServiceFactory(this.type, {this.creationFunction, this.instance});

  T getObject() {
    try {
      switch (type) {
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
    return null; // should never get here but to make the analyser happy
  }
}
