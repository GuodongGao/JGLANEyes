//
//  ViewController.m
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#define SERVER_IP @"192.168.3.1"
#define SERVER_PORT 20001

#define Test_IP @"172.20.65.205"
#define Test_PORT 9999


#import "ViewController.h"
#import "JGH264Decoder.h"
#import "JGVideoGLView.h"
#import "JGTCPClient.h"

@interface ViewController ()<JGTCPClientReceiveDelegate>
//显示
@property (weak, nonatomic) IBOutlet UILabel *lblBirate;
@property (weak, nonatomic) IBOutlet UILabel *lblMsg;
@property (weak, nonatomic) IBOutlet UILabel *lblState;
@property (weak, nonatomic) IBOutlet UIButton *btnStartOrStop;

//成员
@property (nonatomic,strong) JGVideoGLView *glView;
@property (nonatomic,strong) JGH264Decoder *decoder;
@property (nonatomic,strong) JGTCPClient *tcpClient;

//统计
@property (nonatomic,strong) dispatch_source_t oneSecondsTimer;
@property (nonatomic, assign) NSUInteger dataBytes;
@property (nonatomic, assign) size_t width;
@property (nonatomic, assign) size_t height;
@property (nonatomic, assign) NSUInteger fps;
@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];

    //设置display View
    self.glView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width);
    [self.view addSubview:self.glView];
    [self.glView setupGLView];
    
    //初始化decoder
    self.decoder = [[JGH264Decoder alloc]init];
    
    //初始化client
    self.tcpClient = [[JGTCPClient alloc]init];
    self.tcpClient.delegate = self;

    
    self.oneSecondsTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(self.oneSecondsTimer, DISPATCH_TIME_NOW,  1.0f * NSEC_PER_SEC, 0);
    __weak typeof(self) weak_self = self;
    dispatch_source_set_event_handler(self.oneSecondsTimer, ^{
        weak_self.lblBirate.text = [weak_self stringToShowWithByteSize:weak_self.dataBytes];
        weak_self.dataBytes = 0;
        
        weak_self.lblState.text = [NSString stringWithFormat:@"Res(%lu,%lu),fps:%ld",weak_self.width,weak_self.height,weak_self.fps];
        weak_self.fps = 0;
        weak_self.width = 0;
        weak_self.height = 0;
    });
    dispatch_resume(self.oneSecondsTimer);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification object:nil]; //监听是否触发home键挂起程序，（把程序放在后台执行其他操作）
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil]; //监听是否重新进入程序程序.（回到程序)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil]; //监听是否重新进入程序程序.（回到程序)
}

-(void)applicationWillResignActive:(NSNotification *)notification{
    NSLog(@"viewcontroller info :%s",__FUNCTION__);
}

-(void)applicationDidBecomeActive:(NSNotification *)notification{
    NSLog(@"viewcontroller info :%s",__FUNCTION__);
   //进入前台，先要重启解码器
    [self.decoder resetDecode];
    //然后重连
    [self reconnect];
}
-(void)applicationDidEnterBackground:(UIApplication *)application{
    NSLog(@"viewcontroller info :%s",__FUNCTION__);
}

- (NSString *)stringToShowWithByteSize:(NSUInteger)byteSize {
    NSString *resultString = @"";
    CGFloat resultKB = byteSize / 1024;
    CGFloat resultMB = resultKB / 1024;
    CGFloat resultGB = resultMB / 1024;
    
    if (resultGB >= 1) {
        resultString = [NSString stringWithFormat:@"%.1fGB/s", resultGB];
    } else if (resultMB >= 1) {
        resultString = [NSString stringWithFormat:@"%.1fMB/s", resultMB];
    } else {
        resultString = [NSString stringWithFormat:@"%ldKB/s", (long)resultKB];
    }
    return resultString;
}

-(JGVideoGLView *)glView
{
    if (!_glView) {
        _glView = [[JGVideoGLView alloc] init];
    }
    return _glView;
}

- (void)didReceiveVideoData:(NSData *)data{
    self.dataBytes += data.length;
    
    __weak typeof(self) weak_self = self;
    [self.decoder decodeVideoData:(uint8_t*)data.bytes length:data.length andReturnedDecodedData:^(CVPixelBufferRef buffer) {
        
        size_t width = CVPixelBufferGetWidth(buffer);
        size_t height = CVPixelBufferGetHeight(buffer);
        NSStringFromCGSize(CGSizeMake(width, height));
        weak_self.fps ++;
        weak_self.width = width;
        weak_self.height = height;
        
        [self.glView displayPixelBuffer:buffer];
    }];
}

- (void)didReceiveMsg:(NSString *)str{
    NSLog(@"client: receive msg:%@",str);
    if([str isEqualToString:kChangeResolution]){
        [self.decoder resetDecode];
    }else if([str isEqualToString:kStartVideoTransfer]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.btnStartOrStop setTitle:@"start transport" forState:UIControlStateNormal];
        });
        
    }else if([str isEqualToString:kStopVideoTransfer]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.btnStartOrStop setTitle:@"stop transport" forState:UIControlStateNormal];
        });
    }else if([str isEqualToString:@"need reconnect"]){
        //重连
        [self reconnect];
    }else{
        NSLog(@"client error: receive undefined msg;");
    }
}

- (void)reconnect{
    //todo：重连逻辑判定要根据心跳判断网络以及重连次数
    NSError *error = nil;
    [self.tcpClient stopTCPConnection];
    [self.tcpClient startTCPConnectionWithHost:SERVER_IP onPort:SERVER_PORT error:&error];
    if(error){
        NSLog(@"error:startTcpConnection With Host error");
    }
    NSLog(@"client info: reconnect...");
}
//控制
- (IBAction)changeFillMode:(id)sender {
    static int count = 0;
    self.glView.fillMode = (JGFillMode)count;
    count ++;
    if(count == 3){
        count = 0;
    }
}
- (IBAction)changeResulotion:(id)sender {
    [self.tcpClient sendMsg:kChangeResolution];
}

- (IBAction)startOrStopControl:(id)sender {
    [self.tcpClient sendMsg:kStartOrStop];
}

- (IBAction)startConnectToServer:(id)sender {
    
    static BOOL isConnected = NO;
    NSError *error = nil;
#ifdef TEST
    [self.tcpClient startTCPConnectionWithHost:Test_IP onPort:Test_PORT error:&error];
#else
    if(!isConnected){
        [self.tcpClient startTCPConnectionWithHost:SERVER_IP onPort:SERVER_PORT error:&error];
        if(error){
            NSLog(@"error:startTcpConnection With Host error");
        }
        isConnected = YES;
    }else{
        [self.tcpClient stopTCPConnection];
        isConnected = NO;
    }
#endif
}

@end
