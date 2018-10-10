//
//  UGCRequest.h
//  RAC
//
//  Created by Courser on 2018/9/10.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReactiveObjC.h"

typedef NS_ENUM(NSInteger, UGCRequestQueuePriority) {
    UGCRequestQueuePriorityVeryLow = -8L,
    UGCRequestQueuePriorityLow = -4L,
    UGCRequestQueuePriorityNormal = 0,
    UGCRequestQueuePriorityHigh = 4,
    UGCRequestQueuePriorityVeryHigh = 8
};

@interface UGCRequest : NSObject

@property (nonatomic, strong) NSURL *url;
@property UGCRequestQueuePriority queuePriority;
@property (readonly, getter = isExecuting) BOOL executing;
@property (readonly, getter = isFinished) BOOL finished;
@property (readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, readonly, strong) RACSubject *completionSubject; // 订阅回调信息

- (void)cancel;

@end
