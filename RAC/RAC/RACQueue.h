//
//  RACQueue.h
//  RAC
//
//  Created by Courser on 07/09/2017.
//  Copyright © 2017 王忠迪. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReactiveObjC.h"

@interface RACQueue : NSObject

- (void)addRACSignal:(RACSignal *)rac nextBlock:(void (^)(id x))nextBlock;

- (void)cancelAllRACOperation;

@end
