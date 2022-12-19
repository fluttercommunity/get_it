// ignore_for_file: unnecessary_type_check, avoid_redundant_argument_values, avoid_classes_with_only_static_members

import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

class TestBaseClassGeneric<T> {}

class TestClassGeneric<T> implements TestBaseClassGeneric<T> {}

abstract class TestBaseClass {}

class TestClass extends TestBaseClass {
  TestClass() {
    constructorCounter++;
  }
  void dispose() {
    disposeCounter++;
  }
}

class TestClassDisposable extends TestBaseClass with Disposable {
  TestClassDisposable() {
    constructorCounter++;
  }
  void dispose() {
    disposeCounter++;
  }

  @override
  void onDispose() {
    dispose();
  }
}

class TestClass2 {}

class TestClass3 {}

class TestClass4 {}

class TestClassParam {
  final String? param1;
  final int? param2;

  TestClassParam({this.param1, this.param2});
}

void main() {
  setUp(() async {
    // make sure the instance is cleared before each test
    await GetIt.I.reset();
    constructorCounter = 0;
    disposeCounter = 0;
    errorCounter = 0;
  });

  test('register factory', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactory<TestBaseClass>(() => TestClass());

    //final instance1 = getIt.get<TestBaseClass>();

    final TestBaseClass instance1 = getIt<TestBaseClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestBaseClass>();

    expect(getIt.isRegistered<TestBaseClass>(), true);
    expect(getIt.isRegistered<TestClass2>(), false);
    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);
  });

  test('register factory with one Param', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String, void>(
        (s, _) => TestClassParam(param1: s));

    //final instance1 = getIt.get<TestBaseClass>();

    final instance1 = getIt<TestClassParam>(param1: 'abc');
    final instance2 = getIt<TestClassParam>(param1: '123');

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, '123');
  });

  test('register factory with one nullable Param', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String?, void>(
        (s, _) => TestClassParam(param1: s));

    final instance1 = getIt<TestClassParam>(param1: 'abc');
    final instance2 = getIt<TestClassParam>(param1: null);

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, null);
  });

  test('register factory with two Params', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String, int>(
        (s, i) => TestClassParam(param1: s, param2: i));

    //final instance1 = getIt.get<TestBaseClass>();

    final instance1 = getIt<TestClassParam>(param1: 'abc', param2: 3);
    final instance2 = getIt<TestClassParam>(param1: '123', param2: 5);

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1.param2, 3);
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, '123');
    expect(instance2.param2, 5);
  });

  test('register factory with two nullable Params', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String?, int?>(
        (s, i) => TestClassParam(param1: s, param2: i));

    final instance1 = getIt<TestClassParam>(param1: 'abc', param2: 3);
    final instance2 = getIt<TestClassParam>();

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1.param2, 3);
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, null);
    expect(instance2.param2, null);
  });

  test('register factory with Params with wrong type', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String, int>(
        (s, i) => TestClassParam(param1: s, param2: i));

    expect(() => getIt.get<TestClassParam>(param1: 'abc', param2: '3'),
        throwsA(const TypeMatcher<TypeError>()));
  });

  test('register factory with Params with non-nullable type but not pass it',
      () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam, String, int>(
        (s, i) => TestClassParam(param1: s, param2: i));

    expect(() => getIt.get<TestClassParam>(param2: '3'),
        throwsA(const TypeMatcher<TypeError>()));
  });

  test('register factory with access as singleton', () {
    constructorCounter = 0;
    GetIt.instance.registerFactory<TestBaseClass>(() => TestClass());

    final TestBaseClass instance1 = GetIt.I<TestBaseClass>();

    expect(instance1 is TestClass, true);

    final instance2 = GetIt.I.get<TestBaseClass>();

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('register constant', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestBaseClass>(TestClass());

    final instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    GetIt.I.reset();
  });

  test('reset', () async {
    final getIt = GetIt.instance;
    int destructorCounter = 0;

    getIt.registerSingleton<TestBaseClass>(TestClass());
    getIt.registerSingleton<TestBaseClass>(TestClass(),
        instanceName: 'instance2', dispose: (_) {
      destructorCounter++;
    });

    await getIt.reset();
    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));

    expect(destructorCounter, 1);
  });

  test('reset which Disposable Interface', () async {
    disposeCounter = 0;
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestBaseClass>(TestClassDisposable());

    await getIt.reset();
    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));

    expect(disposeCounter, 1);
  });

  test('register lazySingleton', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(() => TestClass());

    expect(constructorCounter, 0);

    final instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    final instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    GetIt.I.reset();
  });

  test('trying to access not registered type', () {
    final getIt = GetIt.instance;

    expect(
        () => getIt.get<int>(), throwsA(const TypeMatcher<AssertionError>()));

    GetIt.I.reset();
  });

  test('register factory by Name', () {
    final getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactory(() => TestClass(), instanceName: 'FactoryByName');

    final TestClass instance1 = getIt<TestClass>(instanceName: 'FactoryByName');

    expect(instance1 is TestClass, true);

    // ignore: prefer_final_locals
    TestClass instance2 = getIt(instanceName: 'FactoryByName');

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('register constant by name', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'ConstantByName');

    final TestClass instance1 =
        getIt<TestClass>(instanceName: 'ConstantByName');

    expect(instance1 is TestClass, true);

    final TestClass instance2 = getIt(instanceName: 'ConstantByName');

    expect(instance1, instance2);

    expect(constructorCounter, 1);
    GetIt.I.reset();
  });

  test('register lazySingleton by name', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(() => TestClass(),
        instanceName: 'LazyByName');

    expect(constructorCounter, 0);

    final TestBaseClass instance1 =
        getIt<TestBaseClass>(instanceName: 'LazyByName');

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    final TestBaseClass instance2 =
        getIt<TestBaseClass>(instanceName: 'LazyByName');

    expect(instance1, instance2);

    expect(constructorCounter, 1);
    GetIt.I.reset();
  });

  test('register lazy singleton two instances of GetIt', () {
    final secondGetIt = GetIt.asNewInstance();

    constructorCounter = 0;
    GetIt.instance.registerLazySingleton<TestBaseClass>(() => TestClass());
    secondGetIt.registerLazySingleton<TestBaseClass>(() => TestClass());

    final TestBaseClass instance1 = GetIt.I<TestBaseClass>();

    expect(instance1 is TestClass, true);

    final instance2 = GetIt.I.get<TestBaseClass>();

    expect(instance1, instance2);
    expect(constructorCounter, 1);

    final instanceSecondGetIt = secondGetIt.get<TestBaseClass>();

    expect(instance1, isNot(instanceSecondGetIt));
    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('trying to access not registered type by name', () {
    final getIt = GetIt.instance;

    expect(() => getIt(instanceName: 'not there'),
        throwsA(const TypeMatcher<AssertionError>()));
    GetIt.I.reset();
  });

  test('reset lazy Singleton when the disposing function is a future',
      () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(() => TestClass());

    expect(constructorCounter, 0);

    final instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    final instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await GetIt.I.resetLazySingleton<TestBaseClass>(
        disposingFunction: (dynamic testClass) async {
      await Future.value(testClass.dispose());
    });

    final instance3 = getIt.get<TestBaseClass>();

    expect(instance3 is TestClass, true);

    expect(instance1, isNot(instance3));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('reset lazy Singleton when the disposing function is not a future',
      () async {
    final getIt = GetIt.instance;

    disposeCounter = 0;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestClass>(() => TestClass());

    expect(constructorCounter, 0);

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    GetIt.I
        .resetLazySingleton<TestClass>(disposingFunction: (x) => x.dispose());

    final instance3 = getIt.get<TestClass>();

    expect(disposeCounter, 1);

    expect(instance3 is TestClass, true);

    expect(instance1, isNot(instance3));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('reset lazy Singleton when the dispose of the register is a future',
      () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(() => TestClass(),
        dispose: (dynamic testClassBase) async {
      await Future.value(testClassBase.dispose());
    });

    expect(constructorCounter, 0);

    final instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    final instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await GetIt.I.resetLazySingleton<TestBaseClass>();

    final instance3 = getIt.get<TestBaseClass>();

    expect(disposeCounter, 1);

    expect(instance3 is TestClass, true);

    expect(instance1, isNot(instance3));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('reset lazy Singleton when the dispose of the register is not a future',
      () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(() => TestClass(),
        dispose: (dynamic testClassBase) => testClassBase.dispose());

    expect(constructorCounter, 0);

    final instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    final instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    GetIt.I.resetLazySingleton<TestBaseClass>();

    final instance3 = getIt.get<TestBaseClass>();

    expect(disposeCounter, 1);

    expect(instance3 is TestClass, true);

    expect(instance1, isNot(instance3));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('reset LazySingleton by instance only', () {
    // Arrange
    final getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton<TestClass>(() => TestClass());
    final instance1 = getIt.get<TestClass>();

    // Act
    GetIt.I.resetLazySingleton(instance: instance1);

    // Assert
    final instance2 = getIt.get<TestClass>();
    expect(instance1, isNot(instance2));
    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('unregister by instance when the dispose of the register is a future',
      () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass(),
        dispose: (dynamic testClass) async =>
            Future.value(testClass.dispose()));

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await getIt.unregister(instance: instance2);

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test(
      'unregister by instance when the dispose of the register is not a future',
      () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass(),
        dispose: (dynamic testClass) => testClass.dispose());

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    getIt.unregister(instance: instance2);

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test('unregister by instance when the disposing function is not a future',
      () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    getIt.unregister(
        instance: instance2,
        disposingFunction: (dynamic testClass) {
          testClass.dispose();
        });

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test('unregister by instance when the disposing function is a future',
      () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await getIt.unregister(
        instance: instance2,
        disposingFunction: (dynamic testClass) async {
          await Future.value(testClass.dispose());
        });

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test('unregister by type', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await getIt.unregister<TestClass>(disposingFunction: (testClass) {
      testClass.dispose();
    });

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test('unregister by name', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');
    getIt.registerSingleton(TestClass(), instanceName: 'instanceName2');
    getIt.registerSingleton(TestClass2(), instanceName: 'instanceName');

    final TestClass instance1 = getIt.get(instanceName: 'instanceName');

    expect(instance1 is TestClass, true);

    await getIt.unregister<TestClass>(
        instanceName: 'instanceName',
        disposingFunction: (testClass) {
          testClass.dispose();
        });

    expect(disposeCounter, 1);

    expect(() => getIt<TestClass>(instanceName: 'instanceName'),
        throwsA(const TypeMatcher<AssertionError>()));
    expect(getIt<TestClass>(instanceName: 'instanceName2'),
        const TypeMatcher<TestClass>());
    expect(getIt<TestClass2>(instanceName: 'instanceName'),
        const TypeMatcher<TestClass2>());
  });

  test('unregister by instance without disposing function', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await getIt.unregister(instance: instance2);

    expect(disposeCounter, 0);

    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test('unregister by type without disposing function', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass());

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);

    final instance2 = getIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await getIt.unregister<TestClass>();

    expect(disposeCounter, 0);

    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test(
      'unregister by type without disposing function function but with implementing Disposable',
      () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton<TestClassDisposable>(TestClassDisposable());

    final instance1 = getIt.get<TestClassDisposable>();

    expect(instance1 is TestClassDisposable, true);

    final instance2 = getIt.get<TestClassDisposable>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);

    await getIt.unregister<TestClassDisposable>();

    expect(disposeCounter, 1);

    expect(() => getIt.get<TestClassDisposable>(),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test('unregister by name without disposing ', () async {
    final getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    final instance1 = getIt.get<TestClass>(instanceName: 'instanceName');

    expect(instance1 is TestClass, true);

    await getIt.unregister<TestClass>(instanceName: 'instanceName');

    expect(disposeCounter, 0);

    expect(() => getIt<TestClass>(instanceName: 'instanceName'),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test(
      'can register a singleton with instanceName and retrieve it with generic parameters and instanceName',
      () {
    final getIt = GetIt.instance;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    final instance1 = getIt.get<TestClass>(instanceName: 'instanceName');

    expect(instance1 is TestClass, true);
  });
  test('GenericType test', () {
    GetIt.I.registerSingleton<TestBaseClassGeneric<TestBaseClass>>(
        TestClassGeneric<TestBaseClass>());

    final instance1 = GetIt.I.get<TestBaseClassGeneric<TestBaseClass>>();

    expect(instance1 is TestClassGeneric<TestBaseClass>, true);
  });

  test('register LazySingleton with lambda and factory function', () {
    GetIt.I.registerLazySingleton(() => SingletonInjector.configuration());

    final Injector instance = GetIt.I<Injector>();

    expect(instance, const TypeMatcher<Injector>());
  });
}

class SingletonInjector {
  static Injector configuration() {
    return Injector();
  }
}

class Injector {}
