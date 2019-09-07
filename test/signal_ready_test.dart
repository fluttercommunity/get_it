import 'dart:async';

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'package:get_it/get_it.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

abstract class TestBaseClass {}

class TestClass extends TestBaseClass {
  TestClass({@required bool signalsReady}) {
    constructorCounter++;
    if (signalsReady) {
      Future.delayed(Duration(milliseconds: 10))
          .then((_) => GetIt.instance.signalReady(this))
          .catchError((e) {
        errorCounter++;
        print(e);
      });
    }
  }

  void signalReady() => GetIt.instance.signalReady(this);

  dispose() {
    disposeCounter++;
  }
}

class TestClass2 {
  TestClass2({@required bool signalsReady}) {
    constructorCounter++;
    if (signalsReady) {
      Future.delayed(Duration(milliseconds: 10))
          .then((_) => GetIt.instance.signalReady(this))
          .catchError((e) {
        errorCounter++;
        print(e);
      });
    }
  }
}

class TestClass3 {
  TestClass3({@required bool signalsReady}) {
    constructorCounter++;
    if (signalsReady) {
      Future.delayed(Duration(milliseconds: 10))
          .then((_) => GetIt.instance.signalReady(this))
          .catchError((e) {
        errorCounter++;
        print(e);
      });
    }
  }
}

class TestClass4 {}

void main() {
  test('ready stream test', () async {
    var getIt = GetIt.instance;

    getIt.registerFactory<TestClass>(() => TestClass(signalsReady: false));
    getIt.registerFactory<TestClass2>(() => TestClass2(signalsReady: false));
    getIt.registerFactory<TestClass3>(() => TestClass3(signalsReady: false));
    getIt.registerFactory(() => TestClass(signalsReady: false),
        instanceName: 'TestNamesInstance');

    expect(getIt.ready, emitsAnyOf([(_) => true]));

    getIt.signalReady();

    // make sure to allow the stream to emit an item
    await Future.delayed(Duration(seconds: 1));
  });

  test('ready future test', () async {
    GetIt.allowMultipleInstances = true;
    var getIt = GetIt
        .asNewInstance(); // We use new instance here to make sure other tests haven't signalled ready already

    getIt.registerFactory<TestClass>(() => TestClass(signalsReady: false));
    getIt.registerFactory<TestClass2>(() => TestClass2(signalsReady: false));
    getIt.registerFactory<TestClass3>(
      () => TestClass3(signalsReady: false),
    );
    getIt.registerFactory(() => TestClass(signalsReady: false),
        instanceName: 'TestNamesInstance');

    expect(getIt.readyFuture, completes);

    getIt.signalReady();
  });

  test('signalReady with not ready registered objects', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingleton<TestClass>(TestClass(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass2>(
        () => TestClass2(signalsReady: false),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass3>(
        () => TestClass3(signalsReady: false));
    getIt.registerLazySingleton(() => TestClass(signalsReady: false),
        instanceName: 'TestNamesInstance', signalsReady: true);

    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt<TestClass2>();
    var instance3 = getIt<TestClass3>();
    var instance4 = getIt('TestNamesInstance');

    expect(() => getIt.signalReady(), throwsA(TypeMatcher<StateError>()));
  });

  test('ready though multiple ready signals', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerLazySingleton<TestClass>(() => TestClass(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass2>(
        () => TestClass2(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass3>(
        () => TestClass3(signalsReady: false),
        signalsReady: false);
    getIt.registerLazySingleton(() => TestClass(signalsReady: true),
        instanceName: 'TestNamesInstance', signalsReady: true);

    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt<TestClass2>();
    var instance3 = getIt<TestClass3>();
    var instance4 = getIt('TestNamesInstance');

    expect(getIt.ready, emitsAnyOf([(_) => true]));
    expect(errorCounter, 0);
  });
  test(
      'trying to signalReady on a entry that does not await a signal should throw',
      () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerLazySingleton<TestClass>(() => TestClass(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass2>(
        () => TestClass2(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass3>(
        () => TestClass3(signalsReady: true),
        signalsReady: false);
    getIt.registerLazySingleton(() => TestClass(signalsReady: true),
        instanceName: 'TestNamesInstance', signalsReady: true);
    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt<TestClass2>();
    var instance3 = getIt<TestClass3>();
    var instance4 = getIt('TestNamesInstance');

    // make sure to allow the stream to emit an item
    await Future.delayed(Duration(seconds: 4));

    expect(errorCounter, 1);
  });
  test('trying to signalReady on a an instance that\'s  not in GetIt',
      () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerLazySingleton<TestClass>(() => TestClass(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass2>(
        () => TestClass2(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass3>(
        () => TestClass3(signalsReady: false),
        signalsReady: false);
    getIt.registerLazySingleton(() => TestClass(signalsReady: true),
        instanceName: 'TestNamesInstance', signalsReady: true);
    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt<TestClass2>();
    var instance3 = getIt<TestClass3>();
    var instance4 = TestClass(signalsReady: true); // this one should fail

    // make sure to allow the stream to emit an item
    await Future.delayed(Duration(seconds: 1));

    expect(errorCounter, 1);
  });
  test(
      'trying to signalReady on a an instance that\'s  registered twice in GetIt',
      () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    var testClass = TestClass(signalsReady: true);
    getIt.registerSingleton<TestClass>(testClass, signalsReady: true);
    getIt.registerLazySingleton<TestClass2>(
        () => TestClass2(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass3>(
        () => TestClass3(signalsReady: false),
        signalsReady: false);
    getIt.registerSingleton(testClass,
        instanceName: 'RegisteredTheSecondTime', signalsReady: true);
    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt<TestClass2>();
    var instance3 = getIt<TestClass3>();

    // make sure to allow the stream to emit an item
    await Future.delayed(Duration(seconds: 1));

    expect(errorCounter, 1);
  });
  test('signaling the same instance twice', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingleton<TestClass>(() => TestClass(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass3>(
        () => TestClass3(signalsReady: false),
        signalsReady: false);
    // make sure that all constructors are run
    var instance2 = getIt<TestClass>();
    var instance3 = getIt<TestClass3>();

    // make sure to allow the stream to emit an item
    await Future.delayed(Duration(seconds: 1));

    expect(instance2.signalReady, throwsA(TypeMatcher<StateError>()));
  });

  test('as long as not all are signalled, ready should never signalled',
      () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingleton<TestClass>(() => TestClass(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass2>(
        () => TestClass2(signalsReady: true),
        signalsReady: true);
    getIt.registerLazySingleton<TestClass3>(
      () => TestClass3(signalsReady: false),
    );
    getIt.registerLazySingleton(() => TestClass(signalsReady: false),
        instanceName: 'TestNamesInstance', signalsReady: true);
    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt<TestClass2>();
    var instance3 = getIt<TestClass3>();
    var instance4 = getIt('TestNamesInstance');

    expect(getIt.readyFuture.timeout(Duration(seconds: 1)),
        throwsA(TypeMatcher<TimeoutException>()));
  });
}
