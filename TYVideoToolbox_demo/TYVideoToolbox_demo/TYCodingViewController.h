//
//  TYCodingViewController.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/12.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TYEncodeVideo.h"
@interface TYCodingViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate, TYEncodeVideoDelegate>

@end
