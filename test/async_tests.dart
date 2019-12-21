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

  test('signalReady with not ready registered objects', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      (completer) => TestClass(internalCompletion: true, completer: completer),
    );
    getIt.registerSingletonAsync<TestClass>((_) => TestClass(internalCompletion: false));
    getIt.registerSingletonAsync<TestClass2>((_) => TestClass2(internalCompletion: false));
    getIt.registerSingletonAsync<TestClass3>((_) => TestClass3(internalCompletion: true));

    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt<TestClass2>();
    var instance3 = getIt<TestClass3>();
    var instance4 = getIt('TestNamesInstance');

    expect(() => getIt.signalReady(), throwsA(TypeMatcher<StateError>()));
  });

  test('ready with internal signalling', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerLazySingletonAsync<TestClass>(
      (completer) => TestClass(internalCompletion: true, completer: null),
    );
    getIt.registerLazySingletonAsync<TestClass2>(
      (completer) => TestClass(internalCompletion: true, completer: completer),
    );
    getIt.registerLazySingleton<TestClass3>(
      () => TestClass3(internalCompletion: false),
    );
    getIt.registerLazySingletonAsync(
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
        var instance = TestClass(internalCompletion: false, completer: completer);
        await instance.init();
        completer.complete();
        return instance;
      },
    );
    getIt.registerLazySingletonAsync<TestClass2>(
      (completer) async{
        var instance = TestClass2(internalCompletion: false, completer: completer);
        await instance.init();
        completer.complete();
        return instance;
      },
    );

    // make sure that all constructors are run
    var instance1 = getIt<TestClass>();
    var instance2 = getIt<TestClass2>();
    var instance3 = getIt<TestClass3>();
    var instance4 = getIt('TestNamesInstance');

    expect(getIt.allReady, completes);
    expect(errorCounter, 0);
  });

  test('ready automatic signalling', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerLazySingletonAsync<TestClass>(
      (completer) async => TestClass(internalCompletion: false, completer: completer),
    );
    getIt.registerLazySingletonAsync<TestClass2>(
      (completer) async => TestClass(internalCompletion: false, completer: completer),
    );
    getIt.registerLazySingletonAsync(
      (completer) async => TestClass(internalCompletion: false, completer: completer),
    );
    expect(getIt.allReady, completes);
    expect(errorCounter, 0);
  });


}
