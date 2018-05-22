//
//  JGPushSession.h
//  JGLANEyes_Server
//
//  Created by mtgao on 2018/5/21.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface JGPushSession : NSObject
@property (nonatomic, copy) NSString *sessionPreset;

- (instancetype)initWithSessionPreset:(NSString *)sessionPreset;

- (void)startCapture;
- (void)stopCapture;

- (void)startPushSession;
- (void)stopPushSession;
@end
