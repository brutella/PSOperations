//
//  NoFailedDependencies.swift
//  PSOperations
//
//  Created by Matthias Hochgatterer on 29.07.20.
//  Copyright © 2020 Pluralsight. All rights reserved.
//

import Foundation

/// A `NoFailedDependencies` condition checks if all dependencies of an operation finished without an error.
public struct NoFailedDependencies: OperationCondition {

    fileprivate var errors = [NSError]()
    public static var name: String {
        return "\(NoFailedDependencies.self)"
    }
    public static var isMutuallyExclusive: Bool = true
    
    public init() {
        // No op.
    }

    public func dependencyForOperation(_ operation: PSOperations.Operation) -> Foundation.Operation? {
        return nil
    }

    public func evaluateForOperation(_ operation: PSOperations.Operation, completion: @escaping(PSOperations.OperationConditionResult) -> Void) {
        for operation in operation.dependencies {
            if let operation = operation as? PSOperations.Operation {
                if operation.errors.count > 0 {
                    let error = NSError(domain: NoFailedDependencies.name, code: 0, userInfo: [NSUnderlyingErrorKey: operation.errors])
                    completion(.failed(error))
                    return
                }
            }
        }
        
        completion(.satisfied)
    }
}
