//
//  JGTCPClient.h
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

typedef enum {
    JGControlTypeCapture,
    JGControlTypeSwitchCamera
}JG_ControlType;


/*****消息头
                        |header| datalength|
                           1        4
***/


typedef struct protocolHeader{
    uint8_t protocolHeader;   //'m', 'd'
    uint32_t dataLength;
}JG_ProtocolHeader;

@protocol JGTCPClientReceiveDelegate <NSObject>
@optional
- (void)didReceiveVideoData:(NSData *)data;
@end


@interface JGTCPClient : NSObject

@property (weak, nonatomic) id<JGTCPClientReceiveDelegate> delegate;

- (BOOL)startTCPConnectionWithHost:(NSString*)host onPort:(uint16_t)port error:(NSError **)errPtr;
- (void)stopTCPConnection;
@end
