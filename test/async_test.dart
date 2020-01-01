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

    getIt.registerFactory<TestClass>(() => TestClass(internalCompletion: false));
    getIt.registerFactory<TestClass2>(() => TestClass2(internalCompletion: false));
    getIt.registerFactory<TestClass3>(() => TestClass3(internalCompletion: false));
    getIt.registerFactory(() => TestClass(internalCompletion: false),
        instanceName: 'TestNamesInstance');

    expect(getIt.allReady, completes);

    getIt.signalReady();

    // make sure to allow the stream to emit an item
    await Future.delayed(Duration(seconds: 1));
  });

  test('signalReady will throw if any async Singletons have not signaled completion', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      (completer) => TestClass(internalCompletion: true, completer: completer),
    );
    getIt.registerSingletonAsync<TestClass>((_) => TestClass(internalCompletion: false)..init());
    getIt.registerSingletonAsync<TestClass2>((_) => TestClass2(internalCompletion: false)..init());
    // this here should signal internally but doesn't do it.
    getIt.registerSingletonAsync<TestClass3>((_) => TestClass3(internalCompletion: true));

    expect(() => getIt.signalReady(), throwsA(TypeMatcher<StateError>()));
  });

  test('ready with internal signalling', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerSingletonAsync<TestClass>(
      (completer) => TestClass(internalCompletion: true, completer: null),
    );
    getIt.registerSingletonAsync<TestClass2>(
      (completer) => TestClass(internalCompletion: true, completer: completer),
    );
    getIt.registerSingletonAsync(
      (completer) => TestClass(internalCompletion: true, completer: completer),
    );

    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt<TestClass2>();
    var instance3 = getIt<TestClass3>();
    var instance4 = getIt('TestNamesInstance');

    expect(getIt.allReady, completes);
    expect(errorCounter, 0);
  });


  test('ready external signalling', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerLazySingletonAsync<TestClass>(
      (completer) async{
        var instance = TestClass(internalCompletion: false, completer: null);
        await instance.init();
        completer.complete();
        return instance;
      },
    );
    getIt.registerLazySingletonAsync<TestClass2>(
      (completer) async{
        var instance = TestClass2(internalCompletion: false, completer: null);
        await instance.init();
        completer.complete();
        return instance;
      },instanceName: 'TestNamedInstance'
    );

    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt('TestNamedInstance');

    expect(getIt.allReady, completes);
    expect(errorCounter, 0);
  });

  test('ready automatic signalling', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerLazySingletonAsync<TestClass>(
      (completer) async => TestClass(internalCompletion: false)..init(),
    );
    getIt.registerLazySingletonAsync<TestClass2>(
      (completer) async => TestClass(internalCompletion: false)..init(),
    );
    getIt.registerLazySingletonAsync(
      (completer) async => TestClass(internalCompletion: false)..init(),
    );
    expect(getIt.allReady, completes);
    expect(errorCounter, 0);
  });

  test('ready manual synchronisation of sequence', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;
    var flag1 = false;
    var flag2 = false;

    getIt.registerSingletonAsync<TestClass>(
      (completer) async {
        var instance= TestClass(internalCompletion: false);
        while (!flag1)
        {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass2>(
      (completer) async {
        await getIt.isReady<TestClass>();
        var instance= TestClass2(internalCompletion: false);
        while (!flag2)
        {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass3>(
      (completer) async {
        await getIt.isReady<TestClass2>();
        var instance= TestClass3(internalCompletion: false);
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
    expect(getIt.allReadySync<TestClass3>(), false);

    flag2 = true;


    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReady<TestClass2>(), completes);
    expect(getIt.isReady<TestClass3>(), completes);
    expect(getIt.allReady, completes);
  });

  test('ready automatic synchronisation of sequence', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;
    var flag1 = false;
    var flag2 = false;

    getIt.registerSingletonAsync<TestClass>(
      (completer) async {
        var instance= TestClass(internalCompletion: false);
        while (!flag1)
        {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass2>(
      (completer) async {
        var instance= TestClass2(internalCompletion: false);
        while (!flag2)
        {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },dependsOn: [TestClass]
    );

    getIt.registerSingletonAsync<TestClass3>(
      (completer) async {
        var instance= TestClass3(internalCompletion: false);
        await instance.init();
        return instance;
      },dependsOn: [TestClass,TestClass2]
    );

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    flag1 = true;

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.allReadySync<TestClass3>(), false);

    flag2 = true;


    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReady<TestClass2>(), completes);
    expect(getIt.isReady<TestClass3>(), completes);
    expect(getIt.allReady, completes);
  });

}
