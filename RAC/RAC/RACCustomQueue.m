//
//  RACCustomQueue.m
//  RAC
//
//  Created by Courser on 2018/9/10.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import "RACCustomQueue.h"

#import "RACCustom.h"
#import <pthread.h>
#import <objc/runtime.h>
#import "RACCancelProtocol.h"

@interface RACCustomQueue () <RACCancelProtocol>

@property (nonatomic, strong) NSMutableDictionary <NSNumber *, NSMutableArray *> *priorityDict;
@property (nonatomic, strong) NSMutableArray <RACCustom *> *executingCustom;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) RACScheduler *scheduler;
@property (nonatomic, strong) RACScheduler *downloadScheduler;

@end

@implementation RACCustomQueue {
    dispatch_semaphore_t _semaphore;
    pthread_mutex_t _downloadLock;
}

- (instancetype)init {
    if (self = [super init]) {
        _priorityDict = [NSMutableDictionary dictionary];
        _executingCustom = [NSMutableArray array];
        _lock = [[NSLock alloc] init];
        _scheduler = [RACQueueScheduler scheduler];
        _downloadScheduler = [[RACQueueScheduler alloc] initWithName:@"com.courser.download" queue:dispatch_queue_create("RACCustomQueue", DISPATCH_QUEUE_CONCURRENT)];
        _semaphore = dispatch_semaphore_create(6);
        pthread_mutex_init(&_downloadLock, NULL);
    }
    return self;
}

- (void)addCustom:(RACCustom *)custom {
    [self saveToDict:custom];
    @weakify(self);
    [self.scheduler schedule:^{
        @strongify(self);
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        pthread_mutex_lock(&_downloadLock);
        RACCustom *custom = [self anyObject];
        if (custom && !custom.isCancelled) {
            [self addExecutingCustomObject:custom];
            [self.downloadScheduler schedule:^{
                @weakify(self);
                @weakify(custom);
                RACDisposable *disposabe = [[[[self getProperty:custom].first execute:custom.url] deliverOn:[RACScheduler mainThreadScheduler]] subscribeNext:^(id  _Nullable x) {
                    @strongify(self);
                    @strongify(custom);
                    [[self getProperty:custom].second sendNext:x];
                    [[self getProperty:custom].second sendCompleted];
                    [self removeExecutingCustomObject:custom];
                    if (!custom.isCancelled) {
                        dispatch_semaphore_signal(_semaphore);
                    }
                } error:^(NSError * _Nullable error) {
                    @strongify(self);
                    @strongify(custom);
                    [[self getProperty:custom].second sendError:error];
                    [self removeExecutingCustomObject:custom];
                    if (!custom.isCancelled) {
                        dispatch_semaphore_signal(_semaphore);
                    }
                }];
                [custom setValue:disposabe forKey:@"disposable"];
            }];
        }else {
            dispatch_semaphore_signal(_semaphore);
        }
        pthread_mutex_unlock(&_downloadLock);
    }];
}

- (RACTuple *)getProperty:(RACCustom *)custom {
    return [RACTuple tupleWithObjects:(RACCommand *)[custom valueForKey:@"command"],
                                      (RACSubject *)[custom valueForKey:@"subject"],
                                      nil];
}

- (void)addExecutingCustomObject:(RACCustom *)object {
    if (!object) return;
    [self.lock lock];
    [self.executingCustom addObject:object];
    [self.lock unlock];
}

- (void)removeExecutingCustomObject:(RACCustom *)object {
    [self.lock lock];
    [self.executingCustom removeObject:object];
    [self.lock unlock];
}

- (void)saveToDict:(RACCustom *)custom {
    if (!custom) return;
    __weak typeof(RACCustomQueue *) weakSelf = self;
    objc_setAssociatedObject(custom, "delegate", weakSelf, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.lock lock];
    if (![self.priorityDict objectForKey:@(custom.queuePriority)]) {
        NSMutableArray *array = [NSMutableArray array];
        [array insertObject:custom atIndex:0];
        [self.priorityDict setObject:array forKey:@(custom.queuePriority)];
    }else {
        NSMutableArray *array = [self.priorityDict objectForKey:@(custom.queuePriority)];
        [array insertObject:custom atIndex:0];
    }
    [self.lock unlock];
}

- (RACCustom *)anyObject {
    RACCustom *custom = nil;
    [self.lock lock];
    for (NSInteger i = 8; i > -8; i-=4) {
        custom = [self.priorityDict objectForKey:@(i)].firstObject;
        if (custom) {
            break;
        }
    }
    [self.lock unlock];
    [self removeObject:custom];
    return custom;
}

- (void)removeObject:(RACCustom *)custom {
    if (!custom) return;
    [self.lock lock];
    [[self.priorityDict objectForKey:@(custom.queuePriority)] removeObject:custom];
    [self.lock unlock];
}

- (void)cancelCustom:(RACCustom *)custom {
    pthread_mutex_lock(&_downloadLock);
    [[custom valueForKey:@"disposable"] dispose];
    if (custom.isExecuting) {
        dispatch_semaphore_signal(_semaphore);
    }
    [self removeExecutingCustomObject:custom];
    pthread_mutex_unlock(&_downloadLock);
}

//- (void)dealloc {
//    NSLog(@"++++++ dealloc ++++++");
//}


@end
