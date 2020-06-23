# PSOperations

This project is based on [pluralsight/PSOperations](https://github.com/pluralsight/PSOperations) with some differences.

- The main class `Operation` is much simpler (with less race conditions).
- Supports push notification authorization for macOS.

## Support

 - Swift 5.x
 - iOS 8.0
 - tvOS 9.0
 - watchOS 3.0
 - macOS 10.11
 - Extension friendly

## Installation
PSOperations supports multiple methods for installing the library in a project.

### CocoaPods
[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like PSOperations in your projects.

 You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate PSOperations into your Xcode project using CocoaPods, specify it in your `Podfile`.  
If you want all the child subspecs (Health and Passbook capabilities):

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

target 'TargetName' do
pod 'PSOperations', '~> 4.0'
end
```

Then, run the following command:

```bash
$ pod install
```

**Alternative configurations:**  
Core functionality, _excluding_ capabilities:
```ruby
pod 'PSOperations/Core', '~> 4.0'
```

Core functionality, including only the Passbook capability:
```ruby
pod 'PSOperations/Passbook', '~> 4.0'
```

Core functionality, including only the Health capability:
```ruby
pod 'PSOperations/Health', '~> 4.0'
```

Core functionality, including only the Calendar capability:
```ruby
pod 'PSOperations/Calendar', '~> 4.0'
```

### Carthage
[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate PSOperations into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "brutella/PSOperations"
```

Run `carthage` to build the framework and drag the built `PSOperations.framework` into your Xcode project. Optionally you can add `PSOperationsHealth.framework`, `PSOperationsPassbook.framework` and `PSOperationsCalendar.framework`

### XCFramework

To build a xcframework for iOS (Device & Simulator) and Mac Catalyst, you have execute the following commands

```shell
# Device slice.
xcodebuild archive -project 'PSOperations.xcodeproj' -scheme 'PSOperations' -configuration Release -destination 'generic/platform=iOS' -archivePath './PSOperations.framework-iphoneos.xcarchive' SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES 

# Simulator slice.
xcodebuild archive -project 'PSOperations.xcodeproj' -scheme 'PSOperations' -configuration Release -destination 'generic/platform=iOS Simulator' -archivePath './PSOperations.framework-iphonesimulator.xcarchive' SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES 

# Mac Catalyst slice.
xcodebuild archive -project 'PSOperations.xcodeproj' -scheme 'PSOperations' -configuration Release -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' -archivePath './PSOperations.framework-catalyst.xcarchive' SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES SUPPORTS_MACCATALYST=YES

xcodebuild -create-xcframework -framework './PSOperations.framework-iphonesimulator.xcarchive/Products/Library/Frameworks/PSOperations.framework' -framework './PSOperations.framework-iphoneos.xcarchive/Products/Library/Frameworks/PSOperations.framework' -framework './PSOperations.framework-catalyst.xcarchive/Products/Library/Frameworks/PSOperations.framework' -output './PSOperations.xcframework'
```

## Getting started

Don't forget to import!
```
import PSOperations
```

If you are using the HealthCapability, PassbookCapability or CalendarCapability you'll need to import them separately:

```
import PSOperationsHealth
import PSOperationsPassbook
import PSOperationsCalendar
```

These features need to be in a separate framework otherwise they may cause App Store review rejection for importing `HealthKit`, `PassKit` or `EventKit` but not actually using them.

#### Create a Queue
The OperationQueue is the heartbeat and is a subclass of NSOperationQueue:
```
let operationQueue = OperationQueue()
```

#### Create an Operation
`Operation` is a subclass of `NSOperation`. Like `NSOperation` it doesn't do much. But PSOperations provides a few helpful subclasses such as:
```
BlockOperation
GroupOperation
URLSessionTaskOperation
LocationOperation
DelayOperation
```

Here is a quick example:
```
let blockOperation = BlockOperation {
	print("perform operation")
}

operationQueue.addOperation(blockOperation)
```

#### Observe an Operation
`Operation` instances can be observed for starting, cancelling, finishing and producing new operations with the `OperationObserver` protocol.

PSOperations provide a couple of types that implement the protocol:
```
BlockObserver
TimeoutObserver
```

Here is a quick example:
```
let blockOperation = BlockOperation {
	print("perform operation")
}

let finishObserver = BlockObserver { operation, error in        
	print("operation finished! \(error)")
}

blockOperation.addObserver(finishObserver)

operationQueue.addOperation(blockOperation)
```

#### Set Conditions on an Operation
`Operation` instances can have conditions required to be met in order to execute using the `OperationCondition` protocol.

PSOperations provide a several types that implement the protocol:
```
SilentCondition
NegatedCondition
NoCancelledDependencies
MutuallyExclusive
ReachabilityCondition
Capability
```

Here is a quick example:
```
let blockOperation = BlockOperation {
	print("perform operation")
}

let dependentOperation = BlockOperation {
	print("working away")
}
                dependentOperation.addCondition(NoCancelledDependencies())
dependentOperation.addDependency(blockOperation)

operationQueue.addOperation(blockOperation)
operationQueue.addOperation(dependentOperation)
```

if `blockOperation` is cancelled, `dependentOperation` will not execute.

#### Set Capabilities on an Operation
A `CapabilityType` is used by the `Capability` condition and allows you to easily view the authorization state and request the authorization of certain capabilities within Apple's ecosystem. i.e. Calendar, Photos, iCloud, Location, and Push Notification.

Here is a quick example:
```
let blockOperation = BlockOperation {
	print("perform operation")
}


let calendarCapability = Capability(Photos())
        
blockOperation.addCondition(calendarCapability)

operationQueue.addOperation(blockOperation)
```

This operation requires access to Photos and will request access to them if needed.

#### Going custom
The examples above provide simple jobs but PSOperations can be involved in many parts of your application. Here is a custom `UIStoryboardSegue` that leverages the power of PSOperations. The segue is retained until an operation is completed. This is a generic `OperationSegue` that will run any given operation. One use case for this might be an authentication operation that ensures a user is authenticated before preceding with the segue. The authentication operation could even present authentication UI if needed.

```
class OperationSegue: UIStoryboardSegue {
    
    var operation: Operation?
    var segueCompletion: ((success: Bool) -> Void)?
    
    override func perform() {        
        if let operation = operation {
            let opQ = OperationQueue()
            var retainedSelf: OperationSegue? = self
            
            let completionObserver = BlockObserver {
                op, errors in
                
                dispatch_async_on_main {
                    defer {
                        retainedSelf = nil
                    }
                    
                    let success = errors.count == 0 && !op.cancelled
                    
                    if let completion = retainedSelf?.segueCompletion {
                        completion(success: success)
                    }
                    
                    if success {
                        retainedSelf?.finish()
                    }
                }
            }
            
            operation.addObserver(completionObserver)
            opQ.addOperation(operation)
        } else {
            finish()
        }
    }
    
    func finish() {
        super.perform()
    }
}

```