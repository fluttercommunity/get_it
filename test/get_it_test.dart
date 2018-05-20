import 'package:test/test.dart';

import 'package:get_it/get_it.dart';

int constructorCounter;

abstract class TestBaseClass
{

}

class TestClass extends TestBaseClass
{
    TestClass()
    {
        constructorCounter++;
    }
}

void main() {

  test('register new', () {
    GetIt.reset();
    
    constructorCounter = 0;
    GetIt.register<TestBaseClass>(()=> new TestClass());

    var instance1 = GetIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true) ;

    var instance2 = GetIt.get<TestBaseClass>();

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

  });

  test('register constant', () {
    GetIt.reset();
    constructorCounter = 0;

    GetIt.registerSingleton<TestBaseClass>(new TestClass());

    var instance1 = GetIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true) ;

    var instance2 = GetIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);
  });



  test('register lazySingleton', () {
    GetIt.reset();
    constructorCounter = 0;
    GetIt.registerLazySingleton<TestBaseClass>(()=>new TestClass());

    expect(constructorCounter, 0);

    var instance1 = GetIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true) ;
    expect(constructorCounter, 1);

    var instance2 = GetIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);
  });


  test('trying to access not registered type', () {

      expect(()=>GetIt.get<int>(), throwsA(new isInstanceOf<Exception>()));
  });



}
