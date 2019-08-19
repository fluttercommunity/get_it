import 'package:test/test.dart';

import 'package:get_it/get_it.dart';

int constructorCounter;

abstract class TestBaseClass {}

class TestClass extends TestBaseClass {
  TestClass() {
    constructorCounter++;
  }
}

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
    GetIt.allowMultipleInstances=true;
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
    getIt.registerFactory(() => TestClass(), 'FactoryByName');

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

    getIt.registerSingleton(TestClass(), 'ConstantByName');

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
    getIt.registerLazySingleton(() => TestClass(), 'LazyByName');

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
}
