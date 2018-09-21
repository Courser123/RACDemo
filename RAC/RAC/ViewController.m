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
#import "RACQueue.h"
#import "RACCustom.h"
#import "RACCustomQueue.h"

@interface ViewController ()

@property (nonatomic, strong) RACSubject *subject;
@property (nonatomic, strong) RACDisposable *disposable;
@property (nonatomic, strong) RACCustomQueue *queue;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.queue = [[RACCustomQueue alloc] init];
//    for (int i = 0 ; i < 100; i ++) {
//        RACCustom *custom = [[RACCustom alloc] init];
//        custom.url = [NSURL URLWithString:[NSString stringWithFormat:@"%d",i]];
//        [self.queue addCustom:custom];
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [custom cancel];
//        });
//    }
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (int i = 0 ; i < 1000; i ++) {
        RACCustom *custom = [[RACCustom alloc] init];
        custom.url = [NSURL URLWithString:[NSString stringWithFormat:@"%d",i]];
        [self.queue addCustom:custom];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
            [custom cancel];
        });
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
