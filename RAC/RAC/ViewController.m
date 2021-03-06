//
//  ViewController.m
//  RAC
//
//  Created by 王忠迪 on 05/07/2017.
//  Copyright © 2017 王忠迪. All rights reserved.
//

#import "ViewController.h"
#import "ReactiveObjC.h"
#import "UGCBaseRequest.h"
#import "UGCRequestQueue.h"
#import "TestRequest.h"

@interface ViewController ()

@property (nonatomic, strong) RACSubject *subject;
@property (nonatomic, strong) RACDisposable *disposable;
@property (nonatomic, strong) UGCRequestQueue *queue;
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    UGCRequestQueueOptions *options = [UGCRequestQueueOptions new];
//    options.executionOrder = RequestLIFOExecutionOrder;
    self.queue = [[UGCRequestQueue alloc] initWithUGCRequestQueueOptions:options];
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self test];
//    [self testQueue];
//    [self testRequest];
}

- (void)testQueue {
    
    UGCRequestQueueOptions *options = [UGCRequestQueueOptions new];
    UGCRequestQueue *queue = [[UGCRequestQueue alloc] initWithUGCRequestQueueOptions:options];
    
    for (int i = 0 ; i < 100; i ++) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            UGCBaseRequest *request = [[UGCBaseRequest alloc] init];
            request.url = [NSURL URLWithString:[NSString stringWithFormat:@"%d",i]];
            if (i % 2 == 0) {
                request.queuePriority = UGCRequestQueuePriorityHigh;
            }else {
                request.queuePriority = UGCRequestQueuePriorityNormal;
            }
            //            self.queue.suspended = YES;
            [[queue addRequest:request] subscribeNext:^(id  _Nullable x) {
                NSLog(@"addRequest done:%@ , queuePriority:%ld",x, request.queuePriority);
            } error:^(NSError * _Nullable error) {
                NSLog(@"addRequest error:%@",error);
            }];
            
            if (i > 5000 && i <= 7500) {
                request.queuePriority = UGCRequestQueuePriorityVeryLow;
            }
            
            if (i < 5000) {
                [request cancel];
            }
            
        });
        
    }
    //    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //        self.queue.suspended = NO;
    //    });
}

- (void)testRequest {
    
    for (int i = 0 ; i < 1000; i++) {
        UGCBaseRequest *request = [UGCBaseRequest new];
        request.url = [NSURL URLWithString:[NSString stringWithFormat:@"%d",i]];
        [[[request start] execute:request.url] subscribeNext:^(id  _Nullable x) {
            NSLog(@"+++ request : %@ +++",x);
        } error:^(NSError * _Nullable error) {
            NSLog(@"+++ error : %@ +++",error);
        }];
    }
    
}

- (void)test {
    
    for (int i = 0 ; i < 10000; i ++) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            TestRequest *request = [[TestRequest alloc] init];
            request.url = [NSURL URLWithString:[NSString stringWithFormat:@"%d",i]];
            if (i % 2 == 0) {
                request.queuePriority = UGCRequestQueuePriorityHigh;
            }else {
                request.queuePriority = UGCRequestQueuePriorityNormal;
            }
//            self.queue.suspended = YES;
            [[self.queue addRequest:request] subscribeNext:^(id  _Nullable x) {
                NSLog(@"addRequest done:%@ , queuePriority:%ld",x, request.queuePriority);
            } error:^(NSError * _Nullable error) {
                NSLog(@"addRequest error:%@",error);
            }];
            
            if (i > 5000 && i <= 7500) {
                request.queuePriority = UGCRequestQueuePriorityVeryHigh;
            }
            
            if (i < 5000) {
                [request cancel];
            }
            
        });
        
    }
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        self.queue.suspended = NO;
//    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
