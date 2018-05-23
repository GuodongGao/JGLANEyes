//
//  ViewController.m
//  JGLANEyes_Server
//
//  Created by mtgao on 2018/5/9.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import "ViewController.h"

#import "JGMacCamera.h"
#import "JGMacH264HardwareEncoder.h"
#import "JGMacTCPServer.h"

@interface ViewController () <JGMacTCPServerDelegate>
@property (weak) IBOutlet NSButton *btnPreset;
@end

@implementation ViewController
{
    JGMacCamera *camera;
    JGMacH264HardwareEncoder *videoEncoder;
    JGMacTCPServer *tcpServer;
    
    __block BOOL isReadyForTCPTransmit;
    
    NSFileHandle *filehandle;  //写裸流文件用于测试
    
    NSString *sessionPreset;
}

- (NSString *)getFilehandle{
    NSArray* documentsArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documents = documentsArray.firstObject;
    NSString* tmpPath = [documents stringByAppendingPathComponent:@"裸流.h264"];
    NSLog(@"tmpPath = %@",tmpPath);
    [[NSFileManager defaultManager] createFileAtPath:tmpPath contents:nil attributes:nil];
    return tmpPath;
}

- (void)initData{
    sessionPreset = AVCaptureSessionPreset1280x720;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initData];
    
    //获取裸流文件句柄
    filehandle = [NSFileHandle fileHandleForWritingAtPath:[self getFilehandle]];

    //初始化相机
    camera = [[JGMacCamera alloc]initWithPreset:sessionPreset];

    //初始化编码器
    videoEncoder = [[JGMacH264HardwareEncoder alloc]init];
    [videoEncoder prepareEncoderWithWidth:1280 andHeight:720];
    
    //初始化服务器
    tcpServer = [[JGMacTCPServer alloc]init];
    tcpServer.delegate = self;
    
   
//    //开始捕捉图像
//    [camera startCaptureAndOutputSampleBuffer:^(CMSampleBufferRef samplebuffer) {
//
////        __strong typeof(self) strongSelf = weakSelf;
////        //图像帧给编码器
////        [strongSelf->videoEncoder pushFrame:samplebuffer andReturnedEncodedData:^(NSData *encodedData) {
////            //写裸流文件
//////            [strongSelf->filehandle writeData:encodedData];
////            //写socket
////            if(strongSelf->isReadyForTCPTransmit){
////                [strongSelf->tcpServer transimitVideoDataToClientWithData:encodedData];
////            }
////        }];
//    }];
    
    //显示在屏幕上
    [camera displayOnView:self.view];
}

- (void)didReceiveMsgFromClient:(NSString *)msg{
    if([msg isEqualToString:kChangeResolution]){
        NSLog(@"server info: do action from client: %@",kChangeResolution);
        [self switchPreset:nil];
    }else if([msg isEqualToString:kStartOrStop]){
        NSLog(@"server info: do action from client: %@",kStartOrStop);
        [self startOrStopCapture:nil];
    }
}

- (IBAction)startOrStopCapture:(id)sender{
    static BOOL isCapturing = NO;
    if(isCapturing){
        [camera stopCapture];
        [tcpServer sendMsg:kStopVideoTransfer];
        isCapturing = NO;
    }else{
        
        __weak typeof(self) weakSelf = self;
        [camera startCaptureAndOutputSampleBuffer:^(CMSampleBufferRef samplebuffer) {
            isCapturing = YES;
    
            __strong typeof(self) strongSelf = weakSelf;
            //图像帧给编码器
            [strongSelf->videoEncoder pushFrame:samplebuffer andReturnedEncodedData:^(NSData *encodedData) {
                //写裸流文件
    //            [strongSelf->filehandle writeData:encodedData];
                //写socket
                if(strongSelf->isReadyForTCPTransmit){
                    [strongSelf->tcpServer transimitVideoDataToClientWithData:encodedData];
                }
            }];
        }];
        [tcpServer sendMsg:kStartVideoTransfer];
    }
}


- (IBAction)switchPreset:(id)sender {
    
    //相机停止采集
    [camera stopCapture];
    static BOOL isSwitchToLow = NO;
    int width = 0;
    int height = 0;
    if(!isSwitchToLow){
        sessionPreset = AVCaptureSessionPreset640x480;
        isSwitchToLow = YES;
        width = 640;
        height = 480;
    }else{
        sessionPreset = AVCaptureSessionPreset1280x720;
        isSwitchToLow = NO;
        width = 1280;
        height = 720;
    }
    
    //设置相机通道
    [camera setCaptureSessionPreset:sessionPreset];
    
    //重新启动编码器
    [videoEncoder resetEncoderWithWidth:width andHeight:height];
    
    [tcpServer sendMsg:kChangeResolution];
    //相机开始采集
    __weak typeof(self) weakSelf = self;
    [camera startCaptureAndOutputSampleBuffer:^(CMSampleBufferRef samplebuffer) {
        __strong typeof(self) strongSelf = weakSelf;
        //图像帧给编码器
        [strongSelf->videoEncoder pushFrame:samplebuffer andReturnedEncodedData:^(NSData *encodedData) {
            //写裸流文件
            //            [strongSelf->filehandle writeData:encodedData];
            //写socket
            if(strongSelf->isReadyForTCPTransmit){
                [strongSelf->tcpServer transimitVideoDataToClientWithData:encodedData];
            }
        }];
    }];
}

- (IBAction)StartOrStopService:(id)sender {
    static BOOL isStart = NO;
    __weak typeof(self) weakSelf = self;
   
    if(!isStart){
         //启动服务socket，开始监听服务端口
        [tcpServer startServerWithReturnSignal:^(BOOL isReady) {
            __strong typeof(self) strongSelf = weakSelf;
            strongSelf->isReadyForTCPTransmit = YES;
        }];
        isStart = YES;
    }else{
        //先关闭采集
//        [camera stopCapture];
        //再断开连接
        [tcpServer stopServer];
        isStart = NO;
    }
}

@end
