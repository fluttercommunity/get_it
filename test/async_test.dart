import 'dart:async';

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'package:get_it/get_it.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

abstract class TestBaseClass {}

class TestClass extends TestBaseClass {
  Completer completer;

  /// if we do the initialisation from inside the constructor the init function has to signal GetIt
  /// that it has finished. For that we need to pass in the completer that we got from the factory call
  /// that we set up in the registration.
  TestClass({@required bool internalCompletion, this.completer}) {
    constructorCounter++;
    Future.delayed(Duration(milliseconds: 10)).then((_) {
      if (internalCompletion) {
        completer.complete();
      }
    }).catchError((e) {
      errorCounter++;
      print(e);
    });
  }

  void signalReady() => completer?.complete();

  // We use this as dummy init that will return a future
  Future init() {
    return Future.delayed(Duration(milliseconds: 10));
  }

  dispose() {
    disposeCounter++;
  }
}

class TestClass2 extends TestBaseClass {
  Completer completer;
  TestClass2({@required bool internalCompletion, this.completer}) {
    constructorCounter++;

    Future.delayed(Duration(milliseconds: 10)).then((_) {
      if (internalCompletion) {
        completer.complete();
      }
    }).catchError((e) {
      errorCounter++;
      print(e);
    });
  }

  void signalReady() => completer?.complete();

  Future init() {
    return Future.delayed(Duration(milliseconds: 10));
  }

  dispose() {
    disposeCounter++;
  }
}

class TestClass3 extends TestBaseClass {
  Completer completer;
  TestClass3({@required bool internalCompletion, this.completer}) {
    constructorCounter++;
    Future.delayed(Duration(milliseconds: 10)).then((_) {
      if (internalCompletion) {
        completer.complete();
      }
    }).catchError((e) {
      errorCounter++;
      print(e);
    });
  }

  void signalReady() => completer?.complete();

  Future init() {
    return Future.delayed(Duration(milliseconds: 10));
  }

  dispose() {
    disposeCounter++;
  }
}

class TestClass4 {}

void main() {
  /// This is the most basic sync functionality. Not sure if we should keep it.
  test('manual ready future test', () async {
    var getIt = GetIt.instance;

    getIt
        .registerFactory<TestClass>(() => TestClass(internalCompletion: false));
    getIt.registerFactory<TestClass2>(
        () => TestClass2(internalCompletion: false));
    getIt.registerFactory<TestClass3>(
        () => TestClass3(internalCompletion: false));
    getIt.registerFactory(() => TestClass(internalCompletion: false),
        instanceName: 'TestNamesInstance');

    expect(getIt.allReady(), completes);

    getIt.signalReady();

    // make sure to allow the stream to emit an item
    await Future.delayed(Duration(seconds: 1));
  });

  test(
      'signalReady will throw if any async Singletons have not signaled completion',
      () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      (completer) => TestClass(internalCompletion: true, completer: completer),
    );
    getIt.registerSingletonAsync<TestClass>(
        (_) => TestClass(internalCompletion: false)..init(),
        instanceName: "Second instance");
    getIt.registerSingletonAsync<TestClass2>(
        (_) => TestClass2(internalCompletion: false)..init());
    // this here should signal internally but doesn't do it.
    getIt.registerSingletonAsync<TestClass3>(
        (_) => TestClass3(internalCompletion: true));

    expect(() => getIt.signalReady(), throwsA(TypeMatcher<StateError>()));
  });

  test('ready with internal signalling', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerSingletonAsync<TestClass>(
      (completer) => TestClass(internalCompletion: true, completer: completer),
    );
    getIt.registerSingletonAsync<TestClass2>(
      (completer) => TestClass2(internalCompletion: true, completer: completer),
    );
    getIt.registerSingletonAsync(
        (completer) =>
            TestClass2(internalCompletion: true, completer: completer),
        instanceName: 'Second Instance');

    expect(getIt.allReady(), completes);
  });

  test('ready external signalling', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      (completer) async {
        var instance = TestClass(internalCompletion: false, completer: null);
        await instance.init();
        completer.complete();
        return instance;
      },
    );
    getIt.registerSingletonAsync<TestClass2>((completer) async {
      var instance = TestClass2(internalCompletion: false, completer: null);
      await instance.init();
      completer.complete();
      return instance;
    }, instanceName: 'TestNamedInstance');

    expect(getIt.allReady(), completes);
  });

  test('ready automatic signalling', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      (completer) async => TestClass(internalCompletion: false)..init(),
    );
    getIt.registerSingletonAsync<TestClass2>(
      (completer) async => TestClass2(internalCompletion: false)..init(),
    );
    getIt.registerSingletonAsync(
        (completer) async => TestClass2(internalCompletion: false)..init(),
        instanceName: 'Second Instance');
    expect(getIt.allReady(), completes);
  });

  test('ready manual synchronisation of sequence', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;
    var flag1 = false;
    var flag2 = false;

    getIt.registerSingletonAsync<TestClass>(
      (completer) async {
        var instance = TestClass(internalCompletion: false);
        while (!flag1) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass2>(
      (completer) async {
        await getIt.isReady<TestClass>();
        var instance = TestClass2(internalCompletion: false);
        while (!flag2) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass3>(
      (completer) async {
        await getIt.isReady<TestClass2>();
        var instance = TestClass3(internalCompletion: false);
        await instance.init();
        return instance;
      },
    );

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    flag1 = true;

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.allReadySync(), false);

    flag2 = true;

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReady<TestClass2>(), completes);
    expect(getIt.isReady<TestClass3>(), completes);
    expect(getIt.allReady(), completes);
  });

  test('ready automatic synchronisation of sequence', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;
    var flag1 = false;
    var flag2 = false;

    getIt.registerSingletonAsync<TestClass>(
      (completer) async {
        var instance = TestClass(internalCompletion: false);
        while (!flag1) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass2>((completer) async {
      var instance = TestClass2(internalCompletion: false);
      while (!flag2) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      return instance;
    }, dependsOn: [TestClass]);

    getIt.registerSingletonAsync<TestClass3>((completer) async {
      var instance = TestClass3(internalCompletion: false);
      await instance.init();
      return instance;
    }, dependsOn: [TestClass, TestClass2]);

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    flag1 = true;

    // give the factory function a chance to run
    await Future.delayed(Duration(microseconds: 1));

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.allReadySync(), false);

    flag2 = true;

    expect(getIt.isReady<TestClass>(timeout: Duration(seconds: 5)), completes);
    expect(
        getIt.isReady<TestClass2>(timeout: Duration(seconds: 10)), completes);
    expect(
        getIt.isReady<TestClass3>(timeout: Duration(seconds: 15)), completes);
    expect(getIt.allReady(timeout: Duration(seconds: 20)), completes);
  });
  test('ready automatic synchronisation of sequence with following getAsync', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;
    var flag1 = false;
    var flag2 = false;

    getIt.registerSingletonAsync<TestClass>(
      (completer) async {
        var instance = TestClass(internalCompletion: false);
        while (!flag1) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass2>((completer) async {
      var instance = TestClass2(internalCompletion: false);
      while (!flag2) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      return instance;
    }, dependsOn: [TestClass]);

    getIt.registerSingletonAsync<TestClass3>((completer) async {
      var instance = TestClass3(internalCompletion: false);
      await instance.init();
      return instance;
    }, dependsOn: [TestClass, TestClass2]);

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    flag1 = true;

    // give the factory function a chance to run
    await Future.delayed(Duration(microseconds: 1));

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.allReadySync(), false);

    flag2 = true;

    expect(getIt.isReady<TestClass>(timeout: Duration(seconds: 5)), completes);
    expect(
        getIt.isReady<TestClass2>(timeout: Duration(seconds: 10)), completes);

    var instance = await getIt.getAsync<TestClass3>();

    expect(instance, TypeMatcher<TestClass3>());
  });

  test('asyncFactory called with getAsync', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerFactoryAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    var instance = await getIt.getAsync<TestClass>();
    expect(instance, TypeMatcher<TestClass>());
  });

  test('asyncFactory called with get instead of getAsync', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerFactoryAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    expect(()=> getIt.get<TestClass>(), throwsA(TypeMatcher<AssertionError>()));
  });

  test('asyncLazySingleton called with get before it was ready', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      (_) => Future.value(TestClass(internalCompletion: false)..init()),
    );

    await Future.delayed(Duration(microseconds: 1));
    expect(()=> getIt.get<TestClass>(), throwsA(TypeMatcher<AssertionError>()));
  });
 
  test('asyncLazySingleton called with getAsync', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      (_) => Future.value(TestClass(internalCompletion: false)..init()),
    );

    var instance = await getIt.getAsync<TestClass>();
    expect(instance, TypeMatcher<TestClass>());
  });

  test('asyncLazySingleton called with getAsync after wait for ready', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      (_) => Future.value(TestClass(internalCompletion: false)..init()),
    );

    await getIt.isReady<TestClass>(timeout: Duration(milliseconds: 20));

    var instance = await getIt.getAsync<TestClass>();
    expect(instance, TypeMatcher<TestClass>());
  });

  test('asyncLazySingleton called with get after wait for ready', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      (_) => Future.value(TestClass(internalCompletion: false)..init()),
    );

    await getIt.isReady<TestClass>(timeout: Duration(milliseconds: 20));

    var instance = getIt.get<TestClass>();
    expect(instance, TypeMatcher<TestClass>());
  });

}
