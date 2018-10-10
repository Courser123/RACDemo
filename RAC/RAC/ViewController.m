//
//  ViewController.m
//  RAC
//
//  Created by 王忠迪 on 05/07/2017.
//  Copyright © 2017 王忠迪. All rights reserved.
//

#import "ViewController.h"
#import "ReactiveObjC.h"
#import "TestOperation.h"
#import "UGCRequest.h"
#import "UGCRequestQueue.h"

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
    
    self.queue = [[UGCRequestQueue alloc] init];
    self.operationQueue = [[NSOperationQueue alloc] init];
//    self.queue.maxConcurrentOperationCount = 10;
//    for (int i = 0 ; i < 100; i ++) {
//        RACCustom *custom = [[RACCustom alloc] init];
//        custom.url = [NSURL URLWithString:[NSString stringWithFormat:@"%d",i]];
//        [self.queue addCustom:custom];
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [custom cancel];
//        });
//    }
//    NSOperationQueue *queue = [NSOperationQueue new];
//    NSLog(@"%ld",queue.maxConcurrentOperationCount);
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    [self testOperation];
    [self test];
}

- (void)test {
    
    for (int i = 0 ; i < 10000; i ++) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            UGCRequest *request = [[UGCRequest alloc] init];
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

- (void)testOperation {
    for (int i = 0; i < 10000; i++) {
        TestOperation *operation = [[TestOperation alloc] init];
        if (i % 2 == 0) {
            self.operationQueue.maxConcurrentOperationCount = 8;
        }else {
            self.operationQueue.maxConcurrentOperationCount = 4;
        }
        [self.operationQueue addOperation:operation];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
