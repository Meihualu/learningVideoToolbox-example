//
//  TYlLntegrationCodeViewController.m
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/27.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import "TYlLntegrationCodeViewController.h"
#import <VideoToolbox/VideoToolbox.h>
#import <AudioToolbox/AudioToolbox.h>


@interface TYlLntegrationCodeViewController (){
    AVCaptureSession *captureSession;
    dispatch_queue_t audioQueue;
    AVCaptureConnection *connectionVideo;
    AVCaptureConnection *connectionAudio;
    AVSampleBufferDisplayLayer *sbDisplayLayer;
    UIButton *recordingBut;
    NSFileHandle *fileHandle; //编码后的数据储存器
}
@property (nullable, strong) id<TYVideoEncodingAgent> h264Encoder;
/// 是否开始上传
@property (nonatomic, assign) BOOL uploading;
/// 上传相对时间戳
@property (nonatomic, assign) uint64_t relativeTimestamps;
/// 上传
@property (nonatomic, strong) id<LFStreamSocket> socket;
/// 时间戳锁
@property (nonatomic, strong) dispatch_semaphore_t lock;
/// 流信息
@property (nonatomic, strong) LFLiveStreamInfo *streamInfo;
@end

@implementation TYlLntegrationCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
//    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.h264"];
//    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
//    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
//    fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
    _h264Encoder = [TYEncodeVideo alloc];
    [_h264Encoder initEncodeVideo];
    [self accessEquipmentdData];
    [self videoLayer];
    [self addButView];
}

//获取设备音视的数据
- (void)accessEquipmentdData{
    NSError *error;
    /**
     AVCaptureDevice //硬件设备
     AVCaptureInput //输入的设备
     AVCaptureOutput //输出的数据
     AVCaotureSession //协助input和output的数据传输
     */
    captureSession = [[AVCaptureSession alloc] init];
    //初始化
    AVCaptureDevice *captureDeviceVideo = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDevice *captureDeviceAudio = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    //输入
    AVCaptureDeviceInput *deviceInputVideo = [AVCaptureDeviceInput deviceInputWithDevice:captureDeviceVideo error:&error];
    
    AVCaptureDeviceInput *deviceInpntAudio = [AVCaptureDeviceInput deviceInputWithDevice:captureDeviceAudio error:&error];
    
    //输出视频
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    //设置视频输出格式
    NSString *key = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    NSNumber *val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    //添加到输出对象中
    videoDataOutput.videoSettings = videoSettings;
    [videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    //输出音频
    audioQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    AVCaptureAudioDataOutput *audioDataOutput = [AVCaptureAudioDataOutput new];
    [audioDataOutput setSampleBufferDelegate:self queue:audioQueue];
    
    //添加到sessin中
    //视频
    [captureSession addInput:deviceInputVideo];
    [captureSession addOutput:videoDataOutput];
    //音频
    if ([captureSession canAddInput:deviceInpntAudio]) {
        [captureSession addInput:deviceInpntAudio];
    }
    
    if ([captureSession canAddOutput:audioDataOutput]) {
        [captureSession addOutput:audioDataOutput];
    }
    
    //设置视频的屏幕大小
    [captureSession beginConfiguration];
    [captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    [captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset1280x720]];
    
    //设置格式
    connectionVideo = [videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    connectionAudio = [audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
    [self setRelativeVideoOrientation];
    [captureSession commitConfiguration];
    
    //开始进行编码
    [_h264Encoder initVideoToolBox];
    [_h264Encoder setDelegete:self];
}

//用于显示视频录制影像的layer
- (void)videoLayer{
    AVSampleBufferDisplayLayer *sbLayer = [[AVSampleBufferDisplayLayer alloc] init];
    sbLayer.backgroundColor = [UIColor blackColor].CGColor;
    sbLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    sbLayer.frame = CGRectMake(0, 0, W, H - 50);
    [self.view.layer addSublayer:sbDisplayLayer = sbLayer];
}

- (void)setRelativeVideoOrientation {
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            connectionVideo.videoOrientation = AVCaptureVideoOrientationPortrait;
            
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            connectionVideo.videoOrientation =
            AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            connectionVideo.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            connectionVideo.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate 摄像头画面代理
-(void)captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
    CGSize imageSize = CVImageBufferGetEncodedSize( imageBuffer );
    NSLog(@"ImageBufferSize------width:%.1f,heigh:%.1f",imageSize.width,imageSize.height);
    
    //直接把samplebuffer传给AVSampleBufferDisplayLayer进行预览播放
    if(connection == connectionVideo){
        [sbDisplayLayer enqueueSampleBuffer:sampleBuffer];
        [_h264Encoder encode:sampleBuffer];
    }
    
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
//    [fileHandle writeData:ByteHeader];
//    [fileHandle writeData:sps];
//    [fileHandle writeData:ByteHeader];
//    [fileHandle writeData:pps];
    
}
- (void)getEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
    //    static int framecount = 1;
    
    // [data writeToFile:h264FileSavePath atomically:YES];
    //write(fd, [data bytes], [data length]);
//    if (fileHandle != NULL)
//    {
//        const char bytes[] = "\x00\x00\x00\x01";
//        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
//        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
//        [fileHandle writeData:ByteHeader];
//        //[fileHandle writeData:UnitHeader];
//        [fileHandle writeData:data];
//    }
}

- (void)videoEncoder:(id<TYVideoEncodingAgent>)encoder videoFrame:(LFVideoFrame *)frame{
    if(_uploading){
        [self pushSendBuffer:frame];
    }
}

#pragma mark -- PrivateMethod
- (void)pushSendBuffer:(LFFrame*)frame{
    if(self.relativeTimestamps == 0){
        self.relativeTimestamps = frame.timestamp;
    }
    frame.timestamp = [self uploadTimestamp:frame.timestamp];
    [self.socket sendFrame:frame];
}

- (id<LFStreamSocket>)socket {
    if (!_socket) {
        _socket = [[LFStreamRTMPSocket alloc] initWithStream:self.streamInfo reconnectInterval:self.reconnectInterval reconnectCount:self.reconnectCount];
        [_socket setDelegate:self];
    }
    return _socket;
}

- (LFLiveStreamInfo *)streamInfo {
    if (!_streamInfo) {
        _streamInfo = [[LFLiveStreamInfo alloc] init];
    }
    return _streamInfo;
}

- (uint64_t)uploadTimestamp:(uint64_t)captureTimestamp{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    currentts = captureTimestamp - self.relativeTimestamps;
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

- (dispatch_semaphore_t)lock{
    if(!_lock){
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

- (void)addButView{
    UIButton *but = [UIButton buttonWithType:UIButtonTypeCustom];
    but.frame = CGRectMake(10, H - 30, 100, 30);
    but.backgroundColor = [UIColor redColor];
    [but setTitle:@"录制" forState:UIControlStateNormal];
    [but addTarget:self action:@selector(selectorBut:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:recordingBut = but];
}

- (void)selectorBut:(UIButton *)but{
    NSLog(@"装换前是but数据:%d",but.selected);
    but.selected = !but.selected;
    NSLog(@"装换后是but数据:%d",but.selected);
    if(but.selected){
        _uploading = YES;
        [captureSession startRunning];
        [recordingBut setTitle:@"停止" forState:UIControlStateNormal];
    }else{
        _uploading = NO;
        [self stopCamera];
        [recordingBut setTitle:@"录制" forState:UIControlStateNormal];
    }
    
}

//取消摄像头
- (void)stopCamera
{
    [captureSession stopRunning];
//    //close(fd);
//    [fileHandle closeFile];
//    fileHandle = NULL;
//    [sbDisplayLayer removeFromSuperlayer];
//    [h264Encoder end];
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
