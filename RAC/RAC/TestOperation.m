//
//  TestOperation.m
//  RAC
//
//  Created by Courser on 07/09/2017.
//  Copyright © 2017 王忠迪. All rights reserved.
//

#import "TestOperation.h"

@implementation TestOperation

//- (void)start {
//    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [self main];
//    });
//}

- (void)main {
    
    NSLog(@"%@",[NSThread currentThread]);
}

@end
