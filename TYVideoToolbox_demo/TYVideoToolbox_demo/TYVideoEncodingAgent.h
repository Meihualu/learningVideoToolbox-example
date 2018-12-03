//
//  TYVideoEncodingAgent.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/30.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFVideoFrame.h"
@protocol TYVideoEncodingAgent;
@protocol TYVideoEncodingAgentDelegate<NSObject>
- (void)getSpsPps:(nullable NSData *)sps pps:(nullable  NSData*)pps timestamp:(uint64_t)timestamp;
- (void)getEncodedData:(nullable  NSData *)data timestamp:(uint64_t)timestamp isKeyFrame:(BOOL)isKeyFrame;
- (void)videoEncoder:(nullable id<TYVideoEncodingAgent>)encoder videoFrame:(nullable LFVideoFrame *)frame;
@end
@protocol TYVideoEncodingAgent <NSObject>
@required
- (void)initEncodeVideo;
- (void)initVideoToolBox;
- (void)encode:(nullable CMSampleBufferRef )sampleBuffer;
- (void)end;
@property (nonatomic, weak) NSString * _Nullable error;
@optional
- (void)setDelegete:(nullable id<TYVideoEncodingAgentDelegate>)delegate;

@end
