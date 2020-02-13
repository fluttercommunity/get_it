
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

class TestClassParam{
  final String param1;
  final int param2;

  TestClassParam({this.param1, this.param2});
}

void main() {

  setUp((){
    //make sure the instance is cleared before each test
    GetIt.I.reset();
  });

  test('register factory', () {
    var getIt = GetIt.instance;
    getIt.reset();
    
    constructorCounter = 0;
    getIt.registerFactory<TestBaseClass>(() => TestClass());

    //var instance1 = getIt.get<TestBaseClass>();

    var instance1 = getIt<TestBaseClass>();

    expect(instance1 is TestClass, true);

    var instance2 = getIt.get<TestBaseClass>();

    expect(getIt.isRegistered<TestBaseClass>(), true);
    expect(getIt.isRegistered<TestClass2>(), false);
    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

  });

  test('register factory with one Param', () {
    var getIt = GetIt.instance;
    getIt.reset();

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam,String,void>((s,_) => TestClassParam(param1:s));

    //var instance1 = getIt.get<TestBaseClass>();

    var instance1 = getIt<TestClassParam>(param1: 'abc');
    var instance2 = getIt<TestClassParam>(param1: '123');

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1 , 'abc');
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1 , '123');
  });

  test('register factory with two Params', () {
    var getIt = GetIt.instance;
    getIt.reset();

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam,String,int>((s,i) => TestClassParam(param1:s, param2: i));

    //var instance1 = getIt.get<TestBaseClass>();

    var instance1 = getIt<TestClassParam>(param1: 'abc',param2:3);
    var instance2 = getIt<TestClassParam>(param1: '123', param2:5);

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1 , 'abc');
    expect(instance1.param2 , 3);
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1 , '123');
    expect(instance2.param2 , 5);
  });

  test('register factory with Params with wrong type', () {
    var getIt = GetIt.instance;
    getIt.reset();

    constructorCounter = 0;
    getIt.registerFactoryParam<TestClassParam,String,int>((s,i) => TestClassParam(param1:s, param2: i));


    expect(()=>getIt.get<TestClassParam>(param1: 'abc',param2:'3'), throwsA(const TypeMatcher<AssertionError>()));

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

    expect(() => getIt.get<int>(), throwsA(TypeMatcher<AssertionError>()));

    GetIt.I.reset();
  });

  test('register factory by Name', () {
    var getIt = GetIt.instance;

    constructorCounter = 0;
    getIt.registerFactory(() => TestClass(), instanceName: 'FactoryByName');

    var instance1 = getIt(instanceName:'FactoryByName');

    expect(instance1 is TestClass, true);

    var instance2 = getIt(instanceName:'FactoryByName');
    ;

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

    GetIt.I.reset();
  });

  test('register constant by name', () {
    var getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'ConstantByName');

    var instance1 = getIt(instanceName:'ConstantByName');

    expect(instance1 is TestClass, true);

    TestClass instance2 = getIt(instanceName:'ConstantByName');

    expect(instance1, instance2);

    expect(constructorCounter, 1);
    GetIt.I.reset();
  });

  test('register lazySingleton by name', () {
    var getIt = GetIt.instance;
    constructorCounter = 0;
    getIt.registerLazySingleton(() => TestClass(), instanceName: 'LazyByName');

    expect(constructorCounter, 0);

    var instance1 = getIt(instanceName:'LazyByName');

    expect(instance1 is TestClass, true);
    expect(constructorCounter, 1);

    var instance2 = getIt(instanceName:'LazyByName');

    expect(instance1, instance2);

    expect(constructorCounter, 1);
    GetIt.I.reset();
  });

  test('register lazy singleton two instances of GetIt', () {
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


  test('trying to access not registered type by name', () {
    var getIt = GetIt.instance;

    expect(() => getIt(instanceName:'not there'), throwsA(TypeMatcher<AssertionError>()));
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

    expect(() => getIt.get<TestClass>(), throwsA(TypeMatcher<AssertionError>()));
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

    expect(() => getIt.get<TestClass>(), throwsA(TypeMatcher<AssertionError>()));
  });

  test('unregister by name', () {
    var getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    var instance1 = getIt.get(instanceName:'instanceName');

    expect(instance1 is TestClass, true);

    getIt.unregister(
        instanceName: 'instanceName',
        disposingFunction: (testClass) {
          testClass.dispose();
        });

    expect(disposeCounter, 1);

    expect(() => getIt(instanceName:'instanceName'), throwsA(TypeMatcher<AssertionError>()));
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

    expect(() => getIt.get<TestClass>(), throwsA(TypeMatcher<AssertionError>()));
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

    expect(() => getIt.get<TestClass>(), throwsA(TypeMatcher<AssertionError>()));
  });

  test('unregister by name without disposing function', () {
    var getIt = GetIt.instance;
    disposeCounter = 0;
    constructorCounter = 0;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    var instance1 = getIt.get(instanceName:'instanceName');

    expect(instance1 is TestClass, true);

    getIt.unregister(instanceName: 'instanceName');

    expect(disposeCounter, 0);

    expect(() => getIt(instanceName:'instanceName'), throwsA(TypeMatcher<AssertionError>()));
  });

  test(
      'can register a singleton with instanceName and retrieve it with generic parameters and instanceName', () {
    final getIt = GetIt.instance;

    getIt.registerSingleton(TestClass(), instanceName: 'instanceName');

    var instance1 = getIt.get<TestClass>(instanceName:'instanceName');

    expect(instance1 is TestClass, true);
  });

}
