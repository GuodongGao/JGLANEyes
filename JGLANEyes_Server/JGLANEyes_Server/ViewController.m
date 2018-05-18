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

@implementation ViewController
{
    JGMacCamera *camera;
    JGMacH264HardwareEncoder *videoEncoder;
    JGMacTCPServer *tcpServer;
    
    __block BOOL isReadyForTCPTransmit;
    
    NSFileHandle *filehandle;  //写裸流文件用于测试
}

- (NSString *)getFilehandle{
    NSArray* documentsArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documents = documentsArray.firstObject;
    NSString* tmpPath = [documents stringByAppendingPathComponent:@"裸流.h264"];
    NSLog(@"tmpPath = %@",tmpPath);
    [[NSFileManager defaultManager] createFileAtPath:tmpPath contents:nil attributes:nil];
    return tmpPath;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //获取裸流文件句柄
    filehandle = [NSFileHandle fileHandleForWritingAtPath:[self getFilehandle]];

    //初始化相机
    camera = [[JGMacCamera alloc]initWithPreset:AVCaptureSessionPreset1280x720];
    
    //初始化编码器
    videoEncoder = [[JGMacH264HardwareEncoder alloc]init];
    [videoEncoder prepareEncoderWithWidth:1280 andHeight:720];
    
    //初始化服务器
    tcpServer = [[JGMacTCPServer alloc]init];
    
    __weak typeof(self) weakSelf = self;
    //启动服务器
    [tcpServer startServerWithReturnSignal:^(BOOL isReady) {
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf->isReadyForTCPTransmit = YES;
    }];
    
    //开始捕捉图像
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
    
    //显示在屏幕上
    [camera displayOnView:self.view];
}

- (IBAction)StopCapture:(id)sender {
    [camera stopCapture];
    [filehandle closeFile];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    // Update the view, if already loaded.
}


@end
