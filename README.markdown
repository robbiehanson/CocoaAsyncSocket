# CocoaAsyncSocket
[![Build Status](https://travis-ci.org/robbiehanson/CocoaAsyncSocket.svg?branch=master)](https://travis-ci.org/robbiehanson/CocoaAsyncSocket) [![Version Status](https://img.shields.io/cocoapods/v/CocoaAsyncSocket.svg?style=flat)](http://cocoadocs.org/docsets/CocoaAsyncSocket) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![Platform](http://img.shields.io/cocoapods/p/CocoaAsyncSocket.svg?style=flat)](http://cocoapods.org/?q=CocoaAsyncSocket) [![license Public Domain](https://img.shields.io/badge/license-Public%20Domain-orange.svg?style=flat)](https://en.wikipedia.org/wiki/Public_domain)


CocoaAsyncSocket provides easy-to-use and powerful asynchronous socket libraries for Mac and iOS. The classes are described below.

## Installation

#### CocoaPods

Install using [CocoaPods](http://cocoapods.org) by adding this line to your Podfile:

````ruby
use_frameworks! # Add this if you are targeting iOS 8+ or using Swift
pod 'CocoaAsyncSocket'  
````

#### Carthage

CocoaAsyncSocket is [Carthage](https://github.com/Carthage/Carthage) compatible. To include it add the following line to your `Cartfile`

```bash
github "robbiehanson/CocoaAsyncSocket" "master"
```

The project is currently configured to build for **iOS**, **tvOS** and **Mac**.  After building with carthage the resultant frameworks will be stored in:

* `Carthage/Build/iOS/CocoaAsyncSocket.framework`
* `Carthage/Build/tvOS/CocoaAsyncSocket.framework`
* `Carthage/Build/Mac/CocoaAsyncSocket.framework`

Select the correct framework(s) and drag it into your project.

#### Manual

You can also include it into your project by adding the source files directly, but you should probably be using a dependency manager to keep up to date.

### Importing

Using Objective-C:

```obj-c
@import CocoaAsyncSocket; // When using iOS 8+ frameworks
// OR
#import "CocoaAsyncSocket.h" // When not using frameworks, targeting iOS 7 or below
```

Using Swift:

```swift
import CocoaAsyncSocket
```

## TCP

**GCDAsyncSocket** and **AsyncSocket** are TCP/IP socket networking libraries. Here are the key features available in both:

- Native objective-c, fully self-contained in one class.<br/>
  _No need to muck around with sockets or streams. This class handles everything for you._

- Full delegate support<br/>
  _Errors, connections, read completions, write completions, progress, and disconnections all result in a call to your delegate method._

- Queued non-blocking reads and writes, with optional timeouts.<br/>
  _You tell it what to read or write, and it handles everything for you. Queueing, buffering, and searching for termination sequences within the stream - all handled for you automatically._

- Automatic socket acceptance.<br/>
  _Spin up a server socket, tell it to accept connections, and it will call you with new instances of itself for each connection._

- Support for TCP streams over IPv4 and IPv6.<br/>
  _Automatically connect to IPv4 or IPv6 hosts. Automatically accept incoming connections over both IPv4 and IPv6 with a single instance of this class. No more worrying about multiple sockets._

- Support for TLS / SSL<br/>
  _Secure your socket with ease using just a single method call. Available for both client and server sockets._

**GCDAsyncSocket** is built atop Grand Central Dispatch:

- Fully GCD based and Thread-Safe<br/>
  _It runs entirely within its own GCD dispatch_queue, and is completely thread-safe. Further, the delegate methods are all invoked asynchronously onto a dispatch_queue of your choosing. This means parallel operation of your socket code, and your delegate/processing code._

- The Latest Technology & Performance Optimizations<br/>
  _Internally the library takes advantage of technologies such as [kqueue's](http://en.wikipedia.org/wiki/Kqueue) to limit [system calls](http://en.wikipedia.org/wiki/System_call) and optimize buffer allocations. In other words, peak performance._

**AsyncSocket** wraps CFSocket and CFStream:

- Fully Run-loop based<br/>
  _Use it on the main thread or a worker thread. It plugs into the NSRunLoop with configurable modes._

## UDP

**GCDAsyncUdpSocket** and **AsyncUdpSocket** are UDP/IP socket networking libraries. Here are the key features available in both:

- Native objective-c, fully self-contained in one class.<br/>
  _No need to muck around with low-level sockets. This class handles everything for you._

- Full delegate support.<br/>
  _Errors, send completions, receive completions, and disconnections all result in a call to your delegate method._

- Queued non-blocking send and receive operations, with optional timeouts.<br/>
  _You tell it what to send or receive, and it handles everything for you. Queueing, buffering, waiting and checking errno - all handled for you automatically._

- Support for IPv4 and IPv6.<br/>
  _Automatically send/recv using IPv4 and/or IPv6. No more worrying about multiple sockets._

**GCDAsyncUdpSocket** is built atop Grand Central Dispatch:

- Fully GCD based and Thread-Safe<br/>
  _It runs entirely within its own GCD dispatch_queue, and is completely thread-safe. Further, the delegate methods are all invoked asynchronously onto a dispatch_queue of your choosing. This means parallel operation of your socket code, and your delegate/processing code._

**AsyncUdpSocket** wraps CFSocket:

- Fully Run-loop based<br/>
  _Use it on the main thread or a worker thread. It plugs into the NSRunLoop with configurable modes._

***

Can't find the answer to your question in any of the [wiki](https://github.com/robbiehanson/CocoaAsyncSocket/wiki) articles? Try the **[mailing list](http://groups.google.com/group/cocoaasyncsocket)**.
<br/>
<br/>
Love the project? Wanna buy me a coffee? (or a beer :D) [![donation](http://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=2M8C699FQ8AW2)

