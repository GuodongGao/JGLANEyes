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
@end

@implementation JGTCPClient

-(instancetype)init{
    if(self = [super init]){
        _socketqueue = dispatch_queue_create("com.jimmygao.socketqueue", NULL);
        _socket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:_socketqueue];
    }
    return self;
}

- (BOOL)startTCPConnectionWithHost:(NSString*)host onPort:(uint16_t)port error:(NSError **)errPtr{
    NSLog(@"client: start connect to server:%@:%d...",host,port);
    return [_socket connectToHost:host onPort:port error:errPtr];
}

- (void)stopTCPConnection{
    
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port{
    
    _currentPacketType = JGProtocoType_Header;
    
    NSLog(@"client: did connected to %@:%d",host,port);
//    NSLog(@"client: start read welcome message...");
//    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:WELCOME_MSG];
    
    NSLog(@"start read msg from server...");
    [sock readDataToLength:TCP_HEAD_LENGTH withTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    NSString *msg = nil;
//    if(tag == WELCOME_MSG){
//        msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
//        NSLog(@"client: did readed welcome message:%@",msg);
//        NSString *str = @"Hi, my friends\r\n";
//        NSLog(@"client: start write echo msg: %@...",str);
//        [sock writeData:[str dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:ECHO_MSG];
//    }
//    if(tag == ECHO_MSG){
//        msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
//        NSLog(@"client: did read echo msg:%@",msg);
//    }
    
    
    
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
        [self processMsgPacket:data]; //to do
    }
    _currentPacketType = JGProtocoType_Header;
    [sock readDataToLength:TCP_HEAD_LENGTH withTimeout:-1 tag:0];
    
}

- (void)processMsgPacket:(NSData *)data{
    
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag{
    if(tag == ECHO_MSG){
        NSLog(@"client: did write echo msg");
        NSLog(@"client: start read echo msg");
        [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:ECHO_MSG];
    }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
}
@end
