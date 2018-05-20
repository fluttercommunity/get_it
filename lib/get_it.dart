library get_it;

typedef FactoryFunc<T> = T Function();

/// Very simple and easy to use service locator
/// You register your object creation or an instance of an object with [register], [registerSingleton] or [registerLazySingleton]
/// And retrieve the desired object using [get]
class GetIt {
  static Map<Type, _ServiceFactory> _factories = new Map<Type, _ServiceFactory>();

  /// retrives or creates an instance of a registered type [T] depending on the registration function used for this type.
  static T get<T>() {
    var object = _factories[T];
    if (object == null) {
      throw new Exception("Object of type ${T.toString()} is not registered inside GetIt");
    }
    return object.getObject<T>();
  }

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [fun] factory funtion for this type
  static void register<T>(FactoryFunc<T> func) {
    var factory = new _ServiceFactory();
    factory.create = func;
    factory.type = ServiceFactoryType.alwaysNew;
    _factories[T] = factory;
  }

  /// registers a type as Singleton by passing a factory function that will be called on the first call of [get] on that type
  /// [T] type to register
  /// [fun] factory funtion for this type
  static void registerLazySingleton<T>(FactoryFunc<T> func) {
    var factory = new _ServiceFactory();
    factory.create = func;
    factory.type = ServiceFactoryType.lazy;
    _factories[T] = factory;
  }

  /// registers a type as Singleton by passing an instance that will be returned on each call of [get] on that type
  /// [T] type to register
  /// [fun] factory funtion for this type
  static void registerSingleton<T>(T instance) {
    var factory = new _ServiceFactory();
    factory.instance = instance;
    factory.type = ServiceFactoryType.constant;
    _factories[T] = factory;
  }
}

enum ServiceFactoryType { alwaysNew, constant, lazy }

class _ServiceFactory {
  ServiceFactoryType type;

  FactoryFunc create;
  Object instance;

  T getObject<T>() {
    try {
      switch (type) {
        case ServiceFactoryType.alwaysNew:
          return create() as T;
          break;
        case ServiceFactoryType.constant:
          return instance as T;
          break;
        case ServiceFactoryType.lazy:
          if (instance == null) {
            instance = create();
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
