//
//  RACCustom.m
//  RAC
//
//  Created by Courser on 2018/9/10.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import "RACCustom.h"

#import <objc/runtime.h>
#import "RACCancelProtocol.h"

@interface RACCustom ()

@property (nonatomic, readonly, strong) RACSubject *subject;
@property (nonatomic, readonly, strong) RACCommand *command;
@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
@property (assign, nonatomic, getter=isCancelled) BOOL cancelled;
@property (nonatomic, strong) RACDisposable *disposable;

@end

@implementation RACCustom {
    RACSubject *_subject;
}

- (instancetype)init {
    if (self = [super init]) {
        _queuePriority = NSOperationQueuePriorityNormal;
        _executing = NO;
        _finished = NO;
    }
    return self;
}

- (RACCommand *)command {
    
    return [[RACCommand alloc] initWithSignalBlock:^RACSignal * _Nonnull(id  _Nullable input) {
        self.executing = YES;
        self.finished = NO;
        return [RACSignal createSignal:^RACDisposable * _Nullable(id<RACSubscriber>  _Nonnull subscriber) {
            
            if ([input isKindOfClass:[NSURL class]]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
                    [subscriber sendNext:((NSURL *)input).absoluteString];
                    [subscriber sendCompleted];
                });
            }
            
            return [RACDisposable disposableWithBlock:^{
                
            }];
        }];
    }];
}

- (RACSubject *)subject {
    if (!_subject) {
        _subject = [RACSubject subject];
        @weakify(self)
        [_subject subscribeNext:^(id  _Nullable x) {
            @strongify(self)
            self.executing = NO;
            self.finished = YES;
            NSLog(@"%@",x);
        } error:^(NSError * _Nullable error) {
            @strongify(self)
            self.executing = NO;
            self.finished = YES;
            NSLog(@"%@",error);
        }];
    }
    return _subject;
}

- (void)cancel {
    [[RACScheduler mainThreadScheduler] schedule:^{
        self.cancelled = YES;
        id <RACCancelProtocol> delegate = objc_getAssociatedObject(self, "delegate");
        if ([delegate respondsToSelector:@selector(cancelCustom:)]) {
            [delegate cancelCustom:self];
        }
    }];
}

- (void)dealloc {
    NSLog(@"++++++ dealloc ++++++");
}

@end
