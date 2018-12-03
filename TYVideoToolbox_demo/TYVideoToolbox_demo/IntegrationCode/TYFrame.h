//
//  TYFrame.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/12/3.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TYFrame : NSObject
//数据
@property (nonatomic,strong) NSData *data;

//时间戳
@property (nonatomic,assign) int timestamp;

//长度
@property (nonatomic,assign) int msgLength;

//typeId
@property (nonatomic,assign) int msgTypeId;

//msgStreamId
@property (nonatomic,assign) int msgStreamId;

//关键帧
@property (nonatomic,assign) BOOL isKeyframe;

@end
