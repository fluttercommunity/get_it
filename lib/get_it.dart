library get_it;

import 'package:meta/meta.dart';

typedef FactoryFunc<T> = T Function();

/// Very simple and easy to use service locator
/// You register your object creation or an instance of an object with [registerFactory], 
/// [registerSingleton] or [registerLazySingleton]
/// And retrieve the desired object using [get] or call your loactor das as function as its a 
/// callable class
class GetIt {
  final _factories = Map<Type, _ServiceFactory<dynamic>>();
  final _factoriesByName = Map<String, _ServiceFactory<dynamic>>();

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  bool allowReassignment = false;

  /// retrives or creates an instance of a registered type [T] depending on the registration function used for this type.
  T get<T>([String instanceName]) {
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
  /// [func] factory funtion for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be nesseary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerFactory<T>(FactoryFunc<T> func, [String instanceName]) {
    _register<T>(
        type: _ServiceFactoryType.alwaysNew,
        instanceName: instanceName,
        factoryFunc: func);
  }

  /// registers a type as Singleton by passing a factory function that will be called on the first call of [get] on that type
  /// [T] type to register
  /// [func] factory funtion for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be nesseary if you need to register more
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
  /// name instead of a type. This should only be nesseary if you need to register more
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
    return null; // should never get here but to make the analyzer happy
  }
}
