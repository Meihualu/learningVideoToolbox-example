//
//  LFFrame.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/30.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LFFrame : NSObject
@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, strong) NSData *data;
///< flv或者rtmp包头
@property (nonatomic, strong) NSData *header;
@end
