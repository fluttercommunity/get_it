import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'package:get_it/get_it.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

abstract class TestBaseClass {}

class TestClassParam {
  final String param1;
  final int param2;

  TestClassParam({this.param1, this.param2});
}

class TestClass extends TestBaseClass{
  GetIt getIt;

  /// if we do the initialisation from inside the constructor the init function has to signal GetIt
  /// that it has finished. For that we need to pass in the completer that we got from the factory call
  /// that we set up in the registration.
  TestClass({@required bool internalCompletion, this.getIt}) {
    constructorCounter++;
    if (internalCompletion) {
      assert(getIt != null);
      initWithSignal();
    }
  }

  /// This one signals after a delay
  Future initWithSignal() {
    return Future.delayed(Duration(milliseconds: 10))
        .then((_) => getIt.signalReady(this));
  }

  // We use this as dummy init that will return a future
  Future init() {
    return Future.delayed(Duration(milliseconds: 10));
  }

  dispose() {
    disposeCounter++;
  }
}

class TestClassWillSignalReady extends TestClass implements WillSignalReady{
  TestClassWillSignalReady({
    @required bool internalCompletion,
    GetIt getIt,
  }) : super(internalCompletion: internalCompletion, getIt: getIt) {}
}
class TestClassWillSignalReady2 extends TestClass implements WillSignalReady{
  TestClassWillSignalReady2({
    @required bool internalCompletion,
    GetIt getIt,
  }) : super(internalCompletion: internalCompletion, getIt: getIt) {}
}

class TestClass2 extends TestClass{
  TestClass2({
    @required bool internalCompletion,
    GetIt getIt,
  }) : super(internalCompletion: internalCompletion, getIt: getIt) {}
}

class TestClass3 extends TestClass {
  TestClass3({
    @required bool internalCompletion,
    GetIt getIt,
  }) : super(internalCompletion: internalCompletion, getIt: getIt) {}
}

class TestClass4 extends TestClass {
  TestClass4({
    @required bool internalCompletion,
    GetIt getIt,
  }) : super(internalCompletion: internalCompletion, getIt: getIt) {}
}

void main() {
  /// This is the most basic sync functionality. Not sure if we should keep it.
  test('manual ready future test', () async {
    var getIt = GetIt.instance;

    getIt
        .registerFactory<TestClass>(() => TestClass(internalCompletion: false));
    getIt.registerFactory<TestClass2>(
        () => TestClass2(internalCompletion: false));
    getIt.registerFactory<TestClass3>(
        () => TestClass3(internalCompletion: false));
    getIt.registerFactory(() => TestClass(internalCompletion: false),
        instanceName: 'TestNamesInstance');

    expect(getIt.allReady(), completes);

    getIt.signalReady(null);

    // make sure to allow future to complete
    await Future.delayed(Duration(seconds: 1));
  });

  test(
      'signalReady will throw if any async Singletons have not signaled completion',
      () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      () => Future.delayed(Duration(milliseconds: 1))
          .then((_) => TestClass(internalCompletion: false, getIt: getIt)),
    );
    getIt.registerSingletonAsync<TestClass2>(
      () => Future.delayed(Duration(milliseconds: 2))
          .then((_) => TestClass2(internalCompletion: false, getIt: getIt)),
    );
    getIt.registerSingletonAsync<TestClass3>(
      () => Future.delayed(Duration(milliseconds: 50))
          .then((_) => TestClass3(internalCompletion: false, getIt: getIt)),
    );

    /// this here should signal call [signalReady()] but doesn't do it.
    getIt.registerSingletonAsync(
      () => Future.delayed(Duration(milliseconds: 50))
          .then((_) => TestClass(internalCompletion: false, getIt: getIt)),
      instanceName: 'TestNamesInstance',
    );

    await Future.delayed(Duration(milliseconds: 20));

    expect(getIt.isReadySync<TestClass>(), true);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.isReadySync(instanceName: 'TestNamesInstance'), false);
    expect(getIt.allReadySync(), false);

    /// We call [signalReady] before the last has completed
    expect(() => getIt.signalReady(null), throwsA(TypeMatcher<StateError>()));
  });

  test(
      'signalReady will throw if any Singletons that has signalsReads==true '
      'have not signaled completion', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
        () => Future.delayed(Duration(milliseconds: 1))
            .then((_) => TestClass(internalCompletion: true, getIt: getIt)),
        signalsReady: true);
    getIt.registerSingletonAsync<TestClass2>(
      () => Future.delayed(Duration(milliseconds: 2))
          .then((_) => TestClass2(internalCompletion: false, getIt: getIt)),
    );
    getIt.registerSingleton<TestClass3>(
      TestClass3(internalCompletion: true, getIt: getIt),
      signalsReady: true,
    );

    /// this here should signal call [signalReady()] but doesn't do it.
    getIt.registerSingleton(TestClass(internalCompletion: false, getIt: getIt),
        instanceName: 'TestNamesInstance', signalsReady: true);

    await Future.delayed(Duration(milliseconds: 20));

    /// We call [signalReady] before the last has completed
    expect(() => getIt.signalReady(null), throwsA(TypeMatcher<StateError>()));
  });
  test('all ready ignoring pending async Singletons', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      () => Future.delayed(Duration(milliseconds: 100))
          .then((_) => TestClass(internalCompletion: false, getIt: getIt)),
    );
    getIt.registerSingletonAsync<TestClass2>(
      () => Future.delayed(Duration(milliseconds: 100))
          .then((_) => TestClass2(internalCompletion: false, getIt: getIt)),
    );
    getIt.registerSingleton<TestClass3>(
      TestClass3(internalCompletion: true, getIt: getIt),
      signalsReady: true,
    );

    await Future.delayed(Duration(milliseconds: 15));

    expect(
        getIt.allReady(
            timeout: Duration(milliseconds: 2),
            ignorePendingAsyncCreation: true),
        completes);

    await Future.delayed(Duration(milliseconds: 15));
  });

  test('Normal Singletons, ready with internal signalling setting signalsReady parameter', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    getIt.registerSingleton<TestClass>(
        TestClass(internalCompletion: true, getIt: getIt),
        signalsReady: true);
    getIt.registerSingleton<TestClass2>(
        TestClass2(internalCompletion: true, getIt: getIt),
        signalsReady: true);
    getIt.registerSingleton(TestClass2(internalCompletion: true, getIt: getIt),
        instanceName: 'Second Instance', signalsReady: true);

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync(instanceName: 'Second Instance'), false);

    final timer= Stopwatch()..start();
    await getIt.allReady(timeout: Duration(milliseconds: 20));
    expect(timer.elapsedMilliseconds, greaterThan(5));
  });

  test('Normal Singletons,ready with internal signalling relying on implementing WillSignalReady interface', () async {
    final getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;

    var b = TestClassWillSignalReady is WillSignalReady;

    getIt.registerSingleton<TestClassWillSignalReady>(
        TestClassWillSignalReady(internalCompletion: true, getIt: getIt),);
    getIt.registerSingleton<TestClassWillSignalReady2>(
        TestClassWillSignalReady2(internalCompletion: true, getIt: getIt),);
    getIt.registerSingleton(TestClass2(internalCompletion: true, getIt: getIt),
        instanceName: 'Second Instance',);

    expect(getIt.isReadySync<TestClassWillSignalReady>(), false);
    expect(getIt.isReadySync<TestClassWillSignalReady2>(), false);
    expect(getIt.isReadySync(instanceName: 'Second Instance'), false);


    final timer= Stopwatch()..start();
    await getIt.allReady(timeout: Duration(milliseconds: 20));
    expect(timer.elapsedMilliseconds, greaterThan(5));
  });


  test('ready external signalling', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingleton<TestClass>(
        TestClass(internalCompletion: false, getIt: getIt),
        signalsReady: true);
    getIt.registerSingleton<TestClass2>(
        TestClass2(internalCompletion: false, getIt: getIt),
        signalsReady: true);
    getIt.registerSingleton(TestClass2(internalCompletion: false, getIt: getIt),
        instanceName: 'Second Instance', signalsReady: true);

    expect(getIt.allReadySync(), false);
    // this are async calls fire and forget
    getIt<TestClass>().initWithSignal();
    getIt<TestClass2>().initWithSignal();
    TestClass2 instance = getIt<TestClass2>(instanceName: 'Second Instance');
    instance.initWithSignal();

    expect(getIt.allReady(), completes);
  });

  test('ready automatic signalling for async Singletons', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
      () async => TestClass(internalCompletion: false)..init(),
    );
    getIt.registerSingletonAsync<TestClass2>(
      () async {
        var instance = TestClass2(internalCompletion: false);
        await instance.init();
        return instance;
      },
    );
    getIt.registerSingletonAsync(
        () async => TestClass2(internalCompletion: false)..init(),
        instanceName: 'Second Instance');
    expect(getIt.allReady(), completes);
  });

  test('ready manual synchronisation of sequence', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;
    var flag1 = false;
    var flag2 = false;

    getIt.registerSingletonAsync<TestClass>(
      () async {
        var instance = TestClass(internalCompletion: false);
        while (!flag1) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass2>(
      () async {
        await getIt.isReady<TestClass>();
        var instance = TestClass2(internalCompletion: false);
        while (!flag2) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass3>(
      () async {
        await getIt.isReady<TestClass2>();
        var instance = TestClass3(internalCompletion: false);
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
    expect(getIt.allReadySync(), false);

    flag2 = true;

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReady<TestClass2>(), completes);
    expect(getIt.isReady<TestClass3>(), completes);
    expect(getIt.allReady(), completes);
  });

  test('ready automatic synchronisation of sequence', () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;
    var flag1 = false;

    getIt.registerSingletonAsync<TestClass>(
      () async {
        var instance = TestClass(internalCompletion: false);
        while (!flag1) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonWithDependencies<TestClass2>(() {
      return TestClass2(internalCompletion: false);
    }, dependsOn: [TestClass]);

    getIt.registerSingletonAsync<TestClass3>(() async {
      var instance = TestClass3(internalCompletion: false);
      await instance.init();
      return instance;
    }, dependsOn: [TestClass, TestClass2]);

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    flag1 = true;

    // give the factory function a chance to run
    await Future.delayed(Duration(microseconds: 1));

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReady<TestClass2>(), completes);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.allReadySync(), false);

    expect(getIt.isReady<TestClass>(timeout: Duration(seconds: 5)), completes);
    expect(
        getIt.isReady<TestClass2>(timeout: Duration(seconds: 10)), completes);
    expect(
        getIt.isReady<TestClass3>(timeout: Duration(seconds: 15)), completes);
    expect(getIt.allReady(timeout: Duration(seconds: 20)), completes);
  });

  test('ready automatic synchronisation of sequence with following getAsync',
      () async {
    var getIt = GetIt.instance;
    getIt.reset();
    errorCounter = 0;
    var flag1 = false;
    var flag2 = false;

    getIt.registerSingletonAsync<TestClass>(
      () async {
        var instance = TestClass(internalCompletion: false);
        while (!flag1) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        return instance;
      },
    );

    getIt.registerSingletonAsync<TestClass2>(() async {
      while (!flag2) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      var instance = TestClass2(internalCompletion: true, getIt: getIt);
      return instance;
    }, dependsOn: [TestClass], signalsReady: true);

    getIt.registerSingletonWithDependencies<TestClass3>(
        () => TestClass3(internalCompletion: false),
        dependsOn: [TestClass, TestClass2]);

    expect(getIt.isReadySync<TestClass>(), false);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);

    flag1 = true;

    // give the factory function a chance to run
    await Future.delayed(Duration(microseconds: 1));

    expect(getIt.isReady<TestClass>(), completes);
    expect(getIt.isReadySync<TestClass2>(), false);
    expect(getIt.isReadySync<TestClass3>(), false);
    expect(getIt.allReadySync(), false);

    flag2 = true;

    expect(getIt.isReady<TestClass>(timeout: Duration(seconds: 5)), completes);
    expect(
        getIt.isReady<TestClass2>(timeout: Duration(seconds: 10)), completes);

    var instance = await getIt.getAsync<TestClass3>();

    expect(instance, TypeMatcher<TestClass3>());
  });

  test('allReady will throw after timeout', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerSingletonAsync<TestClass>(
        () async => TestClass(internalCompletion: false, getIt: getIt),
        signalsReady: true);
    getIt.registerSingletonAsync<TestClass>(
        () async => TestClass(
              internalCompletion: true,
              getIt: getIt,
            ),
        instanceName: "Second instance",
        signalsReady: true);
    getIt.registerSingletonAsync<TestClass2>(
        () async => TestClass2(internalCompletion: false)..init(),
        dependsOn: [TestClass]);
    // this here should signal internally but doesn't do it.
    getIt.registerSingletonAsync<TestClass3>(
        () async => TestClass3(internalCompletion: false),
        signalsReady: true);
    getIt.registerSingletonAsync<TestClass4>(
      () async => TestClass4(internalCompletion: false),
    );

    Future.delayed((Duration(milliseconds: 1)),
        () async => await getIt.isReady<TestClass3>(callee: 'asyncTest'));

    try {
      await getIt.allReady(timeout: Duration(seconds: 1));
    } catch (ex) {
      expect(ex, TypeMatcher<WaitingTimeOutException>());
      var timeOut = ex as WaitingTimeOutException;
      expect(timeOut.notReadyYet.contains('TestClass'), true);
      expect(timeOut.notReadyYet.contains('TestClass2'), true);
      expect(timeOut.notReadyYet.contains('TestClass3'), true);
      expect(timeOut.areReady.contains('TestClass4'), true);
      expect(timeOut.areWaitedBy['TestClass'].contains('TestClass2'), true);
      expect(timeOut.areWaitedBy['TestClass3'].contains('String'), true);
    }
  });

  test('asyncFactory called with getAsync', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerFactoryAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    var instance = await getIt.getAsync<TestClass>();
    expect(instance, TypeMatcher<TestClass>());
  });

  test('register factory with one Param', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    constructorCounter = 0;
    getIt.registerFactoryParamAsync<TestClassParam, String, void>((s, _) async {
      await Future.delayed(Duration(milliseconds: 1));
      return TestClassParam(param1: s);
    });

    //var instance1 = getIt.get<TestBaseClass>();

    var instance1 = await getIt.getAsync<TestClassParam>(param1: 'abc');
    var instance2 = await getIt.getAsync<TestClassParam>(param1: '123');

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, '123');
  });

  test('register factory with two Params', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    constructorCounter = 0;
    getIt.registerFactoryParamAsync<TestClassParam, String, int>((s, i) async {
      await Future.delayed(Duration(milliseconds: 1));
      return TestClassParam(param1: s, param2: i);
    });

    //var instance1 = getIt.get<TestBaseClass>();

    var instance1 =
        await getIt.getAsync<TestClassParam>(param1: 'abc', param2: 3);
    var instance2 =
        await getIt.getAsync<TestClassParam>(param1: '123', param2: 5);

    expect(instance1 is TestClassParam, true);
    expect(instance1.param1, 'abc');
    expect(instance1.param2, 3);
    expect(instance2 is TestClassParam, true);
    expect(instance2.param1, '123');
    expect(instance2.param2, 5);
  });

  test('register factory with Params with wrong type', () {
    var getIt = GetIt.instance;
    getIt.reset();

    constructorCounter = 0;
    getIt.registerFactoryParamAsync<TestClassParam, String, int>(
        (s, i) async => TestClassParam(param1: s, param2: i));

    //var instance1 = getIt.get<TestBaseClass>();

    expect(() => getIt.getAsync<TestClassParam>(param1: 'abc', param2: '3'),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test('asyncFactory called with get instead of getAsync', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerFactoryAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    expect(
        () => getIt.get<TestClass>(), throwsA(TypeMatcher<AssertionError>()));
  });

  test('asyncLazySingleton called with get before it was ready', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    await Future.delayed(Duration(microseconds: 1));
    expect(
        () => getIt.get<TestClass>(), throwsA(TypeMatcher<AssertionError>()));
  });

  test('asyncLazySingleton called with getAsync', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)..init()),
    );

    var instance = await getIt.getAsync<TestClass>();
    expect(instance, TypeMatcher<TestClass>());
  });

  test('asyncLazySingleton called with get after wait for ready', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    var instance = await getIt.getAsync<TestClass>();

    await getIt.isReady<TestClass>(timeout: Duration(milliseconds: 20));

    instance = getIt.get<TestClass>();
    expect(instance, TypeMatcher<TestClass>());
  });

  test('isReady called on asyncLazySingleton ', () async {
    var getIt = GetIt.instance;
    getIt.reset();

    getIt.registerLazySingletonAsync<TestClass>(
      () => Future.value(TestClass(internalCompletion: false)),
    );

    await getIt.isReady<TestClass>(timeout: Duration(milliseconds: 20));

    final instance = getIt.get<TestClass>();
    expect(instance, TypeMatcher<TestClass>());
  });

  test('Code for ReadMe', () async {
    var sl = GetIt.instance;

    sl.registerSingletonAsync<Service1>(() async {
      var instance = Service1Implementation();
      await instance.init();
      return instance;
    });
  });
}

abstract class Service1 {}

abstract class Service2 {}

class Service1Implementation implements Service1 {
  Future init() {
    // dummy async call
    return Future.delayed(Duration(microseconds: 1));
  }
}

class Service2Implementation implements Service2 {
  Service2() {
    _init(); // we call _init here without awaiting it.
  }

  Future _init() async {
    // dummy async call
    await Future.delayed(Duration(microseconds: 1));
    // From here on we are ready
  }
}
