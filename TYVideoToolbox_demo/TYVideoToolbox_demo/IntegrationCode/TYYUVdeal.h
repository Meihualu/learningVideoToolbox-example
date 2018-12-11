//
//  TYYUVdeal.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/12/7.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include "aw_encode_flv.h"
@interface TYYUVdeal : NSObject
//旋转
-(NSData *)rotateNV12Data:(NSData *)nv12Data;
//编码
-(aw_flv_video_tag *) encodeYUVDataToFlvTag:(NSData *)yuvData;

-(aw_flv_video_tag *) encodeVideoSampleBufToFlvTag:(CMSampleBufferRef)videoSample;

//根据flv，h264，aac协议，提供首帧需要发送的tag
//创建sps pps
-(aw_flv_video_tag *) createSpsPpsFlvTag;

//转换
-(NSData *) convertVideoSmapleBufferToYuvData:(CMSampleBufferRef) videoSample;
@end
