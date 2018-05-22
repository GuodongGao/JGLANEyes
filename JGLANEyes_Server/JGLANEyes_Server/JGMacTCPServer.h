//
//  JGMacTCPServer.h
//  JGLANEyes_Server
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket/GCDAsyncSocket.h"

#define MY_PORT 20001
//client to server
#define kChangeResolution @"ChangeResolution"
#define kStartOrStop      @"StartOrStop"

//server to client
#define kStartVideoTransfer @"StartVideoTransfer"
#define kStopVideoTransfer @"StopVideoTransfer"
typedef struct protocolHeader{
    uint32_t header;   //'m', 'd'
    uint32_t dataLength;
}JG_ProtocolHeader;


typedef void (^ReturnReadySingalBlock) (BOOL isReady);

@protocol JGMacTCPServerDelegate<NSObject>
- (void)didReceiveMsgFromClient:(NSString *)msg;
@end

@interface JGMacTCPServer : NSObject

@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, copy) ReturnReadySingalBlock readyBlock;
@property (nonatomic, weak) id<JGMacTCPServerDelegate> delegate;

- (void)startServerWithReturnSignal:(ReturnReadySingalBlock)isReady;
- (void)stopServer;

- (void)transimitVideoDataToClientWithData:(NSData *)data;
- (void)sendMsg:(NSString *)msg;
@end
