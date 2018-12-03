//
//  TYRtmpSession.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/12/3.
//  Copyright © 2018年 汤义. All rights reserved.
//  推流的连接对话

#import <Foundation/Foundation.h>
#import "TYFrame.h"
typedef NS_ENUM(NSUInteger, TYRtmpSessionStatus) {
    SGRtmpSessionStatusNone              = 0,
    SGRtmpSessionStatusConnected         = 1,
    
    SGRtmpSessionStatusHandshake0        = 2,
    SGRtmpSessionStatusHandshake1        = 3,
    SGRtmpSessionStatusHandshake2        = 4,
    SGRtmpSessionStatusHandshakeComplete = 5,
    
    SGRtmpSessionStatusFCPublish         = 6,
    SGRtmpSessionStatusReady             = 7,
    SGRtmpSessionStatusSessionStarted    = 8,
    
    SGRtmpSessionStatusError             = 9,
    SGRtmpSessionStatusNotConnected      = 10
};
@class TYRtmpSession;
@protocol TYRtmpSessionDeleagte <NSObject>
- (void)rtmpSession:(TYRtmpSession *)rtmpSession didChangeStatus:(TYRtmpSessionStatus)rtmpStatus;
@end

@class TYRtmpConfig;
@interface TYRtmpSession : NSObject

@property (nonatomic,strong) TYRtmpConfig *config;

@property (nonatomic,weak) id<TYRtmpSessionDeleagte> delegate;

- (void)connect;

- (void)disConnect;

- (void)sendBuffer:(TYFrame *)frame;
@end
