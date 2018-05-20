import 'package:test/test.dart';

import 'package:get_it/get_it.dart';

int constructorCounter;

class TestClass
{
    int value = 42;

    TestClass()
    {
        constructorCounter++;
    }
}

void main() {

  test('register new', () {
    constructorCounter = 0;
    GetIt.register<TestClass>(()=> new TestClass());

    var instance1 = GetIt.get<TestClass>();

    expect(instance1 is TestClass, true) ;

    var instance2 = GetIt.get<TestClass>();

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

  });

  test('register constant', () {
    constructorCounter = 0;
    GetIt.registerConstant<TestClass>(new TestClass());

    var instance1 = GetIt.get<TestClass>();

    expect(instance1 is TestClass, true) ;

    var instance2 = GetIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);
  });



  test('register lazySingleton', () {
    constructorCounter = 0;
    GetIt.registerLazySingleton<TestClass>(()=>new TestClass());

    expect(constructorCounter, 0);

    var instance1 = GetIt.get<TestClass>();

    expect(instance1 is TestClass, true) ;
    expect(constructorCounter, 1);

    var instance2 = GetIt.get<TestClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);
  });


  test('trying to access not registered type', () {

      expect(()=>GetIt.get<int>(), throwsA(new isInstanceOf<Exception>()));
  });



}
