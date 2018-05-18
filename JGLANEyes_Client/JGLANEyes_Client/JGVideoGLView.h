//
//  JGVideoGLView.h
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/15.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JGVideoGLView : UIView

- (void)setupGLView;
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end
