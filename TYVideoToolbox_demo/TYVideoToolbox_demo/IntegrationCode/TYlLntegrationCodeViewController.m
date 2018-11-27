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
}

@end

@implementation TYlLntegrationCodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self accessEquipmentdData];
    
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

- (void)addButView{
    UIButton *but = [UIButton buttonWithType:UIButtonTypeCustom];
    but.frame = CGRectMake(10, H - 30, 100, 30);
    but.backgroundColor = [UIColor redColor];
    [but setTitle:@"录制" forState:UIControlStateNormal];
    [but addTarget:self action:@selector(selectorBut) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:but];
}

- (void)selectorBut{
    [captureSession startRunning];
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
