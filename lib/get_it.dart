library get_it;

typedef FactoryFunc = Object Function();

/// A Calculator.
class GetIt {
  static Map<Type, _ServiceFactory> _factories = new Map<Type, _ServiceFactory>();

  static T get<T>() {
    var object = _factories[T];
    if (object == null) {
      throw new Exception("Object of type ${T.toString()} is not registered inside GetIt");
    }
    return object.getObject() as T;
  }

  static void register<T>(FactoryFunc func) {
    var factory = new _ServiceFactory();
    factory.create = func;
    factory.type = ServiceFactoryType.alwaysNew;
    _factories[T] = factory;
  }

  static void registerLazySingleton<T>(FactoryFunc func) {
    var factory = new _ServiceFactory();
    factory.create = func;
    factory.type = ServiceFactoryType.lazy;
    _factories[T] = factory;
  }

  static void registerConstant<T>(T instance) {
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
  }
}
