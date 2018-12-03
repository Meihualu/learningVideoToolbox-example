//
//  NSString+URL.h
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/12/3.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (URL)
@property(readonly) NSString *scheme;
@property(readonly) NSString *host;
@property(readonly) NSString *app;
@property(readonly) NSString *playPath;
@property(readonly) UInt32    port;
@end
