// ignore_for_file: unnecessary_type_check, unused_local_variable

import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

abstract class TestBaseClass {}

class TestClass extends TestBaseClass {
  final String? id;

  TestClass([this.id]) {
    constructorCounter++;
  }

  void dispose() {
    disposeCounter++;
  }
}

class TestClassShadowChangHandler extends TestBaseClass
    with ShadowChangeHandlers {
  final String? id;
  final void Function(bool isShadowed, Object shadowIngObject) onShadowChange;

  TestClassShadowChangHandler(this.onShadowChange, [this.id]) {
    constructorCounter++;
  }

  void dispose() {
    disposeCounter++;
  }

  @override
  void onGetShadowed(Object shadowing) {
    onShadowChange(true, shadowing);
  }

  @override
  void onLeaveShadow(Object shadowing) {
    onShadowChange(false, shadowing);
  }
}

class TestClass2 {
  final String? id;

  TestClass2([this.id]);

  void dispose() {
    disposeCounter++;
  }
}

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

  test('unregister constant that was registered in a lower scope', () {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));
    getIt.registerSingleton<TestClass2>(TestClass2('Basescope'));

    getIt.pushNewScope();

    getIt.registerSingleton<TestClass>(TestClass('2. scope'));

    final instance2 = getIt.get<TestClass2>();

    expect(instance2.id, 'Basescope');

    getIt.unregister<TestClass2>();

    expect(() => getIt.get<TestClass2>(), throwsA(isA<StateError>()));
  });

  test('register constant in two scopes', () {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));
    getIt.registerSingleton<TestClass2>(TestClass2('Basescope'));

    getIt.pushNewScope();

    getIt.registerSingleton<TestClass>(TestClass('2. scope'));

    final instance1 = getIt.get<TestClass>();

    expect(instance1 is TestClass, true);
    expect(instance1.id, '2. scope');

    final instance2 = getIt.get<TestClass2>();

    expect(instance2.id, 'Basescope');
  });

  test('register constant in two scopes with ShadowChangeHandlers', () async {
    final getIt = GetIt.instance;

    bool isShadowed = false;
    Object? shadowingObject;

    getIt.registerSingleton<TestClassShadowChangHandler>(
      TestClassShadowChangHandler(
        (shadowState, shadow) {
          isShadowed = shadowState;
          shadowingObject = shadow;
        },
        'Basescope',
      ),
    );

    getIt.pushNewScope();

    final testClassShadowChangHandlerInstance =
        TestClassShadowChangHandler((shadowState, shadow) {}, 'Scope 2');
    getIt.registerSingleton<TestClassShadowChangHandler>(
      testClassShadowChangHandlerInstance,
    );

    expect(isShadowed, true);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
    shadowingObject = null;

    await getIt.popScope();

    expect(isShadowed, false);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
  });

  test('register constant in two scopes with ShadowChangeHandlers', () async {
    final getIt = GetIt.instance;

    bool isShadowed = false;
    Object? shadowingObject;

    getIt.registerSingleton<TestClassShadowChangHandler>(
      TestClassShadowChangHandler(
        (shadowState, shadow) {
          isShadowed = shadowState;
          shadowingObject = shadow;
        },
        'Basescope',
      ),
    );

    getIt.pushNewScope();

    final testClassShadowChangHandlerInstance =
        TestClassShadowChangHandler((shadowState, shadow) {}, 'Scope 2');
    getIt.registerSingleton<TestClassShadowChangHandler>(
      testClassShadowChangHandlerInstance,
    );

    expect(isShadowed, true);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
    shadowingObject = null;

    await getIt.popScope();

    expect(isShadowed, false);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
  });
  test(
      'register lazySingleton in two scopes with ShadowChangeHandlers and scopeChangedHandler',
      () async {
    final getIt = GetIt.instance;

    int scopeChanged = 0;
    bool isShadowed = false;
    Object? shadowingObject;

    getIt.onScopeChanged = (pushed) => scopeChanged++;

    getIt.registerLazySingleton<TestBaseClass>(
      () => TestClassShadowChangHandler(
        (shadowState, shadow) {
          isShadowed = shadowState;
          shadowingObject = shadow;
        },
        'Basescope',
      ),
    );

    getIt.pushNewScope();

    var testClassShadowChangHandlerInstance =
        TestClassShadowChangHandler((shadowState, shadow) {}, 'Scope 2');
    getIt.registerSingleton<TestBaseClass>(
      testClassShadowChangHandlerInstance,
    );

    /// As we haven't used the singleton in the lower scope
    /// it never created an instance that could be shadowed
    expect(isShadowed, false);
    expect(shadowingObject, null);
    await getIt.popScope();

    final lazyInstance = getIt<TestBaseClass>();

    getIt.pushNewScope();
    testClassShadowChangHandlerInstance =
        TestClassShadowChangHandler((shadowState, shadow) {}, 'Scope 2');

    getIt.registerSingleton<TestBaseClass>(
      testClassShadowChangHandlerInstance,
    );

    expect(isShadowed, true);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
    shadowingObject = null;

    await getIt.popScope();

    expect(isShadowed, false);
    expect(shadowingObject, testClassShadowChangHandlerInstance);
    expect(scopeChanged, 4);
  });

  test('register AsyncSingleton in two scopes with ShadowChangeHandlers',
      () async {
    final getIt = GetIt.instance;

    bool isShadowed = false;
    Object? shadowingObject;

    getIt.registerSingleton<TestBaseClass>(
      TestClassShadowChangHandler(
        (shadowState, shadow) {
          isShadowed = shadowState;
          shadowingObject = shadow;
        },
        'Basescope',
      ),
    );

    getIt.pushNewScope();

    TestBaseClass? shadowingInstance;
    getIt.registerSingletonAsync<TestBaseClass>(
      () async {
        await Future.delayed(const Duration(milliseconds: 100));
        final newInstance =
            TestClassShadowChangHandler((shadowState, shadow) {}, '2, Scope');
        shadowingInstance = newInstance;
        return newInstance;
      },
    );

    /// The instance is not created yet because the async init function hasn't completed
    expect(isShadowed, false);
    expect(shadowingObject, null);

    /// wait for the singleton so be created

    final asyncInstance = await getIt.getAsync<TestBaseClass>();

    expect(isShadowed, true);
    expect(shadowingObject, shadowingInstance);
    shadowingObject = null;

    await getIt.popScope();

    expect(isShadowed, false);
    expect(shadowingObject, shadowingInstance);
  });

  test(
      'register SingletonWidthDependies in two scopes with ShadowChangeHandlers',
      () async {
    final getIt = GetIt.instance;

    bool isShadowed = false;
    Object? shadowingObject;

    getIt.registerSingletonAsync<TestClass>(
      () async {
        await Future.delayed(const Duration(milliseconds: 100));
        final newInstance = TestClass('Basescope');
        return newInstance;
      },
    );
    getIt.registerSingleton<TestBaseClass>(
      TestClassShadowChangHandler(
        (shadowState, shadow) {
          isShadowed = shadowState;
          shadowingObject = shadow;
        },
        '2, Scope',
      ),
    );

    getIt.pushNewScope();

    Object? shadowingInstance;
    getIt.registerSingletonWithDependencies<TestBaseClass>(
      () {
        final newInstance =
            TestClassShadowChangHandler((shadowState, shadow) {}, '2, Scope');
        shadowingInstance = newInstance;
        return newInstance;
      },
      dependsOn: [TestClass],
    );

    /// The instance is not created yet because the async init function hasn't completed
    expect(isShadowed, false);
    expect(shadowingObject, null);

    await getIt.allReady();

    expect(isShadowed, true);
    expect(shadowingObject, shadowingInstance);
    shadowingObject = null;

    await getIt.popScope();

    expect(isShadowed, false);
    expect(shadowingObject, shadowingInstance);
  });
  test('popscope', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));

    getIt.pushNewScope();

    getIt.registerSingleton<TestClass>(TestClass('2. scope'));
    getIt.registerSingleton<TestClass2>(TestClass2('2. scope'));

    final instanceTestClassScope2 = getIt.get<TestClass>();

    expect(instanceTestClassScope2 is TestClass, true);
    expect(instanceTestClassScope2.id, '2. scope');

    final instanceTestClass2Scope2 = getIt.get<TestClass2>();

    expect(instanceTestClass2Scope2 is TestClass2, true);
    expect(instanceTestClass2Scope2.id, '2. scope');

    await getIt.popScope();

    final instanceTestClassScope1 = getIt.get<TestClass>();

    expect(instanceTestClassScope1.id, 'Basescope');
    expect(
      () => getIt.get<TestClass2>(),
      throwsA(const TypeMatcher<StateError>()),
    );
  });

  test('popscopeuntil inclusive=true', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));

    getIt.pushNewScope(scopeName: 'Level1');

    getIt.registerSingleton<TestClass>(TestClass('2. scope'));

    getIt.pushNewScope(scopeName: 'Level2');

    getIt.registerSingleton<TestClass>(TestClass('3. scope'));

    final instanceTestClassScope3 = getIt.get<TestClass>();

    expect(instanceTestClassScope3.id, '3. scope');

    await getIt.popScopesTill('Level1');

    final instanceTestClassScope1 = getIt.get<TestClass>();

    expect(instanceTestClassScope1.id, 'Basescope');
    expect(
      () => getIt.get<TestClass2>(),
      throwsA(const TypeMatcher<StateError>()),
    );
  });
  test('popscopeuntil inclusive=false', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));

    getIt.pushNewScope(scopeName: 'Level1');

    getIt.registerSingleton<TestClass>(TestClass('2. scope'));

    getIt.pushNewScope(scopeName: 'Level2');

    getIt.registerSingleton<TestClass>(TestClass('3. scope'));

    final instanceTestClassScope3 = getIt.get<TestClass>();

    expect(instanceTestClassScope3.id, '3. scope');

    await getIt.popScopesTill('Level1', inclusive: false);

    final instanceTestClassScope1 = getIt.get<TestClass>();

    expect(instanceTestClassScope1.id, '2. scope');
    expect(
      () => getIt.get<TestClass2>(),
      throwsA(const TypeMatcher<StateError>()),
    );
  });

  test('popscope with destructors', () async {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(
      TestClass('Basescope'),
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(
      dispose: () {
        return disposeCounter++;
      },
    );

    getIt.registerSingleton<TestClass>(
      TestClass('2. scope'),
      dispose: (x) => x.dispose(),
    );
    getIt.registerSingleton<TestClass2>(
      TestClass2('2. scope'),
      dispose: (x) => x.dispose(),
    );

    await getIt.popScope();

    expect(disposeCounter, 3);
  });
  test('popscope with destructors', () async {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(
      TestClass('Basescope'),
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(
      dispose: () {
        return disposeCounter++;
      },
    );

    getIt.registerSingleton<TestClass>(
      TestClass('2. scope'),
      dispose: (x) => x.dispose(),
    );
    getIt.registerSingleton<TestClass2>(
      TestClass2('2. scope'),
      dispose: (x) => x.dispose(),
    );

    await getIt.popScope();

    expect(disposeCounter, 3);
  });

  test('popscope throws if already on the base scope', () async {
    final getIt = GetIt.instance;

    expect(() => getIt.popScope(), throwsA(const TypeMatcher<StateError>()));
  });

  test('dropScope', () async {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'));

    getIt.pushNewScope(scopeName: 'scope2');
    getIt.registerSingleton<TestClass>(TestClass('2. scope'));
    getIt.registerSingleton<TestClass2>(TestClass2('2. scope'));

    getIt.pushNewScope();
    getIt.registerSingleton<TestClass3>(TestClass3());

    final instanceTestClassScope2 = getIt.get<TestClass>();

    expect(instanceTestClassScope2 is TestClass, true);
    expect(instanceTestClassScope2.id, '2. scope');

    await getIt.dropScope('scope2');

    final instanceTestClassScope1 = getIt.get<TestClass>();

    expect(instanceTestClassScope1.id, 'Basescope');
    expect(
      () => getIt.get<TestClass2>(),
      throwsA(const TypeMatcher<StateError>()),
    );

    final instanceTestClass3Scope3 = getIt.get<TestClass3>();
    expect(instanceTestClass3Scope3 is TestClass3, true);
  });

  test('dropScope throws if scope with name not found', () async {
    final getIt = GetIt.instance;

    getIt.pushNewScope(scopeName: 'scope2');
    await expectLater(
      () => getIt.dropScope('scope'),
      throwsA(const TypeMatcher<ArgumentError>()),
    );
  });

  test('resetScope', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope0',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope1',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope2',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );

    await getIt.resetScope();

    expect(getIt<TestClass>(instanceName: 'scope0'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope1'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope2'), isNotNull);
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope3'),
      throwsA(const TypeMatcher<StateError>()),
    );

    expect(disposeCounter, 2);

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });

  test('resetScope no dispose', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope0',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope1',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope2',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );

    await getIt.resetScope(dispose: false);

    expect(getIt<TestClass>(instanceName: 'scope0'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope1'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope2'), isNotNull);
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope3'),
      throwsA(const TypeMatcher<StateError>()),
    );

    expect(disposeCounter, 0);

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });
  test('full reset', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope0',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope1',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope2',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );

    await getIt.reset();

    expect(
      () => getIt.get<TestClass>(instanceName: 'scope0'),
      throwsA(const TypeMatcher<StateError>()),
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope1'),
      throwsA(const TypeMatcher<StateError>()),
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope2'),
      throwsA(const TypeMatcher<StateError>()),
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope3'),
      throwsA(const TypeMatcher<StateError>()),
    );

    expect(disposeCounter, 7);

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });

  test(
    'has registered scope test',
    () async {
      final getIt = GetIt.instance;
      getIt.pushNewScope(scopeName: 'scope1');
      getIt.pushNewScope(scopeName: 'scope2');
      getIt.pushNewScope(scopeName: 'scope3');

      expect(getIt.hasScope('scope2'), isTrue);
      expect(getIt.hasScope('scope4'), isFalse);

      await getIt.dropScope('scope2');

      expect(getIt.hasScope('scope2'), isFalse);
    },
  );

  test('full reset no dispose', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope0',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope1',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope2',
      dispose: (x) => x.dispose(),
    );

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );

    await getIt.reset(dispose: false);

    expect(
      () => getIt.get<TestClass>(instanceName: 'scope0'),
      throwsA(const TypeMatcher<StateError>()),
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope1'),
      throwsA(const TypeMatcher<StateError>()),
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope2'),
      throwsA(const TypeMatcher<StateError>()),
    );
    expect(
      () => getIt.get<TestClass>(instanceName: 'scope3'),
      throwsA(const TypeMatcher<StateError>()),
    );

    expect(disposeCounter, 0);

    getIt.registerSingleton<TestClass>(
      TestClass(),
      instanceName: 'scope3',
      dispose: (x) => x.dispose(),
    );
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });
}
