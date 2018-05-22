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

    var getIt = new GetIt();
    
    constructorCounter = 0;
    getIt.registerFactory<TestBaseClass>(()=> new TestClass());

    //var instance1 = getIt.get<TestBaseClass>();

    var instance1 = getIt<TestBaseClass>();

    expect(instance1 is TestClass, true) ;

    var instance2 = getIt.get<TestBaseClass>();

    expect(instance1, isNot(instance2));

    expect(constructorCounter, 2);

  });

  test('register constant', () {
    var getIt = new GetIt();
    constructorCounter = 0;

    getIt.registerSingleton<TestBaseClass>(new TestClass());

    var instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true) ;

    var instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);
  });



  test('register lazySingleton', () {
    var getIt = new GetIt();
    constructorCounter = 0;
    getIt.registerLazySingleton<TestBaseClass>(()=>new TestClass());

    expect(constructorCounter, 0);

    var instance1 = getIt.get<TestBaseClass>();

    expect(instance1 is TestClass, true) ;
    expect(constructorCounter, 1);

    var instance2 = getIt.get<TestBaseClass>();

    expect(instance1, instance2);

    expect(constructorCounter, 1);
  });


  test('trying to access not registered type', () {
      var getIt = new GetIt();

      expect(()=>getIt.get<int>(), throwsA(new isInstanceOf<Exception>()));
  });



}
