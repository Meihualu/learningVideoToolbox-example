//
//  TYlLntegrationCodeViewController.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/27.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "TYEncodeVideo.h"
#import "TYVideoEncodingAgent.h"
#import "LFStreamSocket.h"
#import "LFStreamRTMPSocket.h"
//#import "lfs"
/**
 *  连接状态
 */
typedef NS_ENUM(NSUInteger, SGSimpleSessionState) {
    SGSimpleSessionStateNone,
    SGSimpleSessionStateConnecting,
    SGSimpleSessionStateConnected,
    SGSimpleSessionStateReconnecting,
    SGSimpleSessionStateEnd,
    SGSimpleSessionStateError,
};
@interface TYlLntegrationCodeViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,TYVideoEncodingAgentDelegate,LFStreamSocketDelegate,TYH264PackagerDelegate,TYRtmpSessionDeleagte>
/** The reconnectInterval control reconnect timeInterval(重连间隔) *.*/
@property (nonatomic, assign) NSUInteger reconnectInterval;

/** The reconnectCount control reconnect count (重连次数) *.*/
@property (nonatomic, assign) NSUInteger reconnectCount;
@end
