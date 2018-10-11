//
//  UGCBaseRequest.m
//  RAC
//
//  Created by Courser on 2018/9/10.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import "UGCBaseRequest.h"

#import <objc/runtime.h>
#import "UGCRequestProtocol.h"

@interface UGCBaseRequest ()

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
@property (assign, nonatomic, getter=isCancelled) BOOL cancelled;

@end

@implementation UGCBaseRequest

- (instancetype)init {
    if (self = [super init]) {
        _queuePriority = UGCRequestQueuePriorityNormal;
        _executing = NO;
        _finished = NO;
        _cancelled = NO;
    }
    return self;
}

- (RACCommand *)start {
    
    return [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(id  _Nullable input) {

        return [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {

            return [RACDisposable disposableWithBlock:^{
                
            }];
        }];
    }];
}

- (void)cancel {
    self.cancelled = YES;
    id <UGCRequestProtocol> delegate = objc_getAssociatedObject(self, "delegate");
    if ([delegate respondsToSelector:@selector(cancelRequest:)]) {
        [delegate cancelRequest:self];
    }
}

- (void)dealloc {
    NSLog(@"++++++ dealloc:%@ ++++++",self.url.absoluteString);
}

@end
