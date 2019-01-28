/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This code shows how to create a simple subclass of Operation.
 */

import Foundation

/// A closure type that takes a closure as its parameter.
public typealias OperationBlock = (@escaping () -> Void) -> Void

/// A sublcass of `Operation` to execute a closure.
open class BlockOperation: Operation {
    fileprivate let block: OperationBlock?
    
    /**
     The designated initializer.
     
     - parameter block: The closure to run when the operation executes. This
     closure will be run on an arbitrary queue. The parameter passed to the
     block **MUST** be invoked by your code, or else the `BlockOperation`
     will never finish executing. If this parameter is `nil`, the operation
     will immediately finish.
     */
    public init(block: OperationBlock? = nil) {
        self.block = block
        super.init()
    }
    
    /**
     A convenience initializer to execute a block of code.
     
     - parameter block: The block to execute. Note
     that this block does not have a "continuation" block to execute (unlike
     the designated initializer). The operation will be automatically ended
     after the `block` is executed.
     */
    public convenience init(block: @escaping () -> Void) {
        self.init { continuation in
            block()
            continuation()
        }
    }
    
    /**
     A convenience initializer to execute a block on the main queue.
     
     - parameter mainQueueBlock: The block to execute on the main queue. Note
     that this block does not have a "continuation" block to execute (unlike
     the designated initializer). The operation will be automatically ended
     after the `mainQueueBlock` is executed.
     */
    @available(*, deprecated, message: "This initializer breaks QOS, please use the main initializer. If you want to execute on the main thread you still can yourself within the closure. This initializer will be removed in a future version of PSOperations")
    public convenience init(mainQueueBlock: @escaping () -> Void) {
        self.init(block: { continuation in
            DispatchQueue.main.async {
                mainQueueBlock()
                continuation()
            }
        })
    }
    
    override open func execute() {
        if let block = block {
            block {
                self.finish()
            }
        } else {
            finish()
        }
    }
}
