import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

/// A simple 1-type-parameter generic class
class GenericOne<T> {
  final T value;

  GenericOne(this.value);

  @override
  String toString() => 'GenericOne<$T>($value)';
}

/// A more complex 2-type-parameter generic class
class GenericTwo<A, B> {
  final A first;
  final B second;

  GenericTwo(this.first, this.second);

  @override
  String toString() => 'GenericTwo<$A, $B>($first, $second)';
}

void main() {
  final getIt = GetIt.asNewInstance();

  setUp(() async {
    // Reset the test locator before each test so we start fresh
    await getIt.reset();
  });

  group('Generic Registration Tests', () {
    test(
        'Register two distinct single-type generics with different type params',
        () {
      // 1) Register a factory for GenericOne<int>
      getIt.registerFactory<GenericOne<int>>(
        () => GenericOne<int>(42),
      );

      // 2) Register another factory for GenericOne<String>
      getIt.registerFactory<GenericOne<String>>(
        () => GenericOne<String>('hello'),
      );

      // Now retrieve them:
      final genericInt = getIt<GenericOne<int>>();
      final genericString = getIt<GenericOne<String>>();

      // Check that they are not the same object, obviously
      expect(genericInt, isNot(genericString));

      // Confirm the correct values:
      expect(genericInt.value, 42);
      expect(genericString.value, 'hello');
    });

    test('Register multiple-parameter generic with different type combos', () {
      // 1) Register a GenericTwo<int, String>
      getIt.registerFactory<GenericTwo<int, String>>(
        () => GenericTwo<int, String>(99, 'apples'),
      );

      // 2) Register a GenericTwo<int, bool>
      getIt.registerFactory<GenericTwo<int, bool>>(
        () => GenericTwo<int, bool>(7, true),
      );

      // 3) Register a GenericTwo<String, String>
      getIt.registerFactory<GenericTwo<String, String>>(
        () => GenericTwo<String, String>('X', 'Y'),
      );

      // Retrieve them:
      final combo1 = getIt<GenericTwo<int, String>>();
      final combo2 = getIt<GenericTwo<int, bool>>();
      final combo3 = getIt<GenericTwo<String, String>>();

      expect(combo1.first, 99);
      expect(combo1.second, 'apples');

      expect(combo2.first, 7);
      expect(combo2.second, true);

      expect(combo3.first, 'X');
      expect(combo3.second, 'Y');

      // They are all distinct
      expect(combo1, isNot(combo2));
      expect(combo2, isNot(combo3));
      expect(combo1, isNot(combo3));
    });

    test(
        'Using getAll with multiple generic registrations of the same base type',
        () {
      // Register multiple GenericOne with different type params
      getIt
        ..registerFactory<GenericOne<int>>(() => GenericOne<int>(123))
        ..registerFactory<GenericOne<double>>(() => GenericOne<double>(3.14))
        ..registerFactory<GenericOne<String>>(() => GenericOne<String>('ABC'));

      // getAll<GenericOne<int>>() => Should return a single-element iterable with the int version
      final allInts = getIt.getAll<GenericOne<int>>();
      expect(allInts.length, 1);
      expect(allInts.first.value, 123);

      // getAll<GenericOne<String>>() => the string version
      final allStrings = getIt.getAll<GenericOne<String>>();
      expect(allStrings.length, 1);
      expect(allStrings.first.value, 'ABC');

      // Similarly for double
      final allDoubles = getIt.getAll<GenericOne<double>>();
      expect(allDoubles.length, 1);
      expect(allDoubles.first.value, 3.14);

      // If we do getAll<GenericOne<Object>>() => might return nothing or
      // might not match these specifically (depends on your exact get_it usage).
      // That’s fine; we do a quick check:
      final allObjects = getIt.getAll<GenericOne<Object>>();
      expect(
        allObjects,
        isEmpty,
        reason: 'GenericOne<Object> was never registered',
      );
    });

    test('FactoryParam usage with a two-parameter generic class', () {
      // Example: register a factory param for GenericTwo<A, B> that uses param1, param2 as constructor inputs
      getIt.registerFactoryParam<GenericTwo<String, bool>, String, bool>(
        (p1, p2) => GenericTwo<String, bool>(p1, p2),
      );

      // Now we can call getIt<GenericTwo<String, bool>>(param1: ..., param2: ...)
      final instance1 =
          getIt<GenericTwo<String, bool>>(param1: 'Hello', param2: true);
      final instance2 =
          getIt<GenericTwo<String, bool>>(param1: 'World', param2: false);

      expect(instance1.first, 'Hello');
      expect(instance1.second, true);

      expect(instance2.first, 'World');
      expect(instance2.second, false);

      // Distinct results each time because it's a factory
      expect(instance1, isNot(instance2));
    });
  });
}
