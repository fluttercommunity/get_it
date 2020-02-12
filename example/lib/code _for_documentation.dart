import 'package:get_it/get_it.dart';
import 'package:get_it_example/app_model.dart';

class AppModel {}

class AppModelImplmentation extends AppModel {
  AppModelImplmentation(initiData);
}

class AppModelMock extends AppModel {}

class DbService {}

GetIt getIt = GetIt.instance;

class UserManager {
  AppModel appModel;
  DbService dbService;

  UserManager({AppModel appModel, DbService dbService}) {
    this.appModel = appModel ?? getIt.get<AppModel>();
    this.dbService = dbService ?? getIt.get<DbService>();
  }
}

Future restCall()async{}

  void init() {
    bool testing;
    // ambient variable to access the service locator
    GetIt sl = GetIt.instance;

    void setup() {
      sl.registerFactoryAsync<AppModel>(() async => AppModelImplmentation(await restCall()));

      sl.registerSingletonAsync<AppModel>(() async => AppModelImplmentation(await restCall()));

      sl.registerFactoryAsync<AppModel>(() async => AppModelImplmentation(await restCall()));

      // sl.registerFactory<AppModel>(() => AppModelImplmentation());

      // sl.registerSingleton<AppModel>(AppModelImplmentation());

      // sl.registerLazySingleton<AppModel>(() => AppModelImplmentation());

      if (testing) {
        sl.registerSingleton<AppModel>(AppModelMock());
      } else {
        sl.registerSingleton<AppModel>(AppModelImplmentation());
      }
    }
  }

// /// instead of
// MaterialButton(
//   child: Text("Update"),
//   onPressed: TheViewModel.of(context).update
//   ),

// /// do
// MaterialButton(
//   child: Text("Update"),
//   onPressed: sl.get<AppModel>().update
//   ),

// /// or even shorter
// MaterialButton(
//   child:  Text("Update"),
//   onPressed: sl.<AppModel>().update
//   ),

