import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

class WillSignalClass implements WillSignalReady {}

class PlainClass {}

void main() {
  group('Auto signalsReady for classes implementing WillSignalReady', () {
    setUp(() async {
      // Before each test, reset GetIt
      await GetIt.I.reset();
    });

    test(
        'Immediate instance that implements WillSignalReady => auto signalsReady',
        () async {
      final getIt = GetIt.instance;

      // Register an existing instance that implements WillSignalReady,
      // but explicitly pass signalsReady == false:
      final instance = WillSignalClass();
      getIt.registerSingleton<WillSignalClass>(
        instance,
        signalsReady: false, // user sets false
      );

      // Check isReadySync => should STILL be recognized as signalReady
      // because the type implements WillSignalReady => forced to true
      expect(
        getIt.isReadySync<WillSignalClass>(),
        false,
        reason:
            'Because it is not signaled yet, but recognized as "can be signaled"',
      );

      // Now we manually call signalReady
      getIt.signalReady(instance);

      // After signalReady => isReadySync should be true
      expect(getIt.isReadySync<WillSignalClass>(), true);
    });

    test(
        'Factory registration for a type implementing WillSignalReady => auto signalsReady',
        () async {
      final getIt = GetIt.instance;

      // Register with a factory, no instance at registration time
      getIt.registerSingleton<WillSignalClass>(
        WillSignalClass(),
        signalsReady: false,
      );

      // By design, isReadySync should now check if it "can" be signaled
      // but since it hasn't been created or signaled, it should throw or say "not ready"
      // However, we confirm that it's recognized as canBeWaitedFor if we do isReady
      // or allReady. Usually you'd do getIt.getAsync or .allReady.

      // Force creation:
      final instance = getIt<WillSignalClass>();
      // isReadySync should be false (not signaled)
      expect(getIt.isReadySync<WillSignalClass>(), false);

      // Now let's signal once we have the instance
      getIt.signalReady(instance);

      expect(
        getIt.isReadySync<WillSignalClass>(),
        true,
        reason: 'After signalReady, it becomes ready',
      );
    });

    test(
        'If user passes signalsReady == true even for a non-WillSignalReady class => still signals',
        () async {
      final getIt = GetIt.instance;

      // PlainClass doesn't implement WillSignalReady
      final plain = PlainClass();
      getIt.registerSingleton<PlainClass>(
        plain,
        signalsReady: true, // user explicitly sets true
      );

      // isReadySync => false initially (not signaled yet, but can be signaled)
      expect(getIt.isReadySync<PlainClass>(), false);

      // Manually signal
      getIt.signalReady(plain);

      // Now isReadySync => true
      expect(getIt.isReadySync<PlainClass>(), true);
    });

    test(
        'If user passes signalsReady == false for a class that does NOT implement WillSignalReady => it stays false',
        () async {
      final getIt = GetIt.instance;

      getIt.registerSingleton<PlainClass>(
        PlainClass(),
        signalsReady: false,
      );

      // Because there's no auto detection (class is not WillSignalReady)
      // and signalsReady is false, we can't even do isReadySync(...) =>
      // it will throw or say "You only can use this function on async Singletons or Singletons marked signalsReady"
      //
      // Typically you test by calling isReady or isReadySync and expecting an ArgumentError or something
      // depending on your library code. For example:
      expect(
        () => getIt.isReadySync<PlainClass>(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'If user passes signalsReady == false but instance implements WillSignalReady => forced to true',
        () async {
      final getIt = GetIt.instance;

      final willSignal = WillSignalClass();
      getIt.registerSingleton<WillSignalClass>(
        willSignal,
        signalsReady: false, // user says false
      );

      // Under auto-detect logic, the code sees "willSignal is WillSignalReady"
      // => effectively forced signalsReady = true internally
      // => isReadySync doesn't throw, but it's not signaled yet
      expect(getIt.isReadySync<WillSignalClass>(), false);

      // Then we signal
      getIt.signalReady(willSignal);

      // Should now be recognized as ready
      expect(getIt.isReadySync<WillSignalClass>(), true);
    });
  });
}
