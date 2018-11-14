//
//  TYPlayLayer.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/14.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#include <CoreVideo/CoreVideo.h>
@interface TYPlayLayer : CAEAGLLayer
@property CVPixelBufferRef pixelBuffer;
- (instancetype)initWithFrame:(CGRect)frame;
- (void)resetRenderBuffer;
@end
