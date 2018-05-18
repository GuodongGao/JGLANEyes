//
//  JGMacCamera.h
//  JGLANEyes_Server
//
//  Created by mtgao on 2018/5/9.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AppKit;
@import AVFoundation;

typedef void (^ReturnedSampleBuffer) (CMSampleBufferRef samplebuffer);

@interface JGMacCamera : NSObject

@property (copy, nonatomic) ReturnedSampleBuffer sample;
- (instancetype)initWithPreset:(NSString *)preset;

- (void)displayOnView:(NSView *)view;
- (void)startCaptureAndOutputSampleBuffer:(ReturnedSampleBuffer)sampleBuffer;
- (void)stopCapture;

@end
