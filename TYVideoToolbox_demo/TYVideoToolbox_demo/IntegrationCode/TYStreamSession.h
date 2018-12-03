//
//  TYStreamSession.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/12/3.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef NSStreamEvent TYStreamStatus;

@class TYStreamSession;
@protocol TYStreamSessionDelegate <NSObject>

- (void)streamSession:(TYStreamSession *)session didChangeStatus:(TYStreamStatus)streamStatus;

@end

@interface TYStreamSession : NSObject

@property (nonatomic,assign,readonly) TYStreamStatus streamStatus;

@property (nonatomic,weak) id<TYStreamSessionDelegate> delegate;

- (void)connectToServer:(NSString *)host port:(UInt32)port;

- (void)disConnect;

- (NSData *)readData;

- (NSInteger)writeData:(NSData *)data;

@end
