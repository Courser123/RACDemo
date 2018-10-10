//
//  UGCRequestQueue.h
//  RAC
//
//  Created by Courser on 2018/9/10.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReactiveObjC.h"
@class UGCRequest;

typedef NS_ENUM(NSInteger, UGCRequestExecutionOrder) {
    /**
     * Default value. All download operations will execute in queue style (first-in-first-out).
     */
    UGCRequestFIFOExecutionOrder,
    
    /**
     * All download operations will execute in stack style (last-in-first-out).
     */
    UGCRequestLIFOExecutionOrder
};

@interface UGCRequestQueueOptions : NSObject

@property (nonatomic, assign) UGCRequestExecutionOrder executionOrder;
@property NSInteger maxConcurrentOperationCount; // default value is 6

@end

@interface UGCRequestQueue : NSObject

@property (getter=isSuspended) BOOL suspended;

- (instancetype)initWithUGCRequestQueueOptions:(UGCRequestQueueOptions *)options;

- (RACSubject *)addRequest:(UGCRequest *)request;


@end
