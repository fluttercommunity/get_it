## [4.0.2] - 26.04.2020

* removed too strong type check for passed factory parameter
* fixed error message https://github.com/fluttercommunity/get_it/issues/69


## [4.0.1] - 19.03.2020

* overhauled readme
* removed unnecessary print statement

## [4.0.0] - 26.02.2020

* Added abstract `WillSignalReady` class

## [4.0.0-release-candidate] - 14.02.2020

* Breaking changes in API!!!
* Release candidate
* New Async functions
* Factories with parameters
* Improved startup synchronisation

## [3.0.2] - 23.10.2019

* Bugfix when using named instances

## [3.0.1] - 24.09.2019

* Bugfix with https://github.com/fluttercommunity/get_it/pull/21

## [3.0.0+1] - 07.09.2019

* Small fix to make the analyser happy

## [3.0.0] - 07.09.2019

* Overhauled the signalling API because the way it was was not optimal. Now you can either signal globally or by passing the instance of the registered object that shall signal. This way it's ensured that you have to have access to the instance to signal, typically from within the instance with a `GetIt.instance.signalReady(this)` 
individual signalling from other places but the instance itself is probably an error.
* Unregister of singletons /lazysingletons now possible also over a registered instance.
* Most asserts have bin replaced with throwing `Error`objects.
* The example now shows the ready signalling.

## [2.1.0] - 26.08.2019

* Added handy ready signal to make start-up logic a bit easier
* Unregister of Objects now possible with optional disposing function

## [2.0.3] - 26.08.2019

* Small fix

## [2.0.2] - 19.08.2019

* Small fix

## [2.0.1] - 19.08.2019

* Small fix

## [2.0.0] - 18.08.2019

* **Breaking Change with V2.0.0** 
you no longer can directly create instances of the type `GetIt` because `GetIt` is now a singleton please see [README](README.md)

## [1.1.0] - 18.08.2019

* added named registration

## [1.0.3+2] - 26.06.2019

* updated logo in readme

## [1.0.3+1] - 22.05.2019

* updated authors

## [1.0.3] - 01.03.2019

* Small fix so that intellisense works now if you use the short calling form without using `.get()` 

## [1.0.2] - 22.06.2018

* Moved package to [Flutter Community](https://github.com/fluttercommunity) 

## [1.0.1] - 20.06.2018

* Added `reset()`method 

## [1.0.0] - 22.05.2018

* Initial release 

