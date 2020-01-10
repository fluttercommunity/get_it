library get_it;

import 'dart:async';
import 'dart:developer';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

part 'get_it_impl.dart';

typedef FactoryFunc<T> = T Function();
typedef FactoryFuncAsync<T> = Future<T> Function();
typedef SingletonProviderFunc<T> = FutureOr<T> Function(
    Completer initCompleter);

/// In case of an timeout while waiting for an instance to signal ready
/// This exception is thrown whith information about who is still waiting
class WaitingTimeOutException implements Exception {
  /// Lists with Types that are still not ready
  final List<Type> typesNotSignaledYet;
  /// Lists with named Instances that are still not ready
  final List<String> namedInstancesNotSignaledYet;

  WaitingTimeOutException(
      this.typesNotSignaledYet,this.namedInstancesNotSignaledYet)
      : assert(
            typesNotSignaledYet != null &&
            namedInstancesNotSignaledYet != null);

  @override
  String toString() {
    print(
        'GetIt: There was a timeout while waiting for an instance to signal ready');
    print('The following instance types have NOT signaled ready yet');
    for (var entry in typesNotSignaledYet) {
      print('$entry');
    }
    print('The following named instances have NOT signaled ready yet');
    for (var entry in namedInstancesNotSignaledYet) {
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

