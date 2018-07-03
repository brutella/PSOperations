/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
This file contains the foundational subclass of NSOperation.
*/

import Foundation

/**
    The subclass of `NSOperation` from which all other operations should be derived.
    This class adds both Conditions and Observers, which allow the operation to define
    extended readiness requirements, as well as notify many interested parties
    about interesting operation state changes
*/
open class Operation: Foundation.Operation {
    
    /* The completionBlock property has unexpected behaviors such as executing twice and executing on unexpected threads. BlockObserver
     * executes in an expected manner.
     */
    @available(*, deprecated, message: "use BlockObserver completions instead")
    override open var completionBlock: (() -> Void)? {
        set {
            fatalError("The completionBlock property on NSOperation has unexpected behavior and is not supported in PSOperations.Operation 😈")
        }
        get {
            return nil
        }
    }
    
    internal var finishErrors = Atomic<[NSError]>(value: [])
    internal var conditions: [OperationCondition] = []
    internal var observers: [OperationObserver] = []
    
    open var errors: [NSError] {
        return finishErrors.value
    }
    
    open var userInitiated: Bool {
        get {
            return qualityOfService == .userInitiated
        }
        set {
            qualityOfService = newValue ? .userInitiated : .default
        }
    }
    
    private var _isReady = Atomic<Bool>(value: false)
    override open var isReady: Bool {
        // super.isReady is true once all dependencies finishes
        return _isReady.value && super.isReady
    }
    
    private var _isExecuting = Atomic<Bool>(value: false)
    override open var isExecuting: Bool {
        return _isExecuting.value
    }
    
    private var _isFinished = Atomic<Bool>(value: false)
    override open var isFinished: Bool {
        return _isFinished.value
    }
    
    private var _conditionEvaluationStarted = true
    
    internal func didEnqueue() {
        willChangeValue(forKey: "isReady")
        _isReady.modify { $0 = true }
        didChangeValue(forKey: "isReady")
    }
    
    // MARK: Observers and Conditions
    
    open func addCondition(_ condition: OperationCondition) {
        assert(_conditionEvaluationStarted, "Cannot modify conditions after condition evaluating started.")
        conditions.append(condition)
    }
    
    open func addObserver(_ observer: OperationObserver) {
        assert(!isExecuting && !isFinished, "Cannot modify observers after execution has begun.")
        observers.append(observer)
    }
    
    override open func addDependency(_ operation: Foundation.Operation) {
        assert(!isReady, "Dependencies cannot be modified after operation is ready.")
        super.addDependency(operation)
    }
    
    // MARK: Execution
    
    /**
     This methods starts executing the operation.
     
     - First all conditions are evaluated. If a condition fails, the operation gets cancelled and transitions to the finished state.
     - If no conditions failed, `execute()` is called and `isExecuting` is `true`.
     
     If the operation is already canceled, it transitions to the finished state without doing anything.
     
     - Note: The operation queue calls this method automatically once `Operation.isReady` is true.
     */
    open override func start() {
        guard !isCancelled else {
            willChangeValue(forKey: "isFinished")
            _isFinished.modify { $0 = true }
            didChangeValue(forKey: "isFinished")
            return
        }
        
        _conditionEvaluationStarted = true
        let errors = OperationConditionEvaluator.evaluate(conditions, operation: self)
        if errors.count > 0 {
            self.cancelWithErrors(errors)
            self.finish()
        } else {
            for observer in observers {
                observer.operationDidStart(self)
            }
            
            willChangeValue(forKey: "isExecuting")
            _isExecuting.modify { $0 = true }
            didChangeValue(forKey: "isExecuting")
            execute()
        }
    }
    
    /**
     `execute()` is the entry point of execution for all `Operation` subclasses.
     If you subclass `Operation` and wish to customize its execution, you would
     do so by overriding the `execute()` method.
     
     At some point, your `Operation` subclass must call one of the "finish"
     methods defined below; this is how you indicate that your operation has
     finished its execution, and that operations dependent on yours can re-evaluate
     their readiness state.
     */
    open func execute() {
        print("\(type(of: self)) must override `execute()`.")
        finish()
    }
    
    // MARK: Cancellation
    
    override open func cancel() {
        print("CANCEL")
        // sets super.isCancelled to true
        super.cancel()
        
        for observer in observers {
            observer.operationDidCancel(self)
        }
    }
    
    open func cancelWithErrors(_ errors: [NSError]) {
        finishErrors.modify { $0 = $0 + errors }
        cancel()
    }
    
    open func cancelWithError(_ error: NSError) {
        cancelWithErrors([error])
    }
    
    public final func produceOperation(_ operation: Foundation.Operation) {
        for observer in observers {
            observer.operation(self, didProduceOperation: operation)
        }
    }
    
    // MARK: Finishing
    
    /**
     Most operations may finish with a single error, if they have one at all.
     This is a convenience method to simplify calling the actual `finish()`
     method. This is also useful if you wish to finish with an error provided
     by the system frameworks. As an example, see `DownloadEarthquakesOperation`
     for how an error from an `NSURLSession` is passed along via the
     `finishWithError()` method.
     */
    public final func finishWithError(_ error: NSError?) {
        if let error = error {
            finish([error])
        } else {
            finish()
        }
    }
    
    /**
     A private property to ensure we only notify the observers once that the
     operation has finished.
     */
    public final func finish(_ errors: [NSError] = []) {
        var finishWithErrors: [NSError] = []
        finishErrors.modify { internalErrors in
            internalErrors.append(contentsOf: errors)
            finishWithErrors = internalErrors
        }
        
        finished(finishWithErrors)
        
        for observer in observers {
            observer.operationDidFinish(self, errors: finishWithErrors)
        }
        
        willChangeValue(forKey: "isExecuting")
        _isExecuting.modify { $0 = false }
        didChangeValue(forKey: "isExecuting")
        
        willChangeValue(forKey: "isFinished")
        _isFinished.modify { $0 = true }
        didChangeValue(forKey: "isFinished")
    }
    
    /**
     Subclasses may override `finished(_:)` if they wish to react to the operation
     finishing with errors. For example, the `LoadModelOperation` implements
     this method to potentially inform the user about an error when trying to
     bring up the Core Data stack.
     */
    open func finished(_ errors: [NSError]) { }
    
    override open func waitUntilFinished() {
        /*
         Waiting on operations is almost NEVER the right thing to do. It is
         usually superior to use proper locking constructs, such as `dispatch_semaphore_t`
         or `dispatch_group_notify`, or even `NSLocking` objects. Many developers
         use waiting when they should instead be chaining discrete operations
         together using dependencies.
         
         To reinforce this idea, invoking `waitUntilFinished()` will crash your
         app, as incentive for you to find a more appropriate way to express
         the behavior you're wishing to create.
         */
        fatalError("Waiting on operations is an anti-pattern.")
    }
}
