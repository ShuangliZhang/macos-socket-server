//
//  AppDelegate.m
//  zxSocketServer
//
//  Created by 张 玺 on 12-3-24.
//  Copyright (c) 2012年 张玺. All rights reserved.
//

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