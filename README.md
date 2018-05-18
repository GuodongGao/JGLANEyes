
## Realtime Video Transfer base on LAN(local area network)


### Mac Server:
1. Use AVFoundation to capture raw video data
2. Use VideoToolBox to encoder as h264 stream
3. Use GCDAsyncSocket to transmit simple encapsulated packets 

### Client :
1. Use GCDAsyncSocket to receive packets and decapsulate packet; 
2. Use VideoToolBox to decoder as h264 data to raw data
3. Use  OpenGL ES to render raw data to screen

 Reference：https://github.com/AmoAmoAmo/
