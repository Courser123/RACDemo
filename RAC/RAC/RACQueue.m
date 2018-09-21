//
//  RACQueue.m
//  RAC
//
//  Created by Courser on 07/09/2017.
//  Copyright © 2017 王忠迪. All rights reserved.
//

#import "RACQueue.h"

@implementation RACQueue {
    
    NSMutableArray <RACDisposable *> *_queueArray;
    NSOperationQueue *_queue;
    RACSignal *_rac;
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = [[NSOperationQueue alloc] init];
    }
    return self;
}

- (void)addRACSignal:(RACSignal *)rac nextBlock:(void (^)(id x))nextBlock {
    
//    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
//        
//        [rac subscribeNext:nextBlock];
//        
//    }];
//    
//    [_queue addOperation:operation];
    _rac = rac;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [_rac subscribeNext:nextBlock];
    });
    
}

- (void)cancelAllRACOperation {
    
//    [_queue cancelAllOperations];
    _rac = nil;
    NSLog(@"销毁");
}

@end
