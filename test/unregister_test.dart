import 'package:get_it/get_it.dart';
import 'package:test/test.dart';

class Service extends Object {}

class Service2 extends Service {}

void main() {
  test('Unregisters only instance with type  and keep named instance ', () {
    final locator = GetIt.asNewInstance();
    locator.reset();

    locator.registerLazySingleton<Service>(() => Service());
    locator.registerLazySingleton<Service>(() => Service2(), instanceName: '2');

    expect(locator<Service>(), isA<Service>());
    expect(locator<Service>(instanceName: '2'), isA<Service2>());

    locator.unregister<Service>();

    expect(() => locator<Service>(), throwsStateError);
    expect(locator<Service>(instanceName: '2'), isA<Service2>());
  });
}
