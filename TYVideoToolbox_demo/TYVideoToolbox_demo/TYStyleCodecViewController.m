//
//  TYStyleCodecViewController.m
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/14.
//  Copyright © 2018年 汤义. All rights reserved.
//  编解码

#import "TYStyleCodecViewController.h"
#import <VideoToolbox/VideoToolbox.h>
#import "TYPlayLayer.h"
#import "TYToGetData.h"

@interface TYStyleCodecViewController (){
    //编码
    TYEncodeVideo *h264Encoder;
    AVCaptureSession *captureSession;
    AVCaptureConnection* connection;
    AVSampleBufferDisplayLayer *sbDisplayLayer;
    dispatch_queue_t encodeQueue;
    NSFileHandle *fileHandle;
    NSString *h264FileSavePath;
    
    //解码
    uint8_t *_sps;
    NSInteger _spsSize;
    uint8_t *_pps;
    NSInteger _ppsSize;
    VTDecompressionSessionRef _deocderSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
    TYPlayLayer *_playLayer;
    bool playCalled;
}

@end

// 解码
static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}

@implementation TYStyleCodecViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    h264Encoder = [TYEncodeVideo alloc];
    [h264Encoder initEncodeVideo];
    // 设置文件保存位置在document文件夹
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    h264FileSavePath = [documentsDirectory stringByAppendingPathComponent:@"test.h264"];
    [fileManager removeItemAtPath:h264FileSavePath error:nil];
    [fileManager createFileAtPath:h264FileSavePath contents:nil attributes:nil];
    [self startCamera];
    [self cancelBut];
    [self addDecodingBut];       
}

#pragma mark --- 编码
//获取摄像头
- (void)startCamera{
    NSError *deviceError;
    //AVCaptureDevice是用来获取摄像头的
    AVCaptureDevice *cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&deviceError];
    
    //这是用来输出摄像头获取的数据
    AVCaptureVideoDataOutput *outputDevice = [[AVCaptureVideoDataOutput alloc] init];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    outputDevice.videoSettings = videoSettings;
    
    [outputDevice setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    //创建Session
    
    captureSession = [[AVCaptureSession alloc] init];
    
    [captureSession addInput:inputDevice];
    [captureSession addOutput:outputDevice];
    
    // begin configuration for the AVCaptureSession
    [captureSession beginConfiguration];
    
    // picture resolution
    [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    [captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset1280x720]];
    
    connection = [outputDevice connectionWithMediaType:AVMediaTypeVideo];
    [self setRelativeVideoOrientation];
    
    [captureSession commitConfiguration];
    
    // 添加另一个播放Layer，这个layer接收CMSampleBuffer来播放
    AVSampleBufferDisplayLayer *sb = [[AVSampleBufferDisplayLayer alloc]init];
    sb.backgroundColor = [UIColor blackColor].CGColor;
    sbDisplayLayer = sb;
    sb.videoGravity = AVLayerVideoGravityResizeAspect;
    sbDisplayLayer.frame = CGRectMake(0, 20, self.view.frame.size.width, 600);
    [self.view.layer addSublayer:sbDisplayLayer];
    
    // 开始调用摄像头
    [captureSession startRunning];
    
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:h264FileSavePath];
    //初始化编码代码
    [h264Encoder initVideoToolBox];
    [h264Encoder setDelegete:self];
}

- (void)cancelBut{
    UIButton *but = [UIButton buttonWithType:UIButtonTypeCustom];
    but.frame = CGRectMake(0, H - 30, 100, 30);
    but.backgroundColor = [UIColor redColor];
    [but setTitle:@"取消编码" forState:UIControlStateNormal];
    [but addTarget:self action:@selector(selectorBut) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:but];
}

- (void)selectorBut{
    [self stopCamera];
    [h264Encoder end];
}

- (void)setRelativeVideoOrientation {
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            connection.videoOrientation =
            AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate 摄像头画面代理
-(void) captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
    CGSize imageSize = CVImageBufferGetEncodedSize( imageBuffer );
    NSLog(@"ImageBufferSize------width:%.1f,heigh:%.1f",imageSize.width,imageSize.height);
    
    //直接把samplebuffer传给AVSampleBufferDisplayLayer进行预览播放
    [sbDisplayLayer enqueueSampleBuffer:sampleBuffer];
    [h264Encoder encode:sampleBuffer];
}

#pragma mark - H264HwEncoderImplDelegate delegate 解码代理
- (void)getSpsPps:(NSData*)sps pps:(NSData*)pps
{
    NSLog(@"gotSpsPps %d %d", (int)[sps length], (int)[pps length]);
    //[sps writeToFile:h264FileSavePath atomically:YES];
    //[pps writeToFile:h264FileSavePath atomically:YES];
    // write(fd, [sps bytes], [sps length]);
    //write(fd, [pps bytes], [pps length]);
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:pps];
    
}
- (void)getEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
    //    static int framecount = 1;
    
    // [data writeToFile:h264FileSavePath atomically:YES];
    //write(fd, [data bytes], [data length]);
    if (fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [fileHandle writeData:ByteHeader];
        //[fileHandle writeData:UnitHeader];
        [fileHandle writeData:data];
    }
}
//取消摄像头
- (void)stopCamera
{
    [captureSession stopRunning];
    //close(fd);
    [fileHandle closeFile];
    fileHandle = NULL;
    [sbDisplayLayer removeFromSuperlayer];
}

#pragma mark -- 解码

- (void)addDecodingBut{
    UIButton *but1 = [UIButton buttonWithType:UIButtonTypeCustom];
    but1.frame = CGRectMake(W - 100, H - 30, 100, 30);
    but1.backgroundColor = [UIColor greenColor];
    [but1 setTitle:@"解码" forState:UIControlStateNormal];
    [but1 addTarget:self action:@selector(playLayer) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:but1];
}
//设置播放图层
- (void)playLayer{
    //这里用到是OpenGL技术来绘制
    if (!_playLayer) {
        _playLayer = [[TYPlayLayer alloc] initWithFrame:CGRectMake(0, 0, W, H - 300)];
    }
    [self.view.layer addSublayer:_playLayer];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self decodeFile];
    });
}
//decodeFile:(NSString*)fileName fileExt:(NSString*)fileExt
-(void)decodeFile {
    TYToGetData *parser = [TYToGetData alloc];
    //准备数据
    [parser open:h264FileSavePath];
    
    TYVideoPacket *vp = nil;
    while(true) {
        //获取数据
        vp = [parser nextPacket];
        if(vp == nil) {
            break;
        }
        
        uint32_t nalSize = (uint32_t)(vp.size - 4);
        uint8_t *pNalSize = (uint8_t*)(&nalSize);
        vp.buffer[0] = *(pNalSize + 3);
        vp.buffer[1] = *(pNalSize + 2);
        vp.buffer[2] = *(pNalSize + 1);
        vp.buffer[3] = *(pNalSize);
        
        CVPixelBufferRef pixelBuffer = NULL;
        int nalType = vp.buffer[4] & 0x1F;
        switch (nalType) {
            case 0x05:
                NSLog(@"Nal type is IDR frame");
                if([self initH264Decoder]) {
                    NSLog(@"每次都能进入这里吗");
                    pixelBuffer = [self decode:vp];
                }
                break;
            case 0x07:
                NSLog(@"Nal type is SPS");
                _spsSize = vp.size - 4;
                _sps = malloc(_spsSize);
                memcpy(_sps, vp.buffer + 4, _spsSize);
                break;
            case 0x08:
                NSLog(@"Nal type is PPS");
                _ppsSize = vp.size - 4;
                _pps = malloc(_ppsSize);
                memcpy(_pps, vp.buffer + 4, _ppsSize);
                break;
                
            default:
                NSLog(@"Nal type is B/P frame");
                pixelBuffer = [self decode:vp];
                break;
        }
        
        if(pixelBuffer) {
            //将数据添加图层中播放
            dispatch_sync(dispatch_get_main_queue(), ^{
                _playLayer.pixelBuffer = pixelBuffer;
            });
            
            CVPixelBufferRelease(pixelBuffer);
        }
        
        NSLog(@"Read Nalu size %ld", (long)vp.size);
    }
    [parser close];
}

#pragma mark - 解码
//这里都是为了做准备，这里只会创建一次
-(BOOL)initH264Decoder {
    if(_deocderSession) {
        NSLog(@"已有了工具");
        return YES;
    }
    //初始sps和pps
    const uint8_t* const parameterSetPointers[2] = { _sps, _pps };
    //用来放置sps和pps的具体数据
    const size_t parameterSetSizes[2] = { _spsSize, _ppsSize };
    //准备
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    
    if(status == noErr) {
        CFDictionaryRef attrs = NULL;
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
        //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = NULL;
        //这个是用来做异步解码实现的，decompressionOutputRefCon 为需要指定的对象，即自己。didDecompress则为回调函数。
        //将需要sps、pps和数据格式、解码回调都包装到_deocderSession中
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL, attrs,
                                              &callBackRecord,
                                              &_deocderSession);
        CFRelease(attrs);
    } else {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", (int)status);
    }
    
    return YES;
}
-(void)clearH264Deocder {
    if(_deocderSession) {
        VTDecompressionSessionInvalidate(_deocderSession);
        CFRelease(_deocderSession);
        _deocderSession = NULL;
    }
    
    if(_decoderFormatDescription) {
        CFRelease(_decoderFormatDescription);
        _decoderFormatDescription = NULL;
    }
    
    free(_sps);
    free(_pps);
    _spsSize = _ppsSize = 0;
}

-(CVPixelBufferRef)decode:(TYVideoPacket*)vp {
    CVPixelBufferRef outputPixelBuffer = NULL;
    //由编码的数据（I、P、B帧数据）创建CMBlockBuffer。
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)vp.buffer, vp.size,
                                                          kCFAllocatorNull,
                                                          NULL, 0, vp.size,
                                                          0, &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {vp.size};
        //由CMBlockBuffer和CMVideoFormatDescription创建CMSampleBuffer
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            // 默认是同步操作。
            // 调用didDecompress，返回后再回调，将didDecompress装在到_deocderSession中了。
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,//输出解码数据
                                                                      &flagOut);
            
            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", (int)decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", (int)decodeStatus);
            }
            
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    
    return outputPixelBuffer;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
