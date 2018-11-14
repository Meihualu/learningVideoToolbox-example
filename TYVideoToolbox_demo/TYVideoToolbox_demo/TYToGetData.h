//
//  TYToGetData.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/14.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <objc/NSObject.h>
@interface TYVideoPacket : NSObject

@property uint8_t* buffer;
@property NSInteger size;

@end

@interface TYToGetData : NSObject
-(BOOL)open:(NSString*)fileName;
-(TYVideoPacket *)nextPacket;
-(void)close;
@end
