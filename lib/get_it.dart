library get_it;

import 'dart:async';

import 'package:async/async.dart';
import 'package:meta/meta.dart';

part 'get_it_impl.dart';

/// Signature of the factory function used by normal factories
typedef FactoryFunc<T> = T Function();

/// Signature of the factory function used by async factories
typedef FactoryFuncAsync<T> = Future<T> Function();

class WaitingTimeOutException implements Exception {
  /// In case of an timeout while waiting for an instance to get ready
  /// This exception is thrown whith information about who is still waiting
  /// if you pass the [callee] parameter to [isReady]
  /// this maps lists which callees is waiting for whom
  final Map<String, List<String>> areWaitedBy;

  /// Lists with Types that are still not ready
  final List<String> notReadyYet;

  /// Lists with Types that are already ready
  final List<String> areReady;

  WaitingTimeOutException(this.areWaitedBy, this.notReadyYet, this.areReady)
      : assert(
            areWaitedBy != null && notReadyYet != null && areReady != null);

  @override
  String toString() {
    print(
        'GetIt: There was a timeout while waiting for an instance to signal ready');
    print('The following instance types where waiting for completion');
    for (var entry in areWaitedBy.entries) {
      print('${entry.value} is waiting for ${entry.key}');
    }
    print('The following instance types have NOT signalled ready yet');
    for (var entry in notReadyYet) {
      print('$entry');
    }
    print('The following instance types HAVE signalled ready yet');
    for (var entry in areReady) {
      print('$entry');
    }
    return super.toString();
  }
}

/// Very simple and easy to use service locator
/// You register your object creation factory or an instance of an object with [registerFactory],
/// [registerSingleton] or [registerLazySingleton]
/// And retrieve the desired object using [get] or call your locator das as function as its a
/// callable class
/// Additionally GetIt offers asynchronous creation function as well as functions to synchronize
/// the async initialization of multiple Singletons
abstract class GetIt {
  static GetIt _instance;

  /// access to the Singleton instance of GetIt
  static GetIt get instance {
    _instance ??= _GetItImplementation();
    return _instance;
  }

  /// Short form to access the instance of GetIt
  static GetIt get I => instance;

  /// If you need more than one instance of GetIt you can use [asNewInstance()]
  /// You should prefer to use the `instance()` method to access the global instance of [GetIt].
  factory GetIt.asNewInstance() {
    return _GetItImplementation();
  }

  /// By default it's not allowed to register a type a second time.
  /// If you really need to you can disable the asserts by setting[allowReassignment]= true
  bool allowReassignment = false;

  /// retrieves or creates an instance of a registered type [T] depending on the registration
  /// function used for this type or based on a name.
  T get<T>([String instanceName]);

  /// Returns an Future of an instance that is created by an async factory or a Singleton that is
  /// not ready with its initialization.
  Future<T> getAsync<T>([String instanceName]);

  /// Callable class so that you can write `GetIt.instance<MyType>` instead of
  /// `GetIt.instance.get<MyType>`
  T call<T>([String instanceName]);

  /// registers a type so that a new instance will be created on each call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerFactory<T>(FactoryFunc<T> func, {String instanceName});

  /// We use a separate function for the async registration instead just a new parameter
  /// to make the intention explicit
  /// [T] type to register
  /// [func] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerFactoryAsync<T>(FactoryFuncAsync<T> func, {String instanceName});

  /// registers a type as Singleton by passing an [instance] of that type
  ///  that will be returned on each call of [get] on that type
  /// [T] type to register
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  void registerSingleton<T>(T instance,
      {String instanceName, bool signalsReady = false});

  void registerSingletonWithDependencies<T>(FactoryFunc<T> providerFunc,
      {String instanceName,
      Iterable<Type> dependsOn,
      bool signalsReady = false});

  /// registers a type as Singleton by passing an asynchronous factory function which has to return the
  /// that will be returned on each call of [get] on that type.
  /// To control if an async Singleton has completed its initialisation [providerFunc] gets a `Completer` passed
  /// as parameter that has to be completed to signal that this instance is ready.
  /// Therefore you have to ensure that the instance is ready before you use [get] on it or use [getAsync()] to
  /// wait for the completion.
  /// You can check if the instance is ready by using [isReady()] and [isReadySync()].
  /// [providerFunc] is executed immediately. If it returns an object and not a Future the
  /// object has to complete the completer itself.
  /// if it returns a future the completer will be completed automatically when that future completes
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  /// [dependsOn] if this instance depends on other registered async instances before it can be initilaized
  /// you can either orchestrate this manually using [isReady()] or pass a list of the type that the
  /// instance depends on here. The async factory will wait to be executed till this types are ready.
  void registerSingletonAsync<T>(FactoryFuncAsync<T> providerFunc,
      {String instanceName,
      Iterable<Type> dependsOn,
      bool signalsReady = false});

  /// registers a type as Singleton by passing a factory function that will be called
  /// on the first call of [get] on that type
  /// [T] type to register
  /// [func] factory function for this type
  /// [instanceName] if you provide a value here your factory gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended
  /// [registerLazySingleton] does not influence [allReady]
  void registerLazySingleton<T>(FactoryFunc<T> func, {String instanceName});

  /// registers a type as Singleton by passing an asynchronous factory function which has to return the
  /// that will be returned on each call of [get] on that type.
  /// This is a rather esoteric requirement so you should seldom have the need to use it.
  /// This factory function [providerFunc] isn't called immediately but wait till the first call by
  /// [getAsync()] or [isReady()] is made
  /// To control if an async Singleton has completed its [providerFunc] gets a `Completer` passed
  /// as parameter that has to be completed to signal that this instance is ready.
  /// Therefore you have to ensure that the instance is ready before you use [get] on it or use [getAsync()] to
  /// wait for the completion.
  /// You can check if the instance is ready by using [isReady()] and [isReadySync()].
  /// [providerFunc] when it returns an object and not a Future the
  /// object has to complete the completer itself.
  /// if it returns a future the completer will be completed automatically when that future completes.
  /// [instanceName] if you provide a value here your instance gets registered with that
  /// name instead of a type. This should only be necessary if you need to register more
  /// than one instance of one type. Its highly not recommended.
  /// [registerLazySingletonAsync] does not influence [allReady]
  void registerLazySingletonAsync<T>(FactoryFuncAsync<T> providerFunc,
      {String instanceName});

  /// Clears all registered types. Handy when writing unit tests
  void reset();

  /// Clears the instance of a lazy singleton registered type,
  /// being able to call the factory function on the next call
  /// of [get] on that type again.
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

  /// returns a Future that completes if all asynchronously created Singletons are ready
  /// This can be used inside a FutureBuilder to change the UI as soon as all initialization
  /// is done
  /// If you pass a [timeout], an [WaitingTimeOutException] will be thrown if not all Singletons
  /// were ready in the given time. The Exception contains details on which Singletons are not ready yet.
  Future<void> allReady({Duration timeout});

  /// Returns a Future that is completed when a given registered Factories/Singletons has
  /// signalled that it is ready
  /// [T] Type of the factory/Singleton to be waited for
  /// [instance] registered instance to be waited for
  /// [instanceName] factory/Singleton to be waited for that was registered by name instead of a type.
  /// You should only use one of the
  /// If you pass a [timeout], an [WaitingTimeOutException] will be thrown if not all Singletons
  /// were ready in the given time. The Exception contains details on which Singletons are not ready yet.
  /// [callee] optional parameter which makes debugging easier. Pass `this` in here.
  Future<void> isReady<T>({
    Object instance,
    String instanceName,
    Duration timeout,
    Object callee,
  });

  /// Checks if an async Singleton defined by an [instance], a type [T] or an [instanceName]
  /// is ready
  bool isReadySync<T>({Object instance, String instanceName});

  /// Returns if all async Singletons are ready
  bool allReadySync([ignorePendingAsyncCreation = false]);

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
  void signalReady(Object instance);
}
