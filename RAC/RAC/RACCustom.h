//
//  RACCustom.h
//  RAC
//
//  Created by Courser on 2018/9/10.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReactiveObjC.h"

@interface RACCustom : NSObject

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) NSOperationQueuePriority queuePriority;
@property (readonly, getter = isExecuting) BOOL executing;
@property (readonly, getter = isFinished) BOOL finished;
@property (readonly, getter=isCancelled) BOOL cancelled;

- (void)cancel;

@end
