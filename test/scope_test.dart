import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

int constructorCounter = 0;
int disposeCounter = 0;
int errorCounter = 0;

abstract class TestBaseClass {}

class TestClass extends TestBaseClass {
  final String id;
  TestClass([this.id]) {
    constructorCounter++;
  }
  void dispose() {
    disposeCounter++;
  }
}

class TestClass2 {
  final String id;
  TestClass2([this.id]);
  void dispose() {
    disposeCounter++;
  }
}

class TestClass3 {}

class TestClass4 {}

class TestClassParam {
  final String param1;
  final int param2;

  TestClassParam({this.param1, this.param2});
}

void main() {
  setUp(() async {
    //make sure the instance is cleared before each test
    await GetIt.I.reset();
    constructorCounter = 0;
    disposeCounter = 0;
    errorCounter = 0;
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
    expect(() => getIt.get<TestClass2>(),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test('popscope with destructors', () async {
    final getIt = GetIt.instance;

    getIt.registerSingleton<TestClass>(TestClass('Basescope'),
        dispose: (x) => x.dispose());

    getIt.pushNewScope(dispose: () {
      return disposeCounter++;
    });

    getIt.registerSingleton<TestClass>(TestClass('2. scope'),
        dispose: (x) => x.dispose());
    getIt.registerSingleton<TestClass2>(TestClass2('2. scope'),
        dispose: (x) => x.dispose());

    await getIt.popScope();

    expect(disposeCounter, 3);
  });

  test('popscope until', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope0', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope1', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope2', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope3', dispose: (x) => x.dispose());

    expect(getIt<TestClass>(instanceName: 'scope0'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope1'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope2'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
    expect(() => getIt.get<TestClass>(),
        throwsA(const TypeMatcher<AssertionError>()));

    await getIt.popScopesTill('scope2');

    expect(getIt<TestClass>(instanceName: 'scope0'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope1'), isNotNull);
    expect(() => getIt.get<TestClass>(instanceName: 'scope2'),
        throwsA(const TypeMatcher<AssertionError>()));
    expect(() => getIt.get<TestClass>(instanceName: 'scope3'),
        throwsA(const TypeMatcher<AssertionError>()));

    expect(disposeCounter, 4);
  });

  test('resetScope', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope0', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope1', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope2', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope3', dispose: (x) => x.dispose());

    await getIt.resetScope();

    expect(getIt<TestClass>(instanceName: 'scope0'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope1'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope2'), isNotNull);
    expect(() => getIt.get<TestClass>(instanceName: 'scope3'),
        throwsA(const TypeMatcher<AssertionError>()));

    expect(disposeCounter, 2);

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope3', dispose: (x) => x.dispose());
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });

  test('resetScope no dispose', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope0', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope1', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope2', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope3', dispose: (x) => x.dispose());

    await getIt.resetScope(dispose: false);

    expect(getIt<TestClass>(instanceName: 'scope0'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope1'), isNotNull);
    expect(getIt<TestClass>(instanceName: 'scope2'), isNotNull);
    expect(() => getIt.get<TestClass>(instanceName: 'scope3'),
        throwsA(const TypeMatcher<AssertionError>()));

    expect(disposeCounter, 0);

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope3', dispose: (x) => x.dispose());
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });
  test('full reset', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope0', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope1', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope2', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope3', dispose: (x) => x.dispose());

    await getIt.reset();

    expect(() => getIt.get<TestClass>(instanceName: 'scope0'),
        throwsA(const TypeMatcher<AssertionError>()));
    expect(() => getIt.get<TestClass>(instanceName: 'scope1'),
        throwsA(const TypeMatcher<AssertionError>()));
    expect(() => getIt.get<TestClass>(instanceName: 'scope2'),
        throwsA(const TypeMatcher<AssertionError>()));
    expect(() => getIt.get<TestClass>(instanceName: 'scope3'),
        throwsA(const TypeMatcher<AssertionError>()));

    expect(disposeCounter, 7);

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope3', dispose: (x) => x.dispose());
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });

  test('full reset no dispose', () async {
    final getIt = GetIt.instance;
    constructorCounter = 0;

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope0', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope1', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope1', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope2', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope2', dispose: (x) => x.dispose());

    getIt.pushNewScope(scopeName: 'scope3', dispose: () => disposeCounter++);
    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope3', dispose: (x) => x.dispose());

    await getIt.reset(dispose: false);

    expect(() => getIt.get<TestClass>(instanceName: 'scope0'),
        throwsA(const TypeMatcher<AssertionError>()));
    expect(() => getIt.get<TestClass>(instanceName: 'scope1'),
        throwsA(const TypeMatcher<AssertionError>()));
    expect(() => getIt.get<TestClass>(instanceName: 'scope2'),
        throwsA(const TypeMatcher<AssertionError>()));
    expect(() => getIt.get<TestClass>(instanceName: 'scope3'),
        throwsA(const TypeMatcher<AssertionError>()));

    expect(disposeCounter, 0);

    getIt.registerSingleton<TestClass>(TestClass(),
        instanceName: 'scope3', dispose: (x) => x.dispose());
    expect(getIt<TestClass>(instanceName: 'scope3'), isNotNull);
  });
}
