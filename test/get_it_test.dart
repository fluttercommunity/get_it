import 'dart:async';

import 'package:test/test.dart';

import 'package:get_it/get_it.dart';

int constructorCounter;
int disposeCounter;

abstract class TestBaseClass {}

class TestClass extends TestBaseClass {
  TestClass() {
    constructorCounter++;
  }

  dispose() {
    disposeCounter++;
  }
}

class TestClass2 {}

class TestClass3 {}

class TestClass4 {}

void main() {
  test('register factory', () {
    var getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactory<TestBaseClass>(() => TestClass());

    //var instance1 = getIt.get<TestBaseClass>();

    var instance1 = getIt<TestBaseClass>();

    expect(instance1 is TestClass, true);

    var instance2 = getIt.get<TestBaseClass>();

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('register factory with access as singleton', () {
    constructorCounter = 0;
    GetIt.instance.registerFactory<TestBaseClass>(() => TestClass());

    var instance1 = GetIt.I<TestBaseClass>();

    expect(instance1 is TestClass, true);

    var instance2 = GetIt.I.get<TestBaseClass>();

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('register constant', () {
    var getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestBaseClass>(TestClass());

    var instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);

    var instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    GetIt.I.reset();
  });

  test('register lazySingleton', () {
    var getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(() => TestClass());

    expect(constructorCounter, 0);

    var instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    var instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    GetIt.I.reset();
  });

  test('register lazy singleton two instances of GetIt', () {
    GetIt.allowMultipleInstances = true;
    var secondGetIt = GetIt.asNewInstance();

    constructorCounter = 0;
    GetIt.instance.registerLazySingleton<TestBaseClass>(() => TestClass());
    secondGetIt.registerLazySingleton<TestBaseClass>(() => TestClass());

    var instance1 = GetIt.I<TestBaseClass>();

    expect(instance1 is TestClass, true);

    var instance2 = GetIt.I.get<TestBaseClass>();

    expect(instance1, instance2);
    expect(constructorCounter, 1);

    var instanceSecondGetIt = secondGetIt.get<TestBaseClass>();

    expect(instance1, isNot(instanceSecondGetIt));
    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('trying to access not registered type', () {
    var getIt = GetIt.instance;

    expect(() => getIt.get<int>(), throwsA(TypeMatcher<Exception>()));

    GetIt.I.reset();
  });

  test('register factory by Name', () {
    var getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactory(() => TestClass(), instanceName: 'FactoryByName');

    var instance1 = getIt('FactoryByName');

    expect(instance1 is TestClass, true);

    var instance2 = getIt('FactoryByName');
    ;

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('register constant by name', () {
    var getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'ConstantByName');

    var instance1 = getIt('ConstantByName');

    expect(instance1 is TestClass, true);

    var instance2 = getIt('ConstantByName');

    expect(instance1, instance2);

    expect(constructorCounter, 1);
    GetIt.I.reset();
  });

  test('register lazySingleton by name', () {
    var getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton(() => TestClass(), instanceName: 'LazyByName');

    expect(constructorCounter, 0);

    var instance1 = getIt('LazyByName');

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    var instance2 = getIt('LazyByName');

    expect(instance1, instance2);

    expect(constructorCounter, 1);
    GetIt.I.reset();
  });

  test('trying to access not registered type by name', () {
    var getIt = GetIt.instance;

    expect(() => getIt('not there'), throwsA(TypeMatcher<Exception>()));
    GetIt.I.reset();
  });

  test('unregister by type', () {
    var getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    var instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    var instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    getIt.unregister<TestClass>(disposingFunction: (testClass) {
      testClass.dispose();
    });

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(), throwsA(TypeMatcher<Exception>()));
  });

  test('unregister by name', () {
    var getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'instanceName');

    var instance1 = getIt.get('instanceName');

    expect(instance1 is TestClass, true);

    getIt.unregister(
        instanceName: 'instanceName',
        disposingFunction: (testClass) {
          testClass.dispose();
        });

    expect(disposeCounter, 1);

    expect(() => getIt('instanceName'), throwsA(TypeMatcher<Exception>()));
  });

  test('ready stream test', () async {
    var getIt = GetIt.instance;

    getIt.registerFactory<TestClass>(() => TestClass());
    getIt.registerFactory<TestClass2>(() => TestClass2());
    getIt.registerFactory<TestClass3>(
      () => TestClass3(),
    );
    getIt.registerFactory(() => TestClass(), instanceName: 'TestNamesInstance');

    expect(getIt.ready, emitsAnyOf([(_) => true]));

    getIt.signalReady();

    // make sure to allow the stream to emit an item
    await Future.delayed(Duration(seconds: 1));
  });

  test('ready future test', () async {
    GetIt.allowMultipleInstances = true;
    var getIt = GetIt
        .asNewInstance(); // We use new instance here to make sure other tests haven't signalled ready already

    getIt.registerFactory<TestClass>(() => TestClass());
    getIt.registerFactory<TestClass2>(() => TestClass2());
    getIt.registerFactory<TestClass3>(
      () => TestClass3(),
    );
    getIt.registerFactory(() => TestClass(), instanceName: 'TestNamesInstance');

    expect(getIt.readyFuture, completes);

    getIt.signalReady();
  });

  test('signalReady with not ready registered objects', () async {
    GetIt.allowMultipleInstances = true;
    var getIt = GetIt
        .asNewInstance(); // We use new instance here to make sure other tests haven't signalled ready already

    getIt.registerFactory<TestClass>(() => TestClass(), signalsReady: true);
    getIt.registerFactory<TestClass2>(() => TestClass2(), signalsReady: true);
    getIt.registerFactory<TestClass3>(
      () => TestClass3(),
    );
    getIt.registerFactory(() => TestClass(),
        instanceName: 'TestNamesInstance', signalsReady: true);

    getIt.signalReady<TestClass>();
    getIt.signalReady<TestClass2>();
    //getIt.signalReady('TestNamesInstance'); //this is not signalled.

    expect(() => getIt.signalReady(), throwsA(TypeMatcher<Exception>()));
  });

  test('ready though multiple ready signals', () async {
    GetIt.allowMultipleInstances = true;
    var getIt = GetIt
        .asNewInstance(); // We use new instance here to make sure other tests haven't signalled ready already

    getIt.registerFactory<TestClass>(() => TestClass(), signalsReady: true);
    getIt.registerFactory<TestClass2>(() => TestClass2(), signalsReady: true);
    getIt.registerFactory<TestClass3>(
      () => TestClass3(),
    );
    getIt.registerFactory(() => TestClass(),
        instanceName: 'TestNamesInstance', signalsReady: true);

    expect(getIt.ready, emitsAnyOf([(_) => true]));

    getIt.signalReady<TestClass>();
    getIt.signalReady<TestClass2>();
    getIt.signalReady('TestNamesInstance');
  });
  test(
      'trying to signalReady on a entry that does not await a signal should throw',
      () async {
    GetIt.allowMultipleInstances = true;
    var getIt = GetIt
        .asNewInstance(); // We use new instance here to make sure other tests haven't signalled ready already

    getIt.registerFactory<TestClass>(() => TestClass(), signalsReady: true);
    getIt.registerFactory<TestClass2>(() => TestClass2(), signalsReady: true);
    getIt.registerFactory<TestClass3>(
      () => TestClass3(),
    );
    getIt.registerFactory(() => TestClass(),
        instanceName: 'TestNamesInstance', signalsReady: true);

    expect(() => getIt.signalReady<TestClass3>(),
        throwsA(TypeMatcher<Exception>()));
  });
  test('as long as not all are signalled no ready should never signalled',
      () async {
    GetIt.allowMultipleInstances = true;
    var getIt = GetIt
        .asNewInstance(); // We use new instance here to make sure other tests haven't signalled ready already

    getIt.registerFactory<TestClass>(() => TestClass(), signalsReady: true);
    getIt.registerFactory<TestClass2>(() => TestClass2(), signalsReady: true);
    getIt.registerFactory<TestClass3>(
      () => TestClass3(),
    );
    getIt.registerFactory(() => TestClass(),
        instanceName: 'TestNamesInstance', signalsReady: true);

    expect(getIt.readyFuture.timeout(Duration(seconds: 1)),
        throwsA(TypeMatcher<TimeoutException>()));

    getIt.signalReady<TestClass>();
    getIt.signalReady<TestClass2>();
    //getIt.signalReady('TestNamesInstance'); //this is not signalled.
  });
}
