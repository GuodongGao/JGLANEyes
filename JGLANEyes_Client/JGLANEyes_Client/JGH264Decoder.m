//
//  JGH264Decoder.m
//  JGLANEyes_Client
//
//  Created by mtgao on 2018/5/10.
//  Copyright © 2018年 mtgao. All rights reserved.
//

#import "JGH264Decoder.h"
@import VideoToolbox;

@interface JGH264Decoder()
{
    VTDecompressionSessionRef _session;
    CMFormatDescriptionRef _formatDescription;
    
    uint8_t *_packetBuf;
    size_t  _packetSize;
    
    uint8_t *_SPS;
    size_t  _SPSSize;
    uint8_t *_PPS;
    size_t  _PPSSize;
}
@end

@implementation JGH264Decoder

- (void)decodeVideoData:(uint8_t *)data length:(size_t)length andReturnedDecodedData:(DecodeDataBlock)block{
    self.decodedDataBlock = block;
    
    _packetBuf = data;
    _packetSize = length;
    
    [self processVideoPacket];
}

- (void)processVideoPacket{
    
    //把起始码替换为nal长度码
    uint32_t nalSize = (uint32_t)_packetSize - 4;
    uint32_t *pNalsize = (uint32_t *)_packetBuf;
    *pNalsize = CFSwapInt32HostToBig(nalSize);
    
    //第五个字节为nal类型，根据nal类型做不同处理
    CVPixelBufferRef pixelBuffer = NULL;
    int nalType = _packetBuf[4] & 0x1F;
    switch (nalType) {
        case 0x05:   //I
            NSLog(@"decoder: I frame comes");
            //拿到sps，pps，I帧后，根据参数，创建Decoder
            [self setupDecoder];
            pixelBuffer = [self decode];
            break;
        case 0x07:   //sps
             NSLog(@"decoder: sps frame comes");
            _SPSSize = _packetSize - 4;
            _SPS = malloc(_SPSSize);
            memcpy(_SPS, _packetBuf + 4, _SPSSize);
            break;
        case 0x08:   //pps
            NSLog(@"decoder: pps frame comes");
            _PPSSize = _packetSize - 4;
            _PPS = malloc(_PPSSize);
            memcpy(_PPS, _packetBuf + 4, _PPSSize);
            break;
            
        default:
            pixelBuffer = [self decode];
            break;
    }
    
    //解码后的数据传出去
    if(pixelBuffer){
        self.decodedDataBlock(pixelBuffer);
        CVPixelBufferRelease(pixelBuffer);
    }
}


- (void)setupDecoder{
    BOOL canSetupNewSession = (!_session) && _SPS && _PPS;
    if(canSetupNewSession){
        
        //包装CMVideoFormatDescription
        const uint8_t *spsppsArray[2] = {_SPS,_PPS};
        const size_t spsppsSize[2] = {_SPSSize,_PPSSize};
        OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, spsppsArray, spsppsSize, 4, &(_formatDescription));
        
        if(status == noErr){
            //配置输出的像素格式
            //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
            //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
            uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
            
            const void *key[] = { kCVPixelBufferPixelFormatTypeKey };
            const void *values[] = {CFNumberCreate(NULL, kCFNumberSInt32Type, &v)};
            CFDictionaryRef attrs = CFDictionaryCreate(NULL, key, values, 1, NULL, NULL);
            
            VTDecompressionOutputCallbackRecord callBackRecord;
            callBackRecord.decompressionOutputCallback = didDecompress;
            callBackRecord.decompressionOutputRefCon = NULL;
            //创建解码器
            status = VTDecompressionSessionCreate(NULL, _formatDescription, NULL, attrs, &callBackRecord,&_session);
            
            CFRelease(attrs);
            NSLog(@"decoder: h264 decoder setup successful!");
        }else{
            NSLog(@"error:create video format description failured");
        }
    }else{
        NSLog(@"info:don't setup new decoder:_mession = %@,sps:%s,pps:%s",_session,_SPS,_PPS);
    }
}

- (CVPixelBufferRef)decode{
    CVPixelBufferRef outputPixelBuffer = NULL;
    if(_session){
        //把压缩数据用CMBlockBuffer封装
        CMBlockBufferRef blockBuf = NULL;
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, _packetBuf, _packetSize, NULL, NULL, 0, _packetSize, 0, &blockBuf);
        
        if(status == kCMBlockBufferNoErr){
            //使用CMSampleBuffer封装videoformat和data
            CMSampleBufferRef sampleBuf = NULL;
            const size_t sampleSizeArray[] = {_packetSize};
            status = CMSampleBufferCreateReady(NULL, blockBuf, _formatDescription, 1, 0, NULL, 1, sampleSizeArray, &sampleBuf);
            
            //解码
            if(status == kCMBlockBufferNoErr && sampleBuf){
                
                //flag为0时，callback将会在decodeframe返回之前调用
                VTDecodeFrameFlags frameFlag = 0;
                VTDecodeInfoFlags decodeInfoFlag = 0;
                OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_session, sampleBuf, frameFlag, &outputPixelBuffer, &decodeInfoFlag);
                
                if(decodeStatus == kVTInvalidSessionErr) {
                    NSLog(@"error: Invalid session, reset decoder session");
                } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                    NSLog(@"error: decode failed status=%d(Bad data)", (int)decodeStatus);
                } else if(decodeStatus != noErr) {
                    NSLog(@"error: decode failed status=%d", (int)decodeStatus);
                }
            }
            CFRelease(sampleBuf);
        }
//        CFRelease(blockBuf);
    }
    return outputPixelBuffer;
}

- (void)endDecode{
    [self tearDownDecode];
}

- (void)tearDownDecode{
    if(_session) {
        VTDecompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
    
    if(_formatDescription) {
        CFRelease(_formatDescription);
        _formatDescription = NULL;
    }
    
    if(_SPS){
        free(_SPS);
    }

    if(_PPS){
        free(_PPS);
    }
    _SPSSize = _PPSSize = 0;
}

-(void)dealloc{
    [self tearDownDecode];
}

void didDecompress(
                                              void * CM_NULLABLE decompressionOutputRefCon,
                                              void * CM_NULLABLE sourceFrameRefCon,
                                              OSStatus status,
                                              VTDecodeInfoFlags infoFlags,
                                              CM_NULLABLE CVImageBufferRef imageBuffer,
                                              CMTime presentationTimeStamp,
                                              CMTime presentationDuration ){
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(imageBuffer);
}
@end
