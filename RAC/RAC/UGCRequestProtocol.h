//
//  UGCRequestProtocol.h
//  RAC
//
//  Created by Courser on 2018/9/20.
//  Copyright © 2018 王忠迪. All rights reserved.
//

#import <Foundation/Foundation.h>
@class UGCBaseRequest;

@protocol UGCRequestProtocol <NSObject>

- (void)cancelRequest:(UGCBaseRequest *)request;

@end

