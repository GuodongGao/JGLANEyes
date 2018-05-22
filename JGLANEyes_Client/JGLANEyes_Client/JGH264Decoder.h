//
//  JGH264Decoder.h
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

typedef void (^DecodeDataBlock) (CVPixelBufferRef buffer);

@interface JGH264Decoder : NSObject
@property (nonatomic, copy) DecodeDataBlock decodedDataBlock;

- (void)decodeVideoData:(uint8_t *)data length:(size_t)length andReturnedDecodedData:(DecodeDataBlock)block;
- (void)endDecode;
- (void)resetDecode; // called when resolution changed;
@end
