//
//  JGMacTCPServer.m
//  JGLANEyes_Server
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import "JGMacTCPServer.h"

#define WELCOME_MSG 0
#define ECHO_MSG    1
#define READ_TIMEOUT 15.0

@interface JGMacTCPServer()<GCDAsyncSocketDelegate>
@property (nonatomic, strong) dispatch_queue_t socketQueue;
@property (nonatomic, strong) NSMutableArray <GCDAsyncSocket *> *clientSockets;
@end

@implementation JGMacTCPServer

- (instancetype)init{
    if(self = [super init]){
        self.socketQueue = dispatch_queue_create("tcp_socketQueue", NULL);
        self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue];
        
        self.clientSockets = [[NSMutableArray alloc]init];
    }
    return self;
}
- (void)dealloc{
    [self stopServer];
}


- (void)startServerWithReturnSignal:(ReturnReadySingalBlock)isReady{
    
    self.readyBlock = isReady;
    
    NSError *error = nil;
    if(![self.socket acceptOnPort:MY_PORT error:&error]){
        NSLog(@"error: %@,%@,%s",error,NSStringFromClass([self class]),__FUNCTION__);
        return;
    }else{
        NSLog(@"server: start listening on port :%d...",MY_PORT);
    }
}

- (void)stopServer{
    for (GCDAsyncSocket *clientSocket in self.clientSockets){
        [clientSocket disconnect];
    }
    [self.socket disconnect];
}


- (void)transimitVideoDataToClientWithData:(NSData *)data{
    
    JG_ProtocolHeader protocolHeader;
    uint32_t headerLen = sizeof(protocolHeader);
    memset((void *)&protocolHeader, 0, headerLen);

    protocolHeader.header = 'd';
    protocolHeader.dataLength = (uint32_t)[data length];
    NSData *protocolData = [NSData dataWithBytes:&protocolHeader length:headerLen];

    NSMutableData *videoData = [NSMutableData data];
    [videoData appendData:protocolData];
    [videoData appendData:data];
    
    NSLog(@"server: send packet :header:%d,%@, content:%lu",headerLen,protocolData, (unsigned long)data.length);
    [[self.clientSockets objectAtIndex:0] writeData:videoData withTimeout:-1 tag:0];
}

#pragma mark GCDAsynSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    if(self.readyBlock){
        self.readyBlock(YES);
    }
    [self.clientSockets addObject:newSocket];
    
    NSString *clientIP = [newSocket connectedHost];
    UInt16 clientPort = [newSocket connectedPort];
    NSLog(@"server: accept new connect from host : %@:%d ",clientIP,clientPort);
    
    
//    NSString *welcomeMsg = @"Welcome to the AsyncSocket Echo Server\r\n";
//    NSData *welcomeData = [welcomeMsg dataUsingEncoding:NSUTF8StringEncoding];
//    NSLog(@"server: start write welcome message...");
//    [newSocket writeData:welcomeData withTimeout:-1 tag:WELCOME_MSG];
//    NSLog(@"%@,%s",NSStringFromClass([self class]),__FUNCTION__);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    NSLog(@"%@,%s",NSStringFromClass([self class]),__FUNCTION__);

    if(tag == ECHO_MSG){
        NSString *msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"server: did read echo msg : %@",msg);
        NSString *echo1 = @"hi,how are you?\r\n";
        NSLog(@"server: start write echo message...:%@",echo1);
        NSData *echodata = [echo1 dataUsingEncoding:NSUTF8StringEncoding];
        [sock writeData:echodata  withTimeout:-1 tag:ECHO_MSG];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    // Echo message back to client
    if (tag == ECHO_MSG)
    {
        NSLog(@"server: did write echo message...");
    }
    if (tag == WELCOME_MSG){
        NSLog(@"server: did write welcome message");
        NSLog(@"server: start waiting for reading echo message...");
        [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:ECHO_MSG];
    }
    NSLog(@"%@,%s",NSStringFromClass([self class]),__FUNCTION__);
}
@end
