//
//  TYEncodeVideo.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/12.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
@protocol TYEncodeVideoDelegate<NSObject>
- (void)getSpsPps:(NSData*)sps pps:(NSData*)pps;
- (void)getEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame;
@end
@interface TYEncodeVideo : NSObject
- (void)initEncodeVideo;
- (void)initVideoToolBox;
- (void)encode:(CMSampleBufferRef )sampleBuffer;
- (void)end;
@property (nonatomic, weak) id<TYEncodeVideoDelegate> delegate;
@property (nonatomic, weak) NSString *error;
@end
