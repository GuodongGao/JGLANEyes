//
//  JGMacH264HardwareEncoder.h
//  JGLANEyes_Server
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

typedef void (^ReturnDataBlock) (NSData *encodedData);

@interface JGMacH264HardwareEncoder : NSObject

@property (assign, nonatomic, readonly) int width;
@property (assign, nonatomic, readonly) int height;
@property (assign, nonatomic) int fps;  //todo
@property (assign, nonatomic) int bitrate; //todo

@property (nonatomic, copy) ReturnDataBlock returnDataBlock;

- (void)prepareEncoderWithWidth:(int)width andHeight:(int)height;
- (void)tearDownEncoder;

- (void)resetEncoderWithWidth:(int)width andHeight:(int) height;

- (void)pushFrame:(CMSampleBufferRef)buffer andReturnedEncodedData:(ReturnDataBlock)block;
@end
