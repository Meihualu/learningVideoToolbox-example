//
//  TYRtmpConfig.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/12/3.
//  Copyright © 2018年 汤义. All rights reserved.
//  推流的一些参数

#import <Foundation/Foundation.h>

@interface TYRtmpConfig : NSObject
@property (nonatomic,copy  ) NSString *url;
@property (nonatomic,assign) int32_t  width;
@property (nonatomic,assign) int32_t  height;
@property (nonatomic,assign) double   frameDuration;
@property (nonatomic,assign) int32_t  videoBitrate;
@property (nonatomic,assign) double   audioSampleRate;
@property (nonatomic,assign) BOOL     stereo;//立体声
@end
