//
//  UGCRequest.m
//  RAC
//
//  Created by Courser on 2018/9/10.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import "UGCRequest.h"

#import <objc/runtime.h>
#import "UGCRequestProtocol.h"

@interface UGCRequest ()

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
@property (assign, nonatomic, getter=isCancelled) BOOL cancelled;

@end

@implementation UGCRequest

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
        self.executing = YES;
        self.finished = NO;
        return [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
            if ([input isKindOfClass:[NSURL class]]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
                    self.executing = NO;
                    self.finished = YES;
                    [subscriber sendNext:((NSURL *)input).absoluteString];
                    [subscriber sendCompleted];
                });
            }
            
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
