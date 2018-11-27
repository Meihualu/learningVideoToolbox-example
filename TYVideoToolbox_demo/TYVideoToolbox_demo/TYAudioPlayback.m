//
//  TYAudioPlayback.m
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/19.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import "TYAudioPlayback.h"
#import <AudioToolbox/AudioToolbox.h>

const uint32_t CONST_BUFFER_COUNT = 3;
const uint32_t CONST_BUFFER_SIZE = 0x10000;
@interface TYAudioPlayback(){
    AudioFileID audioFileID; // An opaque data type that represents an audio file object.
    AudioStreamBasicDescription audioStreamBasicDescrpition; // An audio data format specification for a stream of audio
    AudioStreamPacketDescription *audioStreamPacketDescrption; // Describes one packet in a buffer of audio data where the sizes of the packets differ or where there is non-audio data between audio packets.
    
    AudioQueueRef audioQueue; // Defines an opaque data type that represents an audio queue.
    AudioQueueBufferRef audioBuffers[CONST_BUFFER_COUNT];
    
    SInt64 readedPacket; //参数类型
    u_int32_t packetNums;
}

@end
@implementation TYAudioPlayback
- (instancetype)init{
    if (self = [super init]) {
        [self audioPlaybackPreparation];
    }
    return self;
}
- (void)audioPlaybackPreparation{
    //NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"aac"];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *path = [[manager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *url = [path URLByAppendingPathComponent:@"abc.aac"];
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, 0, &audioFileID); //Open an existing audio file specified by a URL.
    if (status != noErr) {
        NSLog(@"打开文件失败 %@", url);
        return ;
    }
    uint32_t size = sizeof(audioStreamBasicDescrpition);
    //获得属性的具体内容
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &audioStreamBasicDescrpition); // Gets the value of an audio file property.一个音频文件属性的值。
    NSAssert(status == noErr, @"error");
    //初始化creditease.cn。从上面方法中拿到audioStreamBasicDescrpition用于创建Audio Queue
    status = AudioQueueNewOutput(&audioStreamBasicDescrpition, bufferReady, (__bridge void * _Nullable)(self), NULL, NULL, 0, &audioQueue); // Creates a new playback audio queue object.
    NSAssert(status == noErr, @"error");
    
    if (audioStreamBasicDescrpition.mBytesPerPacket == 0 || audioStreamBasicDescrpition.mFramesPerPacket == 0) {
        uint32_t maxSize;
        size = sizeof(maxSize);
        AudioFileGetProperty(audioFileID, kAudioFilePropertyPacketSizeUpperBound, &size, &maxSize); // The theoretical maximum packet size in the file.理论最大数据包大小的文件。
        if (maxSize > CONST_BUFFER_SIZE) {//限制包的大小，限制的大小为0x10000
            maxSize = CONST_BUFFER_SIZE;
        }
        //计算要开辟的空间大小
        packetNums = CONST_BUFFER_SIZE / maxSize;
        //开辟空间大小
        audioStreamPacketDescrption = malloc(sizeof(AudioStreamPacketDescription) * packetNums);
    }
    else {
        packetNums = CONST_BUFFER_SIZE / audioStreamBasicDescrpition.mBytesPerPacket;
        audioStreamPacketDescrption = nil;
    }
    
    char cookies[100];
    memset(cookies, 0, sizeof(cookies));
    // 这里的100 有问题
    AudioFileGetProperty(audioFileID, kAudioFilePropertyMagicCookieData, &size, cookies); // Some file types require that a magic cookie be provided before packets can be written to an audio file.有些文件类型要求一个神奇的饼干提供数据包之前写入一个音频文件。
    if (size > 0) {
        AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookies, size); // Sets an audio queue property value.
    }
    
    readedPacket = 0;
    // 循环执行 3-5步，直到文件结束。这里为什么会是3个for循环了，这是根据音频的Buffer是三个的原因。
    for (int i = 0; i < CONST_BUFFER_COUNT; ++i) {
        AudioQueueAllocateBuffer(audioQueue, CONST_BUFFER_SIZE, &audioBuffers[i]); // Asks an audio queue object to allocate an audio queue buffer.问一个音频队列对象分配一个音频队列缓冲区。
        if ([self fillBuffer:audioBuffers[i]]) {
            // full
            break;
        }
        NSLog(@"buffer%d full", i);
    }
}

void bufferReady(void *inUserData,AudioQueueRef inAQ,
                 AudioQueueBufferRef buffer){
    NSLog(@"refresh buffer");
    TYAudioPlayback* player = (__bridge TYAudioPlayback *)inUserData;
    if (!player) {
        NSLog(@"player nil");
        return ;
    }
    if ([player fillBuffer:buffer]) {
        NSLog(@"play end");
    }
    
}

//向buffer中填充数据
- (bool)fillBuffer:(AudioQueueBufferRef)buffer {
    bool full = NO;
    uint32_t bytes = 0, packets = (uint32_t)packetNums;
    OSStatus status = AudioFileReadPackets(audioFileID, NO, &bytes, audioStreamPacketDescrption, readedPacket, &packets, buffer->mAudioData); // Reads packets of audio data from an audio file.读取数据包从一个音频文件的音频数据。
    
    NSAssert(status == noErr, ([NSString stringWithFormat:@"error status %d", status]) );
    if (packets > 0) {
        buffer->mAudioDataByteSize = bytes;
        AudioQueueEnqueueBuffer(audioQueue, buffer, packets, audioStreamPacketDescrption);
        readedPacket += packets;
    }
    else {
        AudioQueueStop(audioQueue, NO);
        full = YES;
    }
    
    return full;
}

- (void)play{
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0); // Sets a playback audio queue parameter value.
    AudioQueueStart(audioQueue, NULL); // Begins playing or recording audio.
}
@end
