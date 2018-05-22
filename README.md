
## Realtime Video Transfer base on LAN(local area network)

### Usage:
1. Share Mac network such as hot spot
2. Connect iphone to the network which your mac shared, such as hot spot.
3. Open 'Terminal' and input 'ifconfig' to get Server IP.  The inet of 'bridge100' is the server ip;
4. Instead the '#define SERVER_IP @"192.168.3.1"' as the Server IP of yours;


### Mac Server:
1. Use AVFoundation to capture raw video data
2. Use VideoToolBox to encoder as h264 stream
3. Use GCDAsyncSocket to transmit simple encapsulated packets 

### Client :
1. Use GCDAsyncSocket to receive packets and decapsulate packet; 
2. Use VideoToolBox to decoder as h264 data to raw data
3. Use  OpenGL ES to render raw data to screen

 Reference：https://github.com/AmoAmoAmo/
