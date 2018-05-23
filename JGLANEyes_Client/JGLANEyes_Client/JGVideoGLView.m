//
//  JGVideoGLView.m
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/15.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import "JGVideoGLView.h"
@import OpenGLES;
@import AVFoundation;

#define STRINGIZE(x) #x    //加“”
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @STRINGIZE2(text)  //加@


enum{
    ATTRB_POS,
    ATTRB_TEXCOORD,
    NUM_ATTRIBUTES
};

enum{
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};

// Color Conversion Constants (YUV to RGB) including adjustment from 16-235/16-240 (video range)
// 颜色转换常数（YUV到RGB）包括16-235 / 16-240调整（视频系列）

// BT.601, which is the standard for SDTV.
__unused static const GLfloat kColorConversion601[] = {
    1.164,  1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813,   0.0,
};

// BT.709, which is the standard for HDTV.
static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
const GLfloat kColorConversion601FullRange[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};


@interface JGVideoGLView ()
{

    EAGLContext *_context;
    CVOpenGLESTextureCacheRef _videoTextureCache;
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    
    GLint _backingWidth;  //当前view的长宽
    GLint _backingHeight;
    
    GLint _inputImageWidth;  //输入纹理的长宽
    GLint _inputImageHeight;
    
    GLuint _program;
    GLuint _vShader;
    GLuint _fShader;
    
    GLint attributes[NUM_ATTRIBUTES];
    GLint uniforms[NUM_UNIFORMS];
    
    GLuint _frameBufferHandle;
    GLuint _renderBufferHandle;
    
    const GLfloat *_preferredConversion;
    
    JGFillMode _fillMode;
    
    GLfloat imageVertices[8];
}

@end

@implementation JGVideoGLView

#pragma mark Initialize
+ (Class)layerClass{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame{
    if(self = [super initWithFrame:frame]){
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder{
    if(self = [super initWithCoder:aDecoder]){
        [self commonInit];
    }
    return self;
}

- (void)commonInit{
    //scale和屏幕的保持一致，point(logical coordinate) to pixel(device coordinate)的scale系数
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    
    //设置layer的渲染属性
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking :@(NO),
                                     kEAGLColorFormatRGBA8 : kEAGLColorFormatRGBA8};
    
    //初始化context,并设置context
    _context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if(_context && [EAGLContext setCurrentContext:_context]){
        [self loadProgram];  //加载着色器
    }else{
        NSLog(@"glview error: 创建上下文失败");
    }
    
    _preferredConversion = kColorConversion709;
    _fillMode = JGFillMode_AspectRatio;
}

#pragma mark Setup
- (void)setupGLView{

    [EAGLContext setCurrentContext:_context];
    [self setupBuffers];
    [self loadProgram];
    
    glUseProgram(_program);
    
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    
    //创建一个Core Video texture cache优化从pixelbuffer到video texutre的转换
    if(!_videoTextureCache){
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if(err != noErr){
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
}

#pragma mark Display
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer  // ---- pixelBuffer:解码后的视频数据 ----
{
    CVReturn err;
    if (pixelBuffer != NULL) {

        if (!_videoTextureCache) {
            NSLog(@"No video texture cache");
            return;
        }
        if ([EAGLContext currentContext] != _context) {
            [EAGLContext setCurrentContext:_context];
        }
        
        [self cleanUpTextures];

        int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);

        CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
        if (colorAttachments == kCVImageBufferYCbCrMatrix_ITU_R_601_4) {
            _preferredConversion = kColorConversion601FullRange;
        }
        else {
            _preferredConversion = kColorConversion709;
        }
        
        _inputImageWidth = frameWidth;
        _inputImageHeight = frameHeight;
        
        // Y-plane.
        glActiveTexture(GL_TEXTURE0);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_LUMINANCE,
                                                           frameWidth,
                                                           frameHeight,
                                                           GL_LUMINANCE,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &_lumaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        // UV-plane.
        glActiveTexture(GL_TEXTURE1);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _videoTextureCache,
                                                           pixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_LUMINANCE_ALPHA,
                                                           frameWidth / 2,
                                                           frameHeight / 2,
                                                           GL_LUMINANCE_ALPHA,
                                                           GL_UNSIGNED_BYTE,
                                                           1,
                                                           &_chromaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glBindFramebuffer(GL_FRAMEBUFFER, _renderBufferHandle);
        
        glViewport(0, 0, _backingWidth, _backingHeight);   //750 * 1334
    }
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);  //背景为黑色
    glClear(GL_COLOR_BUFFER_BIT);
    
    // 使用着色器
    glUseProgram(_program);
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    
    // 计算顶点坐标位置
    [self calculateVertexPoint];
    glVertexAttribPointer(ATTRB_POS, 2, GL_FLOAT, 0, 0, imageVertices);
    glEnableVertexAttribArray(ATTRB_POS);
    
    GLfloat quadTextureData[] =  { // 正常坐标
        1, 0,
        0, 0,
        1, 1,
        0, 1
    };
    
    glVertexAttribPointer(ATTRB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData);
    glEnableVertexAttribArray(ATTRB_TEXCOORD);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _frameBufferHandle);
    
    if ([EAGLContext currentContext] == _context) {
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
}

- (void)calculateVertexPoint{
    
    CGFloat widthScaling, heightScaling;
    
    CGSize currentViewSize = CGSizeMake(_backingWidth, _backingHeight);
    CGRect currentViewBounds = CGRectMake(0, 0, _backingWidth, _backingHeight);
    CGSize inputImageSize = CGSizeMake(_inputImageWidth, _inputImageHeight);
    
    
    CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(inputImageSize, currentViewBounds);
    
    switch (_fillMode) {
        case JGFillMode_Stretch:
        {
            widthScaling = 1.0;
            heightScaling = 1.0;
        }
            break;
        case JGFillMode_AspectRatio:
        {
            widthScaling = insetRect.size.width / currentViewSize.width;
            heightScaling = insetRect.size.height / currentViewSize.height;
        }
            break;
        case JGFillMode_AspectFillRatio:
        {
            widthScaling = currentViewSize.height / insetRect.size.height;
            heightScaling = currentViewSize.width / insetRect.size.width;
        }
            break;
    }
    
    imageVertices[0] = -widthScaling;
    imageVertices[1] = -heightScaling;
    imageVertices[2] = widthScaling;
    imageVertices[3] = -heightScaling;
    imageVertices[4] = -widthScaling;
    imageVertices[5] = heightScaling;
    imageVertices[6] = widthScaling;
    imageVertices[7] = heightScaling;
}

- (void)setupBuffers{
    glDisable(GL_DEPTH_TEST);
    
    glEnableVertexAttribArray(ATTRB_POS);
    glVertexAttribPointer(ATTRB_POS, 2, GL_FLOAT, GL_FALSE,  2 * sizeof(GLfloat), 0);
    
    glEnableVertexAttribArray(ATTRB_TEXCOORD);
    glVertexAttribPointer(ATTRB_TEXCOORD, 2, GL_FLOAT, GL_FALSE,  2 * sizeof(GLfloat), 0);
    
    glGenFramebuffers(1, &_frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBufferHandle);
    
    glGenRenderbuffers(1, &_renderBufferHandle);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBufferHandle);
    
    //把CAEAGLayer的绘制buffer绑定给渲染管线的renderbuffer句柄
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
   
    //把renderbuffer 附着到framebuffer的GL_COLOR_ATTACHMENT0位置
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBufferHandle);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }
}

- (void)dealloc{

    [self cleanUpTextures];
    if(_videoTextureCache){
        CFRelease(_videoTextureCache);
    }
    
    [self destoryBuffers];
}

- (void)destoryBuffers{

    [EAGLContext setCurrentContext:_context];
    
    if(_frameBufferHandle){
        glDeleteFramebuffers(1, &_frameBufferHandle);
        _frameBufferHandle = 0;
    }
    
    if(_renderBufferHandle){
        glDeleteRenderbuffers(1, &_renderBufferHandle);
        _renderBufferHandle = 0;
    }
}

- (void)cleanUpTextures{
    if(_lumaTexture){
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    if(_chromaTexture){
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
    
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}

- (void)loadProgram{
    //创建，编译两个着色器
    [self loadVertexShaderString:kJGVertexShaderString fragmentShaderString:kJGYUVFullRangeConversionFragmentShaderString];
    
    //创建program
    _program = glCreateProgram();
    
    //将两个着色器附着在program上
    glAttachShader(_program, _vShader);
    glAttachShader(_program, _fShader);
    
    //attribute在link之前必须先绑定
    glBindAttribLocation(_program, ATTRB_POS, "position");
    glBindAttribLocation(_program, ATTRB_TEXCOORD, "texCoord");
    
    //链接program
    if(![self linkProgram:_program]){
        NSLog(@"glview error: 连接program失败");
    }
    
    //获取uniform locations
    uniforms[UNIFORM_Y] = glGetUniformLocation(_program, "luminanceTexture");
    uniforms[UNIFORM_UV] = glGetUniformLocation(_program, "chrominanceTexture");
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = glGetUniformLocation(_program, "colorConversionMatrix");

}

- (void)loadVertexShaderString:(NSString *)vShaderString fragmentShaderString:(NSString *)fShaderString{
    //创建并编译顶点着色器
    if(![self compileShader:&_vShader type:GL_VERTEX_SHADER string:vShaderString]){
        NSLog(@"glview error: 创建顶点着色器失败");
    }
    
    //创建并编译片段着色器
    if(![self compileShader:&_fShader type:GL_FRAGMENT_SHADER string:fShaderString]){
        NSLog(@"glview error: 创建片段着色器失败");
    }
}

- (BOOL)linkProgram:(GLuint)program{
    GLint status;
    glLinkProgram(program);
    
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if(status != GL_TRUE){
        GLint logLength;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
        if(logLength > 0){
            GLchar *log = (GLchar *)malloc(logLength);
            glGetProgramInfoLog(program, logLength, &logLength, log);
            NSLog(@"glview error: program链接失败，\n%s",log);
            free(log);
        }
        glDeleteProgram(program);
    }
    
    return status == GL_TRUE;
}

- (BOOL)compileShader: (GLuint *)shader type:(GLenum)type string:(NSString *)shaderString{
    
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[shaderString UTF8String];
    if (!source) {
        NSLog(@"glview error: 加载shader失败");
    }
    //创建，编译shader
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if(status != GL_TRUE){
        GLint logLength;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
        if(logLength > 0){
            GLchar *log = (GLchar *)malloc(logLength);
            glGetShaderInfoLog(*shader, logLength, &logLength, log);
            NSLog(@"glview error: shader 编译失败：\n%s",log);
            free(log);
        }
        glDeleteShader(*shader);
    }
    
    return status == GL_TRUE;
}

NSString *const kJGVertexShaderString = SHADER_STRING(
      attribute vec4 position;
      attribute vec4 texCoord;
      
      varying vec2 inputTextureCoord;
      void main(){
          
          float preferredRotation = 3.14;
          mat4 rotationMatrix = mat4( cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,
                                     sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,
                                     0.0,                        0.0, 1.0, 0.0,
                                     0.0,                        0.0, 0.0, 1.0);
          gl_Position = rotationMatrix * position;
          
     
          inputTextureCoord = texCoord.xy;
      }
);

NSString *const kJGYUVFullRangeConversionFragmentShaderString = SHADER_STRING(
                                                                              
      varying highp vec2 inputTextureCoord;
      
      uniform sampler2D luminanceTexture;
      uniform sampler2D chrominanceTexture;
      uniform mediump mat3 colorConversionMatrix;
                                                                              
      void main(){
          
          mediump vec3 yuv;
          lowp vec3 rgb;
          
          yuv.x = texture2D(luminanceTexture,inputTextureCoord).r;
          yuv.yz = texture2D(chrominanceTexture,inputTextureCoord).ra - vec2(0.5,0.5);
          rgb = colorConversionMatrix * yuv;
          
          gl_FragColor = vec4(rgb,1);
      }
                                                                              
);

NSString *const kJGYUVVidoeRangeConversionFragmentShaderString = SHADER_STRING(
                                                                               
       varying highp vec2 inputTextureCoord;
       
       uniform sampler2D luminanceTexture;
       uniform sampler2D chrominanceTexture;
       uniform mediump mat3 colorConversionMatrix;
       
       void main(){

           mediump vec3 yuv;
           lowp vec3 rgb;
           
           yuv.x = texture2D(luminanceTexture,inputTextureCoord).r - (16.0/255.0);
           yuv.yz = texture2D(chrominanceTexture,inputTextureCoord).ra - vec2(0.5,0.5);
           rgb = colorConversionMatrix * yuv;
           
           gl_FragColor = vec4(rgb,1);
       }
);

NSString *const kJGFragmentShaderString = SHADER_STRING(
                                                        
        varying highp vec2 inputTextureCoord;
        uniform sampler2D inputImageTexture;
        
        void main(){
            gl_FragColor = texture2D(inputImageTexture,inputTextureCoord);
        }
);
@end
