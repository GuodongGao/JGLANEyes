//
//  JGMacH264HardwareEncoder.m
//  JGLANEyes_Server
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import "JGMacH264HardwareEncoder.h"
@import VideoToolbox;



@implementation JGMacH264HardwareEncoder
{
    VTCompressionSessionRef _session;
    dispatch_queue_t _queue;
}

- (instancetype)init{
    if (self = [super init]) {
        _width = 1280;
        _height = 720;
        _fps = 30;
        _bitrate = 5*1000*1000; //610kB
        
//        _queue = dispatch_queue_create("com.jimmygao.h264encoderqueue", DISPATCH_QUEUE_SERIAL);
        _session = nil;
    }
    return self;
}

- (void)prepareEncoderWithWidth:(int)width andHeight:(int)height{
 
    _width = width;
    _height = height;
    
    OSStatus status = noErr;
    //查询机器支持的编码器
    CFArrayRef ref;
    VTCopyVideoEncoderList(NULL, &ref);
    NSLog(@"encoder list = %@",(__bridge NSArray*)ref);
    CFRelease(ref);
    
    //打开视频硬编码器
    CFMutableDictionaryRef encodeSpecific = NULL;
    CFStringRef key = kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder;
    CFBooleanRef value = kCFBooleanTrue;
    CFStringRef key1 = kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder;
    CFBooleanRef value1 = kCFBooleanTrue;
    CFStringRef key2 = kVTVideoEncoderSpecification_EncoderID;
    CFStringRef value2 = CFSTR("com.apple.videotoolbox.videoencoder.h264.gva");
    
    encodeSpecific = CFDictionaryCreateMutable(NULL, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(encodeSpecific, key, value);
    CFDictionaryAddValue(encodeSpecific, key1, value1);
    CFDictionaryAddValue(encodeSpecific, key2, value2);
    
    //指定原始图像格式
    SInt32 cvPixelFormatTypeValue = k2vuyPixelFormat;
    CFDictionaryRef emptyDict = CFDictionaryCreate(kCFAllocatorDefault, nil, nil, 0, nil, nil);
    CFNumberRef cvPixelFormatType = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, (const void*)(&(cvPixelFormatTypeValue)));
    CFNumberRef frameW = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, (const void*)(&(width)));
    CFNumberRef frameH = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, (const void*)(&(height)));
    
    const void *pixelBufferOptionsDictKeys[] = { kCVPixelBufferPixelFormatTypeKey,
        kCVPixelBufferWidthKey,  kCVPixelBufferHeightKey, kCVPixelBufferIOSurfacePropertiesKey};
    const void *pixelBufferOptionsDictValues[] = { cvPixelFormatType,  frameW, frameH, emptyDict};
    CFDictionaryRef pixelBufferOptions = CFDictionaryCreate(kCFAllocatorDefault, pixelBufferOptionsDictKeys, pixelBufferOptionsDictValues, 4, nil, nil);
    
    //创建编码器
    status = VTCompressionSessionCreate(NULL, self.width, self.height, kCMVideoCodecType_H264, encodeSpecific, pixelBufferOptions, NULL, didCompressFinished, (__bridge void * _Nullable)(self), &(_session));

    CFRelease(pixelBufferOptions);
    
    if(status != noErr){
         NSLog( @"create session: resolution:(%d,%d)  fps:(%d)",self.width,self.height,self.fps);
    }
   
    if(_session){
        //检查当前是否正在使用硬编
        CFBooleanRef b = NULL;
        VTSessionCopyProperty(_session, kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder, NULL, &b);
        if (b== kCFBooleanTrue) {
            NSLog(@"Check result: Using hardware encoder now!");
        }else{
            NSLog(@"Check result: Not using hardware encoder now!");
            NSAssert(b == kCFBooleanTrue, @"Not using hardware encoder now");
        }
        
        //设置编码器属性
        status = VTSessionSetProperty(_session, kVTCompressionPropertyKey_RealTime,kCFBooleanTrue);
        status = VTSessionSetProperty(_session, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
        status = VTSessionSetProperty(_session, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CAVLC);
        status = VTSessionSetProperty(_session, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);

        
        //设置帧率
        int temp = self.fps;
        CFNumberRef refFPS = CFNumberCreate(NULL, kCFNumberSInt32Type, &temp);
        status = VTSessionSetProperty(_session, kVTCompressionPropertyKey_ExpectedFrameRate, refFPS);
        CFRelease(refFPS);

        //设置平均码率
        temp = self.bitrate;
        CFNumberRef refBitrate = CFNumberCreate(NULL, kCFNumberSInt32Type, &temp);
        VTSessionSetProperty(_session, kVTCompressionPropertyKey_AverageBitRate, refBitrate);
        CFRelease(refBitrate);

        //设置关键帧时间间隔
        temp = 1;
        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &temp);
        VTSessionSetProperty(_session, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, ref);
        CFRelease(ref);

        //最大缓冲帧数
        temp = 3;
        CFNumberRef refFrameDelay = CFNumberCreate(NULL, kCFNumberSInt32Type, &temp);
        status = VTSessionSetProperty(_session, kVTCompressionPropertyKey_MaxFrameDelayCount, refFrameDelay);
        CFRelease(refFrameDelay);

        status = VTCompressionSessionPrepareToEncodeFrames(_session);
    }
}

- (void)tearDownEncoder{
    if(_session){
        VTCompressionSessionCompleteFrames(_session, kCMTimeInvalid);
        VTCompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
        NSLog(@"%s",__FUNCTION__);
    }
}

- (void)resetEncoderWithWidth:(int)width andHeight:(int) height{
    _width = width;
    _height = height;
    
    [self tearDownEncoder];
    [self prepareEncoderWithWidth:width andHeight:height];
}

- (void)pushFrame:(CMSampleBufferRef)buffer andReturnedEncodedData:(ReturnDataBlock)block{
    
    self.returnDataBlock = block;

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer);
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(buffer);
    OSStatus status = VTCompressionSessionEncodeFrame(_session, imageBuffer, pts, kCMTimeInvalid, NULL, NULL, NULL);
    if(status != noErr){
        NSLog(@"encode frame error");
    }
}

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    //    NSLog(@"-------- 编码后SpsPps长度: gotSpsPps %d %d", (int)[sps length] + 4, (int)[pps length]+4);
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *startCode = [NSData dataWithBytes:bytes length:length];
    
    [self returnDataToTCPWithHeadData:startCode andData:sps];
    [self returnDataToTCPWithHeadData:startCode andData:pps];
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
//    NSLog(@"--------- 编码后数据长度： %d -----", (int)[data length]);
    //    NSLog(@"----------- data = %@ ------------", data);
    
    // 把每一帧的所有NALU数据前四个字节变成0x00 00 00 01之后再写入文件
    const char bytes[] = "\x00\x00\x00\x01";  // null null null 标题开始
    size_t length = (sizeof bytes) - 1; //字符串文字具有隐式结尾 '\0'  。    把上一段内容中的’\0‘去掉，
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length]; // 复制C数组所包含的数据来初始化NSData的数据
    
    [self returnDataToTCPWithHeadData:ByteHeader andData:data];
}

-(void)returnDataToTCPWithHeadData:(NSData*)headData andData:(NSData*)data
{
//    printf("---- video 编码后的数据data大小 = %d + %d \n",(int)[headData length] ,(int)[data length]);
    NSMutableData *tempData = [NSMutableData dataWithData:headData];
    [tempData appendData:data];
    
    // 传给socket
    if (self.returnDataBlock) {
        self.returnDataBlock(tempData);
    }
}

void didCompressFinished(
                         void * CM_NULLABLE outputCallbackRefCon,
                         void * CM_NULLABLE sourceFrameRefCon,
                         OSStatus status,
                         VTEncodeInfoFlags infoFlags,
                         CM_NULLABLE CMSampleBufferRef sampleBuffer ){
    
    if(status != 0){
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    
    JGMacH264HardwareEncoder *encoder = (__bridge JGMacH264HardwareEncoder*)outputCallbackRefCon;
    
    //判断是否为关键帧
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    //关键帧获取sps，pps数据
    if(keyframe){
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // Found pps
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder)
                {
                    [encoder gotSpsPps:sps pps:pps];  // 获取sps & pps数据
                }
            }
        }
    }
    
    //写入数据
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            // Read the NAL unit length
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder gotEncodedData:data isKeyFrame:keyframe];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}
@end
