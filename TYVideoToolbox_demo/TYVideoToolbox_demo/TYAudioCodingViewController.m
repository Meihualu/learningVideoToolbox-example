//
//  TYAudioCodingViewController.m
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/16.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import "TYAudioCodingViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TYAudioCoding.h"

@interface TYAudioCodingViewController ()<AVCaptureAudioDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) dispatch_queue_t AudioQueue;
@property (nonatomic, strong) AVCaptureConnection *audioConnection;
@property (nonatomic, strong) TYAudioCoding *audioCoding;
@property (nonatomic, strong) NSFileHandle *audioFileHandle;
@end

@implementation TYAudioCodingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self createFileToDocument];
}

#pragma mark 创建文件夹句柄
- (void)createFileToDocument{
    NSString *audioFile = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.aac"];
    // 有就移除掉
    [[NSFileManager defaultManager] removeItemAtPath:audioFile error:nil];
    // 移除之后再创建
    [[NSFileManager defaultManager] createFileAtPath:audioFile contents:nil attributes:nil];
    self.audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:audioFile];
}

- (void)addButView{
    UIButton *but = [UIButton buttonWithType:UIButtonTypeCustom];
    but.frame = CGRectMake(10, H - 30, 100, 30);
    but.backgroundColor = [UIColor redColor];
    [but setTitle:@"录制" forState:UIControlStateNormal];
    [but addTarget:self action:@selector(selectorBut:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:but];
    
    UIButton *but1 = [UIButton buttonWithType:UIButtonTypeCustom];
    but1.frame = CGRectMake(W - 100,H - 30, 100, 30);
    but1.backgroundColor = [UIColor greenColor];
    [but1 setTitle:@"播放" forState:UIControlStateNormal];
    [but1 addTarget:self action:@selector(selectorBut1:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:but1];
}

- (void)selectorBut:(UIButton *)but{
    but.selected = !but.selected;
    if (but.selected) {
        [self accessAudioEquipment];
        [but setTitle:@"停止" forState:UIControlStateNormal];
    }else{
        [self stopCarmera];
        [but setTitle:@"录制" forState:UIControlStateNormal];
    }
}

- (void)selectorBut1:(UIButton *)but{
    but.selected = !but.selected;
    if (but.selected) {
        
    }
}

- (void)accessAudioEquipment{
    self.audioCoding = [[TYAudioCoding alloc] init];
    //创建session
    self.session = [[AVCaptureSession alloc] init];
    
    //创建cap
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    //创建输入
    NSError *error = nil;
    AVCaptureDeviceInput *audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    if(error){
        NSLog(@"获取设备失败");
    }
    
    //将输入加入到session
    if([self.session canAddInput:audioInput]){
       [self.session addInput:audioInput];
    }
    
    self.AudioQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    //创建输出
    AVCaptureAudioDataOutput *audioOutput = [AVCaptureAudioDataOutput new];
    [audioOutput setSampleBufferDelegate:self queue:self.AudioQueue];
    
    //将输出加入到session
    if ([self.session canAddOutput:audioOutput]) {
        [self.session addOutput:audioOutput];
    }
    //设置音频类型
    self.audioConnection = [audioOutput connectionWithMediaType:AVMediaTypeAudio];
}

- (void)stopCarmera
{
    [_session stopRunning];
}

#pragma mark -- AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if(connection == _audioConnection){
        __weak typeof(self) weakSelf = self;
        [self.audioCoding encodeSampleBuffer:sampleBuffer completionBlock:^(NSData *encodedData, NSError *error) {
            if (encodedData) {
                [weakSelf.audioFileHandle writeData:encodedData];
            }else{
                NSLog(@"编码报错了");
            }
        }];
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
