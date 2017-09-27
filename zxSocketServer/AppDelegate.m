#import "AppDelegate.h"

@implementation AppDelegate


@synthesize status;
@synthesize port;
@synthesize host;
@synthesize window = _window;
@synthesize socket;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    port.stringValue = @"1234";
}
-(void)addText:(NSString *)str
{
    status.string = [status.string stringByAppendingFormat:@"%@\n",str];
}
- (IBAction)listen:(id)sender {
    NSLog(@"listen");
    s_ocp = false;
    s1_ocp = false;
    s_file_trans_mark = false;
    socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *err = nil; 
    if(![socket acceptOnPort:[port integerValue] error:&err]) 
    { 
        [self addText:err.description];
    }else
    {
        [self addText:[NSString stringWithFormat:@"开始监听%d端口.",port.integerValue]];
    }
}

- (void)socket:(GCDAsyncSocket *)sender didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // The "sender" parameter is the listenSocket we created.
    // The "newSocket" is a new instance of GCDAsyncSocket.
    // It represents the accepted incoming client connection.
    
    // Do server stuff with newSocket...
    [self addText:[NSString stringWithFormat:@"建立与%@的连接",newSocket.connectedHost]];
    
    if (!s_ocp) {
        s = newSocket;
        s.delegate = self;
        [s readDataWithTimeout:-1 tag:0];
        s_ocp = true;
    }
    else
    {
        s1 = newSocket;
        s1.delegate = self;
        [s1 readDataWithTimeout:-1 tag:0];
        s1_ocp = true;
    }
    
}

-(void)sendTxtFile:(NSString *)filename withSender:(GCDAsyncSocket *)sender
{
    NSString *content = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL];
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    int index = 0;
    int totalLen = [content length];
 //   NSData *piece = buffer;
    uint8_t *readBytes = (uint8_t *)[data bytes];
    
    while (index < totalLen) {
        //if ([outputStream hasSpaceAvailable]) {
        int indexLen =  256;
        NSRange first4k = {index, MIN([data length]-index, indexLen)};
        NSData *piece =[data subdataWithRange:first4k];
    //        (void)memcpy(buffer, readBytes, indexLen);
          s_received_mark = false;
            [sender writeData:piece withTimeout:1 tag:0];
//            int written = [outputStream write:buffer maxLength:indexLen];
//
//            if (written < 0) {
//                break;
//            }
      
        index += indexLen;
        while (!s_received_mark)
        {}
        
    
        //}
    }
//    return data;
}

-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *receive = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self addText:[NSString stringWithFormat:@"%@:%@",sock.connectedHost,receive]];
    
    NSString *reply = [NSString stringWithFormat:@"%@:%@",sock.connectedHost,receive];
    NSLog(s.connectedHost);
    NSLog(sock.connectedHost);
    if (s_ocp && [s.connectedHost isEqualToString:sock.connectedHost]) {
        NSLog(s.connectedHost);
        [s writeData:[reply dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        s_received_mark = true;
        if (!s_file_trans_mark ) {
            s_file_trans_mark = true;
            dispatch_queue_t queue = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                dispatch_async(queue,//dispatch_get_main_queue(),
                               ^{
                                   [self sendTxtFile:@"/Users/hzzhangshuangli/Documents/test.txt" withSender:s];
                               });
            });
        }
        if (s1_ocp) {
            [s1 writeData:[reply dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        }
    }
    else if (s1_ocp && [s1.connectedHost isEqualToString:sock.connectedHost]) {
        [s writeData:[reply dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    }
    if (s_ocp) {
        [s readDataWithTimeout:-1 tag:0];
    }
    if (s1_ocp) {
        [s1 readDataWithTimeout:-1 tag:0];
    }
    
}
@end
