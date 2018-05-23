//
//  JGTCPClient.m
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import "JGTCPClient.h"

#define WELCOME_MSG 0
#define ECHO_MSG    1
#define READ_TIMEOUT 15.0

#define TCP_HEAD_LENGTH 8


typedef enum {
    JGProtocoType_Header,
    JGProtocoType_Msg,
    JGProtocoType_Data
}JGProtocoType;

@interface JGTCPClient()<GCDAsyncSocketDelegate>
@property (strong, nonatomic) GCDAsyncSocket *socket;
@property (strong, nonatomic) dispatch_queue_t socketqueue;
@property (assign, nonatomic) JGProtocoType currentPacketType;
@property (nonatomic,strong) dispatch_source_t heartbeatTimer;
@property (nonatomic,assign) NSUInteger heartbeatPacketCount;
@end

@implementation JGTCPClient

-(instancetype)init{
    if(self = [super init]){
        _socketqueue = dispatch_queue_create("com.jimmygao.socketqueue", NULL);
        _socket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:_socketqueue];
    }
    return self;
}

-(void)dealloc{
    
    dispatch_source_cancel(_heartbeatTimer);
    _heartbeatTimer = nil;
    
    if([_socket isConnected]){
        [_socket disconnect];
    }
    _socketqueue = nil;
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

//client到server的消息直接发"字符串\r\n"
- (void)sendMsg:(NSString *)msg{

    NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    NSData *endData = [GCDAsyncSocket CRLFData];
    NSMutableData *packetData = [NSMutableData data];
    [packetData appendData:msgData];
    [packetData appendData:endData];
    
    NSLog(@"client info: send msg:%@",msg);
    [_socket writeData:packetData withTimeout:-1 tag:0];
}

- (BOOL)startTCPConnectionWithHost:(NSString*)host onPort:(uint16_t)port error:(NSError **)errPtr{
    NSLog(@"client: start connect to server:%@:%d...",host,port);
    return [_socket connectToHost:host onPort:port error:errPtr];
}

    
- (void)stopTCPConnection{
    if(_socket.isConnected){
        [_socket disconnect];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    
    _currentPacketType = JGProtocoType_Header;
    
    NSLog(@"client: did connected to %@:%d",host,port);
//    NSLog(@"client: start read welcome message...");
//    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:WELCOME_MSG];
    
    NSLog(@"start read msg from server...");
#ifdef TEST
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
#else
    //连接成功后开始读数据
    [sock readDataToLength:TCP_HEAD_LENGTH withTimeout:-1 tag:0];
    //连接成功后开始发送心跳包
    [self startHeartBeat];
#endif
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{

#ifdef TEST
    msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"test client: recive from android:%@ ",msg);
    NSString *replyMsg = [NSString stringWithFormat:@"I recive your message:%@",msg];
    NSData *replyData = [replyMsg dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *completeReplyData = [[NSMutableData alloc]init];
    [completeReplyData appendData:replyData];
    [completeReplyData appendData:[GCDAsyncSocket CRLFData]];
    [sock writeData:completeReplyData withTimeout:-1 tag:0];
#else
    
    
    if(_currentPacketType == JGProtocoType_Header){
        //前四个字节为消息类型
        uint32_t pHeader;
        [data getBytes:&pHeader length:sizeof(uint32_t)];
       
        //后四个字节为数据包长度
        uint32_t packetLength;
        [data getBytes:&packetLength range:NSMakeRange(sizeof(uint32_t), sizeof(uint32_t))];
//        NSData *headerData = [data subdataWithRange:NSMakeRange(0, 2*sizeof(uint32_t))];
//        NSData *packetData = [data subdataWithRange:NSMakeRange(2*sizeof(uint32_t), packetLength)];
//        NSLog(@"client: receive packet: header:%d,dataLenth:%d, %@",pHeader,packetLength,headerData);
        NSLog(@"client: msg type: %c,receive content length = %u, header data = %@，",(char)pHeader,packetLength,data);
        switch (pHeader) {
            case 'm':
                _currentPacketType = JGProtocoType_Msg;
                break;
            case 'd':
                _currentPacketType = JGProtocoType_Data;
                break;
            default:
                //                NSLog(@"client: receive error data from server");
                break;
        }
        [sock readDataToLength:packetLength withTimeout:-1 tag:0];
        
        return;
    }else if (_currentPacketType == JGProtocoType_Data){
        
        [self.delegate didReceiveVideoData:data];
        
    }else if (_currentPacketType == JGProtocoType_Msg){
        [self processReceivedMsgPacket:data]; //to do
    }
    _currentPacketType = JGProtocoType_Header;
    [sock readDataToLength:TCP_HEAD_LENGTH withTimeout:-1 tag:0];
#endif
}

- (void)processReceivedMsgPacket:(NSData *)data{
    
    NSString *msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"client info: receive msg: %@",msg);
    if([msg isEqualToString:kHeartBeat]){
        self.heartbeatPacketCount++;
    }else{
        [self.delegate didReceiveMsg:msg];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
//    NSLog(@"client info: did write msg");
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"client info: did disconnect:%@",err);
    if(err.code == 7){
        //服务端主动断开客户端的socket，socket can closed by remote peer; error cdoe = 7;
        [self stopTCPConnection];
    }else if(err.code == 61){
        //服务端socket主动断开，还未监听，连接会出现这个错误Code=61 "Connection refused"
    }
}

- (void)processHeartbeatPacket{
    static int i = 0;
    i++;
    if(i == 10){ //每10s读取一次心跳包个数
        
        NSUInteger count = self.heartbeatPacketCount;
        NSLog(@"client info: 最近10秒收到%lu个心跳包",(unsigned long)count);
        if((count<5) && (count>0)){
            NSLog(@"client info : 网络不稳定，请靠近一点");
        }else if(count == 0){
            NSLog(@"client info: 没有收到来自服务端的心跳包");
            [self.delegate didReceiveMsg:@"need reconnect"];

        }
        self.heartbeatPacketCount = 0;
        i = 0;
    }
}
@end
