import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

void main() {
  test(' Throws ArgumentError ', () async {
    final getIt = GetIt.instance;
    getIt.allowReassignment = false;
    getIt.skipDoubleRegistration = false;
    getIt.reset();
    getIt.registerSingleton<DataStore>(MockDataStore());

    expect(
      () => getIt.registerSingleton<DataStore>(RemoteDataStore()),
      throwsArgumentError,
    );
  });

  test(' replaces dependency safely ', () async {
    final getIt = GetIt.instance;
    getIt.reset();
    getIt.allowReassignment = true;
    getIt.skipDoubleRegistration = false;
    getIt.registerSingleton<DataStore>(MockDataStore());
    getIt.registerSingleton<DataStore>(RemoteDataStore());

    expect(getIt<DataStore>(), isA<RemoteDataStore>());
  });

  test(' Ignores Double registration error ', () async {
    final getIt = GetIt.instance;
    getIt.reset();
    getIt.allowReassignment = false;
    getIt.skipDoubleRegistration = true;
    getIt.registerSingleton<DataStore>(MockDataStore());
    final remoteDataStore = RemoteDataStore();
    getIt.registerSingleton<DataStore>(remoteDataStore);

    expect(getIt<DataStore>(), isA<MockDataStore>());
  });

  test(' does not care about [skipDoubleRegistration] varibale   ', () async {
    final getIt = GetIt.instance;
    getIt.reset();
    getIt.allowReassignment = true;
    getIt.skipDoubleRegistration = true;
    getIt.registerSingleton<DataStore>(MockDataStore());
    getIt.registerSingleton<DataStore>(RemoteDataStore());

    expect(getIt<DataStore>(), isA<RemoteDataStore>());
  });
}

abstract class DataStore {}

class RemoteDataStore implements DataStore {}

class MockDataStore implements DataStore {}
