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

typedef struct protocolHeader{
    uint32_t header;   //'m', 'd'
    uint32_t dataLength;
}JG_ProtocolHeader;


typedef void (^ReturnReadySingalBlock) (BOOL isReady);

@interface JGMacTCPServer : NSObject

@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, copy) ReturnReadySingalBlock readyBlock;

- (void)startServerWithReturnSignal:(ReturnReadySingalBlock)isReady;
- (void)stopServer;
- (void)transimitVideoDataToClientWithData:(NSData *)data;

@end
