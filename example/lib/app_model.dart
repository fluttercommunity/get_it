import 'dart:async';

import 'package:flutter/material.dart';

abstract class AppModel extends ChangeNotifier {
  void incrementCounter();

  int get counter;
}

class AppModelImplementation extends AppModel {
  int _counter = 0;

  AppModelImplementation(Completer completer) {
    /// lets pretend we have to do some async initilization
    Future.delayed(Duration(seconds: 3)).then((_) => completer.complete());
  }

  @override
  int get counter => _counter;

  @override
  void incrementCounter() {
    _counter++;
    notifyListeners();
  }
}
