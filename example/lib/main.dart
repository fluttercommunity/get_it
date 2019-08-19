import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:get_it_example/app_model.dart';


// This is our global ServiceLocator
GetIt getIt = new GetIt.asNewInstance();

void main() {

  getIt.registerSingleton<AppModel>(new AppModelImplementation());

  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(

        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  initState()
  {
    // Access the instance of the registered AppModel
    getIt<AppModel>().addListener(update); 
    // Alternative
    // getIt.get<AppModel>().addListener(update); 
    
    super.initState();
  }

  @override
  void dispose() {
      getIt<AppModel>().removeListener(update); 
      super.dispose();
    }

  update()=> setState(()=>{});

  @override
  Widget build(BuildContext context) {

    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title),
      ),
      body: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Text(
              'You have pushed the button this many times:',
            ),
            new Text(
              '${getIt<AppModel>().counter}',
              style: Theme.of(context).textTheme.display1,
            ),
          ],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: getIt<AppModel>().incrementCounter,
        tooltip: 'Increment',
        child: new Icon(Icons.add),
      ),
    );
  }
}
