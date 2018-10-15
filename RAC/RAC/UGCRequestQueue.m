//
//  UGCRequestQueue.m
//  RAC
//
//  Created by Courser on 2018/9/10.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import "UGCRequestQueue.h"

#import "UGCBaseRequest.h"
#import <pthread.h>
#import <objc/runtime.h>
#import "UGCRequestProtocol.h"
#import "NSObject+RACKVOWrapper.h"

@implementation UGCRequestQueueOptions

- (instancetype)init {
    if (self = [super init]) {
        _executionOrder = UGCRequestFIFOExecutionOrder;
        _maxConcurrentOperationCount = 6;
    }
    return self;
}

@end

@interface UGCBaseRequest (InternalControl)

@property (nonatomic, readwrite, strong) RACSubject *completionSubject;
@property (nonatomic, strong) RACDisposable *disposable;
@property (nonatomic, assign) BOOL internalCancelled;
@property (nonatomic, assign) BOOL internalExecuting;
@property (nonatomic, assign) BOOL internalFinished;
@property (nonatomic, assign) UGCRequestQueuePriority internalQueuePriority;
@property (nonatomic, assign) BOOL criticalState; // 出了存储数组还未进执行数组的临界状态

@end

@implementation UGCBaseRequest (InternalControl)

- (void)setCompletionSubject:(RACSubject *)completionSubject {
    objc_setAssociatedObject(self, "completionSubject", completionSubject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (RACSubject *)completionSubject {
    return objc_getAssociatedObject(self, "completionSubject");
}

- (void)setDisposable:(RACDisposable *)disposable {
    objc_setAssociatedObject(self, "disposable", disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (RACDisposable *)disposable {
    return objc_getAssociatedObject(self, "disposable");
}

- (void)setInternalCancelled:(BOOL)internalCancelled {
    objc_setAssociatedObject(self, "internalCancelled", @(internalCancelled), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)internalCancelled {
    return [objc_getAssociatedObject(self, "internalCancelled") boolValue];
}

- (void)setInternalExecuting:(BOOL)internalExecuting {
    objc_setAssociatedObject(self, "internalExecuting", @(internalExecuting), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)internalExecuting {
    return [objc_getAssociatedObject(self, "internalExecuting") boolValue];
}

- (void)setInternalFinished:(BOOL)internalFinished {
    objc_setAssociatedObject(self, "internalFinished", @(internalFinished), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)internalFinished {
    return [objc_getAssociatedObject(self, "internalFinished") boolValue];
}

- (void)setInternalQueuePriority:(UGCRequestQueuePriority)internalQueuePriority {
    objc_setAssociatedObject(self, "internalQueuePriority", @(internalQueuePriority), OBJC_ASSOCIATION_ASSIGN);
}

- (UGCRequestQueuePriority)internalQueuePriority {
    return [objc_getAssociatedObject(self, "internalQueuePriority") integerValue];
}

- (void)setCriticalState:(BOOL)criticalState {
    objc_setAssociatedObject(self, "criticalState", @(criticalState), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)criticalState {
    return [objc_getAssociatedObject(self, "criticalState") boolValue];
}

@end

@interface UGCRequestQueue () <UGCRequestProtocol>

@property (nonatomic, strong) NSMutableDictionary <NSNumber *, NSMutableArray *> *priorityDict;
@property (nonatomic, strong) NSMutableArray <UGCBaseRequest *> *executingRequest;
@property (nonatomic, strong) RACScheduler *controlScheduler;
@property (nonatomic, strong) RACScheduler *downloadScheduler;
@property (nonatomic, assign) UGCRequestExecutionOrder executionOrder;

@end

@implementation UGCRequestQueue {
    dispatch_semaphore_t _semaphore;
    pthread_mutex_t _downloadLock;
    dispatch_queue_t _controlQueue;
    dispatch_semaphore_t _lock;
    dispatch_semaphore_t _executionLock;
}
@synthesize suspended = _suspended;

- (instancetype)initWithUGCRequestQueueOptions:(UGCRequestQueueOptions *)options {
    if (self = [super init]) {
        _priorityDict = [NSMutableDictionary dictionary];
        _executingRequest = [NSMutableArray array];
        _lock = dispatch_semaphore_create(1);
        _executionLock = dispatch_semaphore_create(1);
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

- (RACSubject *)addRequest:(UGCBaseRequest *)request {
    RACSubject *completionSubject = [RACSubject subject];
    request.completionSubject = completionSubject;
    [self _addRequest:request];
    return request.completionSubject;
}

- (void)_addRequest:(UGCBaseRequest *)request {
    [self saveToRequestDict:request];
    @weakify(self);
    [self.controlScheduler schedule:^{
        @strongify(self);
        dispatch_semaphore_wait(self->_semaphore, DISPATCH_TIME_FOREVER);
        pthread_mutex_lock(&self->_downloadLock);
        UGCBaseRequest *request = [self anyRequest];
        if (request && !request.internalCancelled) {
            [self addExecutingRequest:request];
            request.internalExecuting = YES;
            request.internalFinished = NO;
            [self.downloadScheduler schedule:^{
                @weakify(self);
                @weakify(request);
                RACDisposable *disposabe = [[[request start] execute:request.url] subscribeNext:^(id  _Nullable x) {
                    @strongify(request);
                    [request.completionSubject sendNext:x];
                } error:^(NSError * _Nullable error) {
                    @strongify(self);
                    @strongify(request);
                    request.internalExecuting = NO;
                    request.internalFinished = YES;
                    [self removeExecutingRequest:request];
                    if (!request.internalCancelled) {
                        dispatch_semaphore_signal(self->_semaphore);
                    }
                    [request.completionSubject sendError:error];
                } completed:^{
                    @strongify(self);
                    @strongify(request);
                    request.internalExecuting = NO;
                    request.internalFinished = YES;
                    [self removeExecutingRequest:request];
                    if (!request.internalCancelled) {
                        dispatch_semaphore_signal(self->_semaphore);
                    }
                    [request.completionSubject sendCompleted];
                }];
                request.disposable = disposabe;
            }];
        }else {
            dispatch_semaphore_signal(self->_semaphore);
        }
        pthread_mutex_unlock(&self->_downloadLock);
    }];
}

- (void)addExecutingRequest:(UGCBaseRequest *)request {
    if (!request) return;
    dispatch_semaphore_wait(self->_executionLock, DISPATCH_TIME_FOREVER);
    [self.executingRequest addObject:request];
    dispatch_semaphore_signal(self->_executionLock);
}

- (void)removeExecutingRequest:(UGCBaseRequest *)request {
    if (!request) return;
    dispatch_semaphore_wait(self->_executionLock, DISPATCH_TIME_FOREVER);
    [self.executingRequest removeObject:request];
    dispatch_semaphore_signal(self->_executionLock);
}

- (void)saveToRequestDict:(UGCBaseRequest *)request {
    if (!request) return;
    objc_setAssociatedObject(request, "delegate", self, OBJC_ASSOCIATION_ASSIGN);
    request.internalQueuePriority = request.queuePriority;
    @weakify(self);
    @weakify(request);
    [request rac_observeKeyPath:@"queuePriority" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew observer:nil block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
        @strongify(self);
        @strongify(request);
        if (!causedByDealloc && ([[change objectForKey:@"old"] integerValue] != [[change objectForKey:@"new"] integerValue])) {
            dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER);
            if (request.criticalState) {
                dispatch_semaphore_signal(self->_lock);
                return;
            }
            request.internalQueuePriority = request.queuePriority;
            [[self.priorityDict objectForKey:[change objectForKey:@"old"]] removeObject:request];
            NSMutableArray *array = [self.priorityDict objectForKey:@(request.queuePriority)];
            if (self.executionOrder == UGCRequestFIFOExecutionOrder) {
                [array addObject:request];
            }else {
                [array insertObject:request atIndex:0];
            }
            dispatch_semaphore_signal(self->_lock);
        }
    }];
    dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER);
    NSMutableArray *array = [self.priorityDict objectForKey:@(request.internalQueuePriority)];
    if (self.executionOrder == UGCRequestFIFOExecutionOrder) {
        [array addObject:request];
    }else {
        [array insertObject:request atIndex:0];
    }
    request.criticalState = NO;
    dispatch_semaphore_signal(self->_lock);
}

- (UGCBaseRequest *)anyRequest {
    UGCBaseRequest *request = nil;
    dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER);
    request = [self getFistRequest];
    [self removeRequest:request];
    request.criticalState = YES;
    dispatch_semaphore_signal(self->_lock);
    return request;
}

- (UGCBaseRequest *)getFistRequest {
    UGCBaseRequest *request = nil;
    for (NSInteger i = 8; i >= -8; i-=4) {
        request = [self.priorityDict objectForKey:@(i)].firstObject;
        if (request) {
            break;
        }
    }
    return request;
}

- (void)removeRequest:(UGCBaseRequest *)request {
    if (!request) return;
    [[self.priorityDict objectForKey:@(request.internalQueuePriority)] removeObject:request];
}

- (void)cancelRequest:(UGCBaseRequest *)request {
    pthread_mutex_lock(&_downloadLock);
    request.internalCancelled = YES;
    [request.disposable dispose];
    if (request.internalExecuting) {
        dispatch_semaphore_signal(_semaphore);
    }
    [request.completionSubject sendCompleted]; // 不sendCompleted会导致内存泄漏!!!
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
