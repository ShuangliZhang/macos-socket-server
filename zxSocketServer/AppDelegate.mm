
#import <opencv2/core.hpp>
#import "AppDelegate.h"
#include <iostream>
#include "ARSimpleMap.h"
#include "fileIO.h"
#include <vector>
#include <Eigen/Core>

using namespace std;


#import "FileTransferFormat.h"


NSInteger socket_message_state = -1;
BOOL have_read_the_message = false;
NSData *received_message_data = NULL;
BOOL processing_file = false;
int max_byte_transfer = 1024;
@interface AppDelegate()

@property (nonatomic) FileTransferFormat *mySender;

@end

@implementation AppDelegate


@synthesize status;
@synthesize port;
@synthesize host;
@synthesize window = _window;
@synthesize socket;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    port.stringValue = @"10086";
}
-(void)addText:(NSString *)str
{
    status.string = [status.string stringByAppendingFormat:@"%@\n",str];
}
#pragma -mark ----------socket----------

- (IBAction)registration:(id)sender {
    NSLog(@"test");
    ARSimpleMap mymap;
    cv::Mat rt;
    mymap.computeTransform("/Users/hzzhangshuangli/Documents/keyframe/2017-09-21 14_34_41",
                           "/Users/hzzhangshuangli/Documents/keyframe/2017-09-21 14_33_22", rt);
    cout << rt;
}

- (IBAction)listen:(id)sender {
    NSLog(@"listen");
    //在这里获取应用程序Documents文件夹里的文件及文件夹列表
    self.mySender = [FileTransferFormat alloc];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDir = [documentPaths objectAtIndex:0];
    NSError *error = nil;
    NSArray *fileList = [[NSArray alloc] init];
    //fileList便是包含有该文件夹下所有文件的文件名及文件夹名的数组
    
    fileList = [fileManager contentsOfDirectoryAtPath:@"/Users/hzzhangshuangli/Downloads/" error:&error];
    
        
    NSMutableArray *dirArray = [[NSMutableArray alloc] init];
    BOOL isDir = NO;
    //在上面那段程序中获得的fileList中列出文件夹名
    for (NSString *file in fileList) {
        NSString *path = [documentDir stringByAppendingPathComponent:file];
        
        [fileManager fileExistsAtPath:path isDirectory:(&isDir)];
        //if (isDir)
        if ([file.pathExtension compare:@"dmg" options:NSCaseInsensitiveSearch] == NSOrderedSame)   //指定扩展名
        {
            NSString *theFileName = [[file lastPathComponent] stringByDeletingPathExtension];  //stringByDeletingPathExtension去掉扩展名  lastPathComponent文件名
            [dirArray addObject:theFileName];
        }
        isDir = NO;
    }
    NSLog(@"Every Thing in the dir:%@",fileList);
    NSLog(@"All folders:%@",dirArray);
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
    
    NSUInteger index = 0;
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

    }
//    return data;
}

-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *receive = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
 //   [self addText:[NSString stringWithFormat:@"%@:%@",sock.connectedHost,receive]];
    received_message_data = data;
    have_read_the_message = false;
    NSString *reply = [NSString stringWithFormat:@"%@:%@",sock.connectedHost,receive];
  //  NSLog(s.connectedHost);
  //  NSLog(sock.connectedHost);
    if (s_ocp && [s.connectedHost isEqualToString:sock.connectedHost]) {
        //NSLog(s.connectedHost);
        //[s writeData:[reply dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        if (!processing_file && [self.mySender convertMsgToInt:receive] == REQUEST_REGISTRATION) {
            processing_file = true;
            NSLog(@"receive REQUEST_REGISTRATION");
            dispatch_queue_t queue = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                dispatch_async(queue,//dispatch_get_main_queue(),
                ^{
                       [self.mySender receiveAndSaveFileswithSender:s withFolder:@"/Users/hzzhangshuangli/Downloads/"];
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