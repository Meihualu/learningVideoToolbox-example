//
//  TYEncodeVideo.m
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/12.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import "TYEncodeVideo.h"
#import "LFVideoFrame.h"
#import "TYYUVdeal.h"
#include "aw_utils.h"
@interface TYEncodeVideo(){
    VTCompressionSessionRef compressionSession;
    VTCompressionSessionRef encodingSession;
    dispatch_queue_t encodeQueue;
    NSData *sps;
    NSData *pps;
    int  frameCount;
    BOOL enabledWriteVideoFile;
    FILE *fp;
}
@property (nonatomic, weak) id<TYVideoEncodingAgentDelegate> delegate;
@property (nonatomic, strong) TYYUVdeal *deal;
@property (nonatomic) NSInteger currentVideoBitRate;
@end

@implementation TYEncodeVideo
@synthesize error;

- (void)initEncodeVideo:(TYYUVdeal *)deal{
    encodingSession = nil;
//    initialized = true;
    encodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    frameCount = 0;
    sps = NULL;
    pps = NULL;
    _deal = deal;
#ifdef DEBUG
    enabledWriteVideoFile = NO;
    [self initForFilePath];
#endif
}

- (void)initForFilePath {
    NSString *path = [self GetFilePathByfileName:@"IOSCamDemo.h264"];
    NSLog(@"%@", path);
    self->fp = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "wb");
}

- (NSString *)GetFilePathByfileName:(NSString*)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return writablePath;
}
// VTCompressionOutputCallback（回调方法）  由VTCompressionSessionCreate调用
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)sourceFrameRefCon) longLongValue];
    
    TYEncodeVideo* encoder = (__bridge TYEncodeVideo*)outputCallbackRefCon;
    
    // Check if we have got a key frame first
    //获取是第一个帧，这也是关键帧
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // 获得了sps，再获取pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // 获取SPS和PPS data
                encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(getSpsPps:pps:timestamp:)])
                {
                    [encoder.delegate getSpsPps:encoder->sps pps:encoder->pps timestamp:timeStamp];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    //这里获取了数据指针，和NALU的帧总长度，前四个字节里面保存的
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;// 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            // 读取NALU长度的数据
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            LFVideoFrame *videoFrame = [LFVideoFrame new];
            videoFrame.timestamp = timeStamp;
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            videoFrame.data = data;
            videoFrame.isKeyFrame = keyframe;
            videoFrame.sps = encoder->sps;
            videoFrame.pps = encoder->pps;
            
            if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(getEncodedData:timestamp:isKeyFrame:)]) {
                [encoder.delegate getEncodedData:data timestamp:timeStamp isKeyFrame:keyframe];
            }
            
            if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(videoEncoder:videoFrame:)]) {
                [encoder.delegate videoEncoder:encoder videoFrame:videoFrame];
            }
            // 移动到下一个NALU单元
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
    }
    
}

#pragma mark -- VideoCallBack
static void VideoCompressonOutputCallback(void *VTref, void *VTFrameRef, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer){
    if (!sampleBuffer) return;
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!array) return;
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    if (!dic) return;
    
    BOOL keyframe = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)VTFrameRef) longLongValue];
    
    TYEncodeVideo *videoEncoder = (__bridge TYEncodeVideo *)VTref;
    if (status != noErr) {
        return;
    }
    
    if (keyframe && !videoEncoder->sps) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (statusCode == noErr) {
                videoEncoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                videoEncoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (videoEncoder.delegate && [videoEncoder.delegate respondsToSelector:@selector(getSpsPps:pps:timestamp:)])
                {
                    [videoEncoder.delegate getSpsPps:videoEncoder->sps pps:videoEncoder->pps timestamp:timeStamp];
                }
                if (videoEncoder->enabledWriteVideoFile) {
                    NSMutableData *data = [[NSMutableData alloc] init];
                    uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
                    [data appendBytes:header length:4];
                    [data appendData:videoEncoder->sps];
                    [data appendBytes:header length:4];
                    [data appendData:videoEncoder->pps];
                    fwrite(data.bytes, 1, data.length, videoEncoder->fp);
                }
                
            }
        }
    }
    
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            LFVideoFrame *videoFrame = [LFVideoFrame new];
            videoFrame.timestamp = timeStamp;
            videoFrame.data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            videoFrame.isKeyFrame = keyframe;
            videoFrame.sps = videoEncoder->sps;
            videoFrame.pps = videoEncoder->pps;
            
            if (videoEncoder.delegate && [videoEncoder.delegate respondsToSelector:@selector(getEncodedData:timestamp:isKeyFrame:)]) {
                [videoEncoder.delegate getEncodedData:videoFrame.data timestamp:timeStamp isKeyFrame:keyframe];
            }
            
            if (videoEncoder.delegate && [videoEncoder.delegate respondsToSelector:@selector(videoEncoder:videoFrame:)]) {
                [videoEncoder.delegate videoEncoder:videoEncoder videoFrame:videoFrame];
            }
            
            if (videoEncoder->enabledWriteVideoFile) {
                NSMutableData *data = [[NSMutableData alloc] init];
                if (keyframe) {
                    uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
                    [data appendBytes:header length:4];
                } else {
                    uint8_t header[] = {0x00, 0x00, 0x01};
                    [data appendBytes:header length:3];
                }
                [data appendData:videoFrame.data];
                
                fwrite(data.bytes, 1, data.length, videoEncoder->fp);
            }
            
            
            bufferOffset += AVCCHeaderLength + NALUnitLength;
            
        }
        
    }
}


- (void)initVideoToolBox {
    dispatch_sync(encodeQueue  , ^{
//        frameNO = 0;
        int width = 640, height = 480;
        // 创建编码
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &encodingSession);
        NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        if (status != 0)
        {
            NSLog(@"H264: Unable to create a H264 session");
            return ;
        }
        
        /**
         configuration.sessionPreset = LFCaptureSessionPreset360x640;
         configuration.videoFrameRate = 24;
         configuration.videoMaxFrameRate = 24;
         configuration.videoMinFrameRate = 12;
         configuration.videoBitRate = 600 * 1000;
         configuration.videoMaxBitRate = 720 * 1000;
         configuration.videoMinBitRate = 500 * 1000;
         configuration.videoSize = CGSizeMake(360, 640);
         configuration.sessionPreset = [configuration supportSessionPreset:configuration.sessionPreset];
         configuration.videoMaxKeyframeInterval = configuration.videoFrameRate*2;
         configuration.outputImageOrientation = outputImageOrientation;
         */
        
        // 设置实时编码输出（避免延迟）
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        
        // 设置关键帧（GOPsize)间隔
        int frameInterval = 24;
        CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
        
        //设置期望帧率
        int fps = 15;
        CFNumberRef  fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        
        
        //设置码率，均值，单位是byte
        int bitRate = width * height * 3 * 4 * 8;
//        int bitRate = 600 * 1000;
        CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
        
        //设置码率，上限，单位是bps
        int bitRateLimit = width * height * 3 * 4;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        
        //开始编码
        VTCompressionSessionPrepareToEncodeFrames(encodingSession);
    });
}

- (void)resetCompressionSession {
    if (compressionSession) {
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
    }
    
    /**
     configuration.sessionPreset = LFCaptureSessionPreset360x640;
     configuration.videoFrameRate = 24;
     configuration.videoMaxFrameRate = 24;
     configuration.videoMinFrameRate = 12;
     configuration.videoBitRate = 600 * 1000;
     configuration.videoMaxBitRate = 720 * 1000;
     configuration.videoMinBitRate = 500 * 1000;
     configuration.videoSize = CGSizeMake(360, 640);
     configuration.sessionPreset = [configuration supportSessionPreset:configuration.sessionPreset];
     configuration.videoMaxKeyframeInterval = configuration.videoFrameRate*2;
     configuration.outputImageOrientation = outputImageOrientation;
     CGSize size = configuration.videoSize;
     if(configuration.landscape) {
     configuration.videoSize = CGSizeMake(size.height, size.width);
     } else {
     configuration.videoSize = CGSizeMake(size.width, size.height);
     }
     */
    
    OSStatus status = VTCompressionSessionCreate(NULL, 360, 640, kCMVideoCodecType_H264, NULL, NULL, NULL, VideoCompressonOutputCallback, (__bridge void *)self, &compressionSession);
    if (status != noErr) {
        return;
    }
    
    _currentVideoBitRate = 600 * 1000;
    // 设置关键帧（GOPsize)间隔
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(24*2));
    
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(24*2/24));
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(24));
    //设置码率，均值，单位是byte
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(600 * 1000));
    
    NSArray *limit = @[@(600 * 1000 * 1.5/8), @(1)];
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    // 设置实时编码输出（避免延迟）
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
    
    
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    VTCompressionSessionPrepareToEncodeFrames(compressionSession);
    
}

// 从控制的AVCaptureVideoDataOutputSampleBufferDelegate代理方法中调用至此
- (void)encode:(CMSampleBufferRef )sampleBuffer // 频繁调用
{
    dispatch_sync(encodeQueue, ^{
        
        frameCount++;
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        //            CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Create properties
        CMTime presentationTimeStamp = CMTimeMake(frameCount, 1); // 这个值越大画面越模糊
        //            CMTime duration = CMTimeMake(1, DURATION);
        VTEncodeInfoFlags flags;
        
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(encodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL, NULL, &flags);
//        status = VTCompressionSessionEncodeFrame(_vEnSession, pixelBuf, pts, kCMTimeInvalid, NULL, pixelBuf, NULL);
        // Check for error
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            error = @"H264: VTCompressionSessionEncodeFrame failed ";
            
            // End the session
            VTCompressionSessionInvalidate(encodingSession);
            CFRelease(encodingSession);
            encodingSession = NULL;
            error = NULL;
            return;
        }
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    });
    
}

#pragma mark -- LFVideoEncoder
- (void)encodeVideoData:(CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp {
//    if(_isBackGround) return;
    dispatch_sync(encodeQueue  , ^{
        frameCount++;
        CMTime presentationTimeStamp = CMTimeMake(frameCount, (int32_t)24);
        VTEncodeInfoFlags flags;
        CMTime duration = CMTimeMake(1, (int32_t)24);
        
        NSDictionary *properties = nil;
        if (frameCount % (int32_t)24*2 == 0) {
            properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
        }
        NSNumber *timeNumber = @(timeStamp);
        
        OSStatus status = VTCompressionSessionEncodeFrame(compressionSession, pixelBuffer, presentationTimeStamp, duration, (__bridge CFDictionaryRef)properties, (__bridge_retained void *)timeNumber, &flags);
        if(status != noErr){
            [self resetCompressionSession];
        }
    });
}

- (void)encodeYuv:(CMSampleBufferRef )sampleBuffer // 频繁调用
{
    __weak typeof(self) weakSelf = self;
    dispatch_sync(encodeQueue, ^{
        [weakSelf addYuv:sampleBuffer];
    });

}

- (void)addYuv:(CMSampleBufferRef )sampleBuffer{
    frameCount++;
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
    CGSize videoSize = CVImageBufferGetEncodedSize( imageBuffer );
    NSLog(@"ImageBufferSize------width:%.1f,heigh:%.1f",videoSize.width,videoSize.height);
    
//    NSData *yuvData = [_deal convertVideoSmapleBufferToYuvData:sampleBuffer];
    NSData *yuvData = [self convertVideoSmapleBufferToYuvData:sampleBuffer];
    //视频宽度
    size_t pixelWidth = videoSize.width;
    //视频高度
    size_t pixelHeight = videoSize.height;
    
    //现在要把NV12数据放入 CVPixelBufferRef中，因为 硬编码主要调用VTCompressionSessionEncodeFrame函数，此函数不接受yuv数据，但是接受CVPixelBufferRef类型。
    CVPixelBufferRef pixelBuf = NULL;
    //初始化pixelBuf，数据类型是kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange，此类型数据格式同NV12格式相同。
    CVPixelBufferCreate(NULL, pixelWidth, pixelHeight, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, NULL, &pixelBuf);
    
    // Lock address，锁定数据，应该是多线程防止重入操作。
    if(CVPixelBufferLockBaseAddress(pixelBuf, 0) != kCVReturnSuccess){
        [self onErrorWithCode:@"在这里" des:@"encode video lock base address failed"];
        return;
    }
    
    //将yuv数据填充到CVPixelBufferRef中
    size_t y_size = pixelWidth * pixelHeight;
    size_t uv_size = y_size / 4;
    uint8_t *yuv_frame = (uint8_t *)yuvData.bytes;
    
    //处理y frame
    uint8_t *y_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuf, 0);
    memcpy(y_frame, yuv_frame, y_size);
    
    uint8_t *uv_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuf, 1);
    memcpy(uv_frame, yuv_frame + y_size, uv_size * 2);
    
    //硬编码 CmSampleBufRef
    
    //时间戳
    //        uint32_t ptsMs = self.manager.timestamp + 1; //self.vFrameCount++ * 1000.f / self.videoConfig.fps;
    
    CMTime pts = CMTimeMake(frameCount, 1);
    
    VTEncodeInfoFlags flags;
    //硬编码主要其实就这一句。将携带NV12数据的PixelBuf送到硬编码器中，进行编码。
//    OSStatus statusCode = VTCompressionSessionEncodeFrame(encodingSession, pixelBuf, pts, kCMTimeInvalid, NULL, NULL, &flags);
    OSStatus statusCode = VTCompressionSessionEncodeFrame(encodingSession, pixelBuf, pts, kCMTimeInvalid, NULL, pixelBuf, NULL);
    if (statusCode != noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
        error = @"H264: VTCompressionSessionEncodeFrame failed ";
        
        // End the session
        VTCompressionSessionInvalidate(encodingSession);
        CFRelease(encodingSession);
        encodingSession = NULL;
        error = NULL;
        return;
    }
    NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
}

-(void)onErrorWithCode:(NSString *)code des:(NSString *) des{
    aw_log("[ERROR] encoder error code:%@ des:%s",code, des.UTF8String);
}
//获取yuv数据
-(NSData *)convertVideoSmapleBufferToYuvData:(CMSampleBufferRef)videoSample{
    // 获取yuv数据
    // 通过CMSampleBufferGetImageBuffer方法，获得CVImageBufferRef。
    // 这里面就包含了yuv420(NV12)数据的指针
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(videoSample);
    
    //表示开始操作数据
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    //图像宽度（像素）
    size_t pixelWidth = CVPixelBufferGetWidth(pixelBuffer);
    //图像高度（像素）
    size_t pixelHeight = CVPixelBufferGetHeight(pixelBuffer);
    //yuv中的y所占字节数
    size_t y_size = pixelWidth * pixelHeight;
    //yuv中的uv所占的字节数
    size_t uv_size = y_size / 2;
    
    uint8_t *yuv_frame = aw_alloc(uv_size + y_size);
    
    //获取CVImageBufferRef中的y数据
    uint8_t *y_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(yuv_frame, y_frame, y_size);
    
    //获取CMVImageBufferRef中的uv数据
    uint8_t *uv_frame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    memcpy(yuv_frame + y_size, uv_frame, uv_size);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    //返回数据
    return [NSData dataWithBytesNoCopy:yuv_frame length:y_size + uv_size];
}


- (void)setDelegete:(nullable id<TYVideoEncodingAgentDelegate>)delegate{
    _delegate = delegate;
}

- (void)end{
    // Mark the completion
    VTCompressionSessionCompleteFrames(encodingSession, kCMTimeInvalid);
    // End the session
    VTCompressionSessionInvalidate(encodingSession);
    CFRelease(encodingSession);
    encodingSession = NULL;
    error = NULL;
}
@end
