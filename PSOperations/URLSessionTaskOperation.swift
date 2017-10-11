/*
Copyright (C) 2015 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Shows how to lift operation-like objects in to the NSOperation world.
*/

import Foundation

/**
    `URLSessionTaskOperation` is an `Operation` that lifts an `NSURLSessionTask` 
    into an operation.

    Note that this operation does not participate in any of the delegate callbacks \
    of an `NSURLSession`, but instead uses Key-Value-Observing to know when the
    task has been completed. It also does not get notified about any errors that
    occurred during execution of the task.

    An example usage of `URLSessionTaskOperation` can be seen in the `DownloadEarthquakesOperation`.
*/
open class URLSessionTaskOperation: Operation {
    let task: URLSessionTask
    
    fileprivate var taskStateObservation: NSKeyValueObservation?
    fileprivate let stateLock = NSLock()
    
    public init(task: URLSessionTask) {
        assert(task.state == .suspended, "Tasks must be suspended.")
        self.task = task
        super.init()
        
        addObserver(BlockObserver(cancelHandler: { _ in
            task.cancel()
        }))
    }
    
    override open func execute() {
        assert(task.state == .suspended, "Task was resumed by something other than \(self).")
        
        taskStateObservation = task.observe(\.state) {
            [weak self] (op, change) in
            switch op.state {
            case .completed:
                self?.finish()
                fallthrough
            case .canceling:
                self?.taskStateObservation = nil
            default:
                return
            }
        }
        
        task.resume()
    }
}
