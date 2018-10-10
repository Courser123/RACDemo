//
//  UGCRequestQueue.m
//  RAC
//
//  Created by Courser on 2018/9/10.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import "UGCRequestQueue.h"

#import "UGCRequest.h"
#import <pthread.h>
#import <objc/runtime.h>
#import "UGCRequestProtocol.h"
#import "NSObject+RACKVOWrapper.h"

@implementation UGCRequestQueueOptions

- (instancetype)init {
    if (self = [super init]) {
        _executionOrder = RequestFIFOExecutionOrder;
        _maxConcurrentOperationCount = 6;
    }
    return self;
}

@end

@interface UGCRequestQueue () <UGCRequestProtocol>

//@property (nonatomic, strong) NSMutableDictionary <NSNumber *, NSMutableArray *> *priorityDict;
//@property (nonatomic, strong) NSMutableArray <UGCRequest *> *executingRequest;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) RACScheduler *controlScheduler;
@property (nonatomic, strong) RACScheduler *downloadScheduler;
@property (nonatomic, assign) RequestExecutionOrder executionOrder;

@end

@implementation UGCRequestQueue {
    dispatch_semaphore_t _semaphore;
    pthread_mutex_t _downloadLock;
    dispatch_queue_t _controlQueue;
}
@synthesize suspended = _suspended;

- (instancetype)initWithUGCRequestQueueOptions:(UGCRequestQueueOptions *)options {
    if (self = [super init]) {
        _priorityDict = [NSMutableDictionary dictionary];
        _executingRequest = [NSMutableArray array];
        _lock = [[NSLock alloc] init];
        _controlQueue = dispatch_queue_create("ControlQueue", DISPATCH_QUEUE_SERIAL);
        _controlScheduler = [[RACQueueScheduler alloc] initWithName:@"com.courser.control" queue:_controlQueue];
        _downloadScheduler = [[RACQueueScheduler alloc] initWithName:@"com.courser.download" queue:dispatch_queue_create("UGCRequestQueue", DISPATCH_QUEUE_CONCURRENT)];
        _semaphore = dispatch_semaphore_create(options.maxConcurrentOperationCount);
        pthread_mutex_init(&_downloadLock, NULL);
        for (NSInteger i = -8 ; i <= 8; i += 4) {
            NSMutableArray *array = [NSMutableArray array];
            [_priorityDict setObject:array forKey:@(i)];
        }
        _executionOrder = options.executionOrder;
    }
    return self;
}

- (instancetype)init {
    UGCRequestQueueOptions *options = [UGCRequestQueueOptions new];
    return [self initWithUGCRequestQueueOptions:options];
}

- (RACSubject *)addRequest:(UGCRequest *)request {
    [self _addRequest:request];
//    return [self getProperty:request].second;
    return request.completionSubject;
}

- (void)_addRequest:(UGCRequest *)request {
    [self saveToRequestDict:request];
    @weakify(self);
    [self.controlScheduler schedule:^{
        @strongify(self);
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        pthread_mutex_lock(&_downloadLock);
        UGCRequest *request = [self anyRequest];
        if (request && ![[request valueForKey:@"internalCancelled"] boolValue]) {
            [self addExecutingRequest:request];
            [self.downloadScheduler schedule:^{
                [request setValue:@(YES) forKey:@"internalExecuting"];
                [request setValue:@(NO) forKey:@"internalFinished"];
                @weakify(self);
                @weakify(request);
                RACDisposable *disposabe = [[[[self getProperty:request].first execute:request.url] deliverOn:[RACScheduler mainThreadScheduler]] subscribeNext:^(id  _Nullable x) {
                    @strongify(self);
                    @strongify(request);
//                    pthread_mutex_lock(&_downloadLock);
                    if (![[request valueForKey:@"internalCancelled"] boolValue]) {
                        [request setValue:@(NO) forKey:@"internalExecuting"];
                        [request setValue:@(YES) forKey:@"internalFinished"];
                        [request.completionSubject sendNext:x];
                        [request.completionSubject sendCompleted];
                        [self removeExecutingRequest:request];
                        dispatch_semaphore_signal(_semaphore);
                    }
//                    pthread_mutex_unlock(&_downloadLock);
                } error:^(NSError * _Nullable error) {
                    @strongify(self);
                    @strongify(request);
//                    pthread_mutex_lock(&_downloadLock);
                    if (![[request valueForKey:@"internalCancelled"] boolValue]) {
                        [request setValue:@(NO) forKey:@"internalExecuting"];
                        [request setValue:@(YES) forKey:@"internalFinished"];
                        [request.completionSubject sendError:error];
                        [self removeExecutingRequest:request];
                        dispatch_semaphore_signal(_semaphore);
                    }
//                    pthread_mutex_unlock(&_downloadLock);
                }];
                [request setValue:disposabe forKey:@"disposable"];
            }];
        }else {
            dispatch_semaphore_signal(_semaphore);
        }
        pthread_mutex_unlock(&_downloadLock);
    }];
}

- (RACTuple *)getProperty:(UGCRequest *)request {
    return [RACTuple tupleWithObjects:(RACCommand *)[request valueForKey:@"command"],
//                                      (RACSubject *)[request valueForKey:@"completionSubject"],
                                      nil];
}

- (void)addExecutingRequest:(UGCRequest *)request {
    if (!request) return;
    [self.lock lock];
    [self.executingRequest addObject:request];
    [self.lock unlock];
}

- (void)removeExecutingRequest:(UGCRequest *)request {
    if (!request) return;
    [self.lock lock];
    [self.executingRequest removeObject:request];
    [self.lock unlock];
}

- (void)saveToRequestDict:(UGCRequest *)request {
    if (!request) return;
//    __weak typeof(UGCRequestQueue *) weakSelf = self;
//    objc_setAssociatedObject(request, "delegate", weakSelf, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(request, "delegate", self, OBJC_ASSOCIATION_ASSIGN);
    [request setValue:@(request.queuePriority) forKey:@"internalQueuePriority"];
    @weakify(self);
    @weakify(request);
    [request rac_observeKeyPath:@"queuePriority" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew observer:nil block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
        @strongify(self);
        @strongify(request);
        if (!causedByDealloc && ([[change objectForKey:@"old"] integerValue] != [[change objectForKey:@"new"] integerValue])) {
            [self.lock lock];
            [request setValue:@(request.queuePriority) forKey:@"internalQueuePriority"];
            [[self.priorityDict objectForKey:[change objectForKey:@"old"]] removeObject:request];
            NSMutableArray *array = [self.priorityDict objectForKey:@(request.queuePriority)];
            if (self.executionOrder == RequestFIFOExecutionOrder) {
                [array addObject:request];
            }else {
                [array insertObject:request atIndex:0];
            }
            [self.lock unlock];
        }
    }];
    [self.lock lock];
    NSMutableArray *array = [self.priorityDict objectForKey:[request valueForKey:@"internalQueuePriority"]];
    if (self.executionOrder == RequestFIFOExecutionOrder) {
        [array addObject:request];
    }else {
        [array insertObject:request atIndex:0];
    }
    [self.lock unlock];
}

- (UGCRequest *)anyRequest {
    UGCRequest *request = nil;
    [self.lock lock];
    request = [self getFistRequest];
    [self removeRequest:request];
    [self.lock unlock];
    return request;
}

- (UGCRequest *)getFistRequest {
    UGCRequest *request = nil;
    for (NSInteger i = 8; i >= -8; i-=4) {
        request = [self.priorityDict objectForKey:@(i)].firstObject;
        if (request) {
            break;
        }
    }
    return request;
}

- (void)removeRequest:(UGCRequest *)request {
    if (!request) return;
    [[self.priorityDict objectForKey:[request valueForKey:@"internalQueuePriority"]] removeObject:request];
}

- (void)cancelRequest:(UGCRequest *)request {
    pthread_mutex_lock(&_downloadLock);
    NSLog(@"+++ hascanceled:%@ +++",request.url.absoluteString);
    [request setValue:@(YES) forKey:@"internalCancelled"];
    [[request valueForKey:@"disposable"] dispose];
    if ([[request valueForKey:@"internalExecuting"] boolValue]) {
        dispatch_semaphore_signal(_semaphore);
    }
    [self removeExecutingRequest:request];
    pthread_mutex_unlock(&_downloadLock);
}

- (void)setSuspended:(BOOL)suspended {
    if (suspended && (_suspended == NO)) {
        dispatch_suspend(_controlQueue);
    }else if (!suspended && (_suspended == YES)) {
        dispatch_resume(_controlQueue);
    }
    _suspended = suspended;
}

- (BOOL)isSuspended {
    return _suspended;
}

- (void)dealloc {
    if (self.isSuspended) {
        dispatch_resume(_controlQueue);
    }
    NSLog(@"++++++ dealloc ++++++");
}


@end
