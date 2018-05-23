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

@property (nonatomic,strong) dispatch_source_t heartbeatTimer;
@property (nonatomic,assign) NSUInteger heartbeatPacketCount;
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
    dispatch_source_cancel(_heartbeatTimer);
    _heartbeatTimer = nil;
    
    [self stopServer];
    
    if([_socket isConnected]){
        [_socket disconnect];
    }
    _socketQueue = nil;
    _socket = nil;
}

- (void)startHeartBeat {
    if (self.heartbeatTimer) {
        return;
    }
    
    //后台模式支持
    self.heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    dispatch_source_set_timer(self.heartbeatTimer, DISPATCH_TIME_NOW, 1.0f * NSEC_PER_SEC, 0);
    __weak typeof(self) weak_self = self;
    dispatch_source_set_event_handler(self.heartbeatTimer, ^{
        [weak_self sendMsg:kHeartBeat];
        [weak_self processHeartbeatPacket];
    });
    dispatch_resume(self.heartbeatTimer);
}

- (void)startServerWithReturnSignal:(ReturnReadySingalBlock)isReady{
    
    self.readyBlock = isReady;
    
    NSError *error = nil;
    if(![self.socket acceptOnPort:MY_PORT error:&error]){
        NSLog(@"error: %@,%@,%s",error,NSStringFromClass([self class]),__FUNCTION__);
        return;
    }else{
        NSLog(@"server: start listening on port :%d...",MY_PORT);
     
//        [self.socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
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

- (void)sendMsg:(NSString *)msg{
    JG_ProtocolHeader protocolHeader;
    uint32_t headerLen = sizeof(protocolHeader);
    memset((void *)&protocolHeader, 0, headerLen);
    
    NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    protocolHeader.header = 'm';
    protocolHeader.dataLength = (uint32_t)[msgData length];
    NSData *protocalData = [NSData dataWithBytes:&protocolHeader length:headerLen];
    
    NSMutableData *packetData = [NSMutableData data];
    [packetData appendData:protocalData];
    [packetData appendData:msgData];
    
    NSLog(@"server: send msg: header:%d,%@, content:%lu,",headerLen,protocalData,(unsigned long)msgData.length);
    [[self.clientSockets objectAtIndex:0] writeData:packetData withTimeout:-1 tag:0];
}

#pragma mark GCDAsynSocketDelegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket{
    if(self.readyBlock){
        self.readyBlock(YES);
    }
    
    [self.clientSockets removeAllObjects];
    [self.clientSockets addObject:newSocket];
    
    NSString *clientIP = [newSocket connectedHost];
    UInt16 clientPort = [newSocket connectedPort];
    NSLog(@"server: accept new connect from host : %@:%d ",clientIP,clientPort);
    
    [[self.clientSockets objectAtIndex:0] readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    NSLog(@"server: start read data...");
    //在接收到连接后就开启心跳包
    [self startHeartBeat];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
  
    //去掉\r\n
    NSData *msgData = [data subdataWithRange:NSMakeRange(0, data.length-2)];
    NSString *receiveMsg = [[NSString alloc]initWithData:msgData encoding:NSUTF8StringEncoding];
    
    if([receiveMsg isEqualToString:kHeartBeat]){
        self.heartbeatPacketCount++;
    }else{
        [self.delegate didReceiveMsgFromClient:receiveMsg];
    }
    NSLog(@"server info : receive msg from client :%@",receiveMsg);
    [[self.clientSockets objectAtIndex:0] readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{

}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err{
    NSLog(@"server info: %s,%@",__FUNCTION__,err);
}

- (void)processHeartbeatPacket{
    static int i = 0;
    i++;
    if(i == 10){ //每10s读取一次心跳包个数
        
        NSUInteger count = self.heartbeatPacketCount;
        NSLog(@"server info: 最近10秒收到%lu个心跳包",(unsigned long)count);
        if((count<5) && (count>0)){
            NSLog(@"server info : 网络不稳定，请靠近一点");
        }else if(count == 0){
            NSLog(@"server info: 没有收到来自客户端的心跳包");
        }
        self.heartbeatPacketCount = 0;
        i = 0;
    }
}
@end
