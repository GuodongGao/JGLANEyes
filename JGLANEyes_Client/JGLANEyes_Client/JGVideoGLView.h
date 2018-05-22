//
//  JGVideoGLView.h
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/15.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, JGFillMode) {
    JGFillMode_AspectRatio,         //default
    JGFillMode_Stretch,
    JGFillMode_AspectFillRatio,
};

@interface JGVideoGLView : UIView
@property (assign, nonatomic) JGFillMode fillMode;

- (void)setupGLView;
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end
