//
//  TYCodingViewController.m
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/12.
//  Copyright © 2018年 汤义. All rights reserved.
// 编码

#import "TYCodingViewController.h"
#import <VideoToolbox/VideoToolbox.h>

@interface TYCodingViewController (){
    TYEncodeVideo *h264Encoder;
    AVCaptureSession *captureSession;
    AVCaptureConnection* connection;
    AVSampleBufferDisplayLayer *sbDisplayLayer;
    dispatch_queue_t encodeQueue;
    NSFileHandle *fileHandle;
    NSString *h264FileSavePath;
}

@end

@implementation TYCodingViewController

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
}

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
    h264Encoder.delegate = self;
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
        
        
        /*NSData *UnitHeader;
         if(isKeyFrame)
         {
         char header[2];
         header[0] = '\x65';
         UnitHeader = [NSData dataWithBytes:header length:1];
         framecount = 1;
         }
         else
         {
         char header[4];
         header[0] = '\x41';
         //header[1] = '\x9A';
         //header[2] = framecount;
         UnitHeader = [NSData dataWithBytes:header length:1];
         framecount++;
         }*/
        [fileHandle writeData:ByteHeader];
        //[fileHandle writeData:UnitHeader];
        [fileHandle writeData:data];
    }
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
