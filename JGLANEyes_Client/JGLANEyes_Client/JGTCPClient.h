//
//  JGTCPClient.h
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
//#define TEST
typedef enum {
    JGControlTypeCapture,
    JGControlTypeSwitchCamera
}JG_ControlType;

//client to server
#define kChangeResolution @"ChangeResolution"
#define kStartOrStop      @"StartOrStop"

//server to client
#define kStartVideoTransfer @"StartVideoTransfer"
#define kStopVideoTransfer @"StopVideoTransfer"
/*****消息头
                        |header| datalength|
                           4        4
***/


typedef struct protocolHeader{
    uint8_t header;   //'m', 'd'
    uint32_t dataLength;
}JG_ProtocolHeader;

@protocol JGTCPClientReceiveDelegate <NSObject>
@optional
- (void)didReceiveVideoData:(NSData *)data;
- (void)didReceiveMsg:(NSString *)str;
@end


@interface JGTCPClient : NSObject

@property (weak, nonatomic) id<JGTCPClientReceiveDelegate> delegate;

- (BOOL)startTCPConnectionWithHost:(NSString*)host onPort:(uint16_t)port error:(NSError **)errPtr;
- (void)stopTCPConnection;

- (void)sendMsg:(NSString *)msg;
@end
