import 'dart:async';

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'package:get_it/get_it.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

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

  setUp((){
    //make sure the instance is cleared before each test
    GetIt.I.reset();
  });

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

  test('trying to access not registered type', () {
    var getIt = GetIt.instance;

    expect(() => getIt.get<int>(), throwsA(TypeMatcher<ArgumentError>()));

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

    var instance1 = getIt();

    expect(instance1 is TestClass, true);

    TestClass instance2 = getIt('ConstantByName');

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

    expect(() => getIt('not there'), throwsA(TypeMatcher<ArgumentError>()));
    GetIt.I.reset();
  });

  test('reset lazySingleton', () {
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

    GetIt.I.resetLazySingleton<TestBaseClass>();

    var instance3 = getIt.get<TestBaseClass>();

    expect(instance3 is TestClass, true);

    expect(instance1, isNot(instance3));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('unregister by instance', () {
    var getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    var instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    var instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    getIt.unregister(
        instance: instance2,
        disposingFunction: (testClass) {
          testClass.dispose();
        });

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(), throwsA(TypeMatcher<ArgumentError>()));
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

    expect(() => getIt.get<TestClass>(), throwsA(TypeMatcher<ArgumentError>()));
  });

  test('unregister by name', () {
    var getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    var instance1 = getIt.get('instanceName');

    expect(instance1 is TestClass, true);

    getIt.unregister(
        instanceName: 'instanceName',
        disposingFunction: (testClass) {
          testClass.dispose();
        });

    expect(disposeCounter, 1);

    expect(() => getIt('instanceName'), throwsA(TypeMatcher<ArgumentError>()));
  });
  
  test('unregister by instance without disposing function', () {
    var getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    var instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    var instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    getIt.unregister(instance: instance2);

    expect(disposeCounter, 0);

    expect(() => getIt.get<TestClass>(), throwsA(TypeMatcher<ArgumentError>()));
  });
  
  test('unregister by type without disposing function', () {
    var getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    var instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    var instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    getIt.unregister<TestClass>();

    expect(disposeCounter, 0);

    expect(() => getIt.get<TestClass>(), throwsA(TypeMatcher<ArgumentError>()));
  });

  test('unregister by name without disposing function', () {
    var getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    var instance1 = getIt.get('instanceName');

    expect(instance1 is TestClass, true);

    getIt.unregister(instanceName: 'instanceName');

    expect(disposeCounter, 0);

    expect(() => getIt('instanceName'), throwsA(TypeMatcher<ArgumentError>()));
  });

  test(
      'can register a singleton with instanceName and retrieve it with generic parameters and instanceName', () {
    final getIt = GetIt.instance;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    var instance1 = getIt.get<TestClass>('instanceName');

    expect(instance1 is TestClass, true);
  });

}
