//
//  TYH264Packager.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/12/3.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TYFrame.h"
@class TYH264Packager;
@protocol TYH264PackagerDelegate <NSObject>

- (void)h264Packager:(TYH264Packager *)packager didPacketFrame:(TYFrame *)frame;

@end
@interface TYH264Packager : NSObject

@property (nonatomic, weak) id<TYH264PackagerDelegate> delegate;

- (void)reset;

- (void)packageKeyFrameSps:(NSData *)spsData pps:(NSData *)ppsData timestamp:(uint64_t)timestamp;

- (void)packageFrame:(NSData *)data timestamp:(uint64_t)timestamp isKeyFrame:(BOOL)isKeyFrame;
@end
