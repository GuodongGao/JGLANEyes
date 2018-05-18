//
//  ViewController.m
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#define SERVER_IP @"192.168.2.1"
#define SERVER_PORT 20001

#import "ViewController.h"
#import "JGH264Decoder.h"
#import "JGVideoGLView.h"
#import "JGTCPClient.h"

@interface ViewController ()<JGTCPClientReceiveDelegate>
@property (weak, nonatomic) IBOutlet UILabel *lblBirate;
@property (nonatomic,strong) JGVideoGLView *glView;
@property (nonatomic,strong) JGH264Decoder *decoder;
@property (nonatomic,strong) JGTCPClient *tcpClient;
@property (nonatomic,strong) dispatch_source_t oneSecondsTimer;

@property (nonatomic, assign) NSUInteger dataBytes;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    //设置display View
    self.glView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height/2);
    [self.view addSubview:self.glView];
    [self.glView setupGLView];
    
    //初始化decoder
    self.decoder = [[JGH264Decoder alloc]init];
    
    //初始化client
    self.tcpClient = [[JGTCPClient alloc]init];
    self.tcpClient.delegate = self;
    
    NSError *error = nil;
    [self.tcpClient startTCPConnectionWithHost:SERVER_IP onPort:SERVER_PORT error:&error];
    if(error){
        NSLog(@"error:startTcpConnection With Host error");
    }
    NSLog(@"size of int = %lu",sizeof(int));
    
    self.oneSecondsTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(self.oneSecondsTimer, DISPATCH_TIME_NOW,  1.0f * NSEC_PER_SEC, 0);
    __weak typeof(self) weak_self = self;
    dispatch_source_set_event_handler(self.oneSecondsTimer, ^{
        weak_self.lblBirate.text = [weak_self stringToShowWithByteSize:weak_self.dataBytes];
        weak_self.dataBytes = 0;
    });
    dispatch_resume(self.oneSecondsTimer);

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
    [self.decoder decodeVideoData:(uint8_t*)data.bytes length:data.length andReturnedDecodedData:^(CVPixelBufferRef buffer) {
        [self.glView displayPixelBuffer:buffer];
    }];
}
@end
