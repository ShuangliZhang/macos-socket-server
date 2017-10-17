//
//  FileTransferFormat.m
//  socket-client
//
//  Created by hzzhangshuangli on 2017/9/27.
//  Copyright © 2017年 hzzhangshuangli. All rights reserved.
//

#import "FileTransferFormat.h"
@implementation FileTransferFormat

//REQUEST_REGISTRATION_ = 0x00,
//REQUEST_REGISTRATION_ALLOWED = 0x01,
//REQUEST_REGISTRATION_DENY = 0x02,
//FILE_ONE_END_HERE = 0x10,
//FILE_ALL_END_HERE = 0x20,
//PROCESS_REGISTRATION_FINISHED = 0xA0
//RECEIVED_MARKER
- (NSString*) convertMsgToString:(StateMessages) messageID
{
    switch (messageID) {
        case REQUEST_REGISTRATION:
            return @"RequestRegistration";
            break;
        case REQUEST_REGISTRATION_ALLOWED:
            return @"RequestRegistrationAllowed";
            break;
        case REQUEST_REGISTRATION_DENY:
            return @"RequestRegistrationDeny";
            break;
        case FILE_ONE_END_HERE:
            return @"FileOneEndHere";
            break;
        case FILE_ALL_END_HERE:
            return @"FileAllEndHere";
            break;
        case PROCESS_REGISTRATION_FINISHED:
            return @"ProcessRegistrationFinished";
            break;
        case RECEIVED_MARKER:
            return @"ReceivedMarker";
            break;
        default:
            break;
    }
}

- (StateMessages) convertMsgToInt:(NSString *)messageText
{
    if ([messageText isEqualToString:@"RequestRegistration"]) {
        return REQUEST_REGISTRATION;
    }
    if ([messageText isEqualToString:@"RequestRegistrationAllowed"]) {
        return REQUEST_REGISTRATION_ALLOWED;
    }
    if ([messageText isEqualToString:@"RequestRegistrationDeny"]) {
        return REQUEST_REGISTRATION_DENY;
    }
    if ([messageText isEqualToString:@"FileOneEndHere"]) {
        return FILE_ONE_END_HERE;
    }
    if ([messageText isEqualToString:@"FileAllEndHere"]) {
        return FILE_ALL_END_HERE;
    }
    if ([messageText isEqualToString:@"ProcessRegistrationFinished"]) {
        return PROCESS_REGISTRATION_FINISHED;
    }
    if ([messageText isEqualToString:@"ReceivedMarker"]) {
        return RECEIVED_MARKER;
    }
    return -1;
}

- (bool)sendRegistrationRequestwithSender:(GCDAsyncSocket *)sender withFiles:(NSArray *) files
{
    // send request
    NSString *msgRequest = [self convertMsgToString:REQUEST_REGISTRATION];
    self.timerWaiting = 10.0;
    NSLog(@"send request");
    bool result = [self sendRequestwithSender:sender withData:[msgRequest dataUsingEncoding:NSUTF8StringEncoding] withGoal:REQUEST_REGISTRATION_ALLOWED];
    if (!result) {
        NSLog(@"REQUEST_REGISTRATION_DENY error");
        return false;
    }
    self.timerWaiting = 2.0;
    // send frame number
    NSString *msgFileNumber = [NSString stringWithFormat: @"%i", [files count]];
    result = [self sendRequestwithSender:sender withData:[msgFileNumber dataUsingEncoding:NSUTF8StringEncoding] withGoal:RECEIVED_MARKER];
    
    if (!result) {
        NSLog(@"Fail to send message file number");
        return false;
    }
    
    // send files
    for (NSString *file in files) {
        result = [self sendRequestwithSender:sender withData:[file dataUsingEncoding:NSUTF8StringEncoding] withGoal:RECEIVED_MARKER];
        if (!result) {
            NSLog(@"Fail to send message %@", file);
            return false;
        }
        NSString *theFileName = [file lastPathComponent];
        [self sendFilewithSender:sender withFiles:theFileName];
    }
    
    // send EOF of all
    NSString *msgEOF = [self convertMsgToString:FILE_ALL_END_HERE];
    result = [self sendRequestwithSender:sender withData:[msgEOF dataUsingEncoding:NSUTF8StringEncoding] withGoal:REQUEST_REGISTRATION_ALLOWED];
    if (!result) {
        NSLog(@"FILE_ALL_END_HERE error");
        return false;
    }
    
    return true;
}

-(bool)sendFilewithSender:(GCDAsyncSocket *)sender withFiles:(NSString *)filename
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
        index += indexLen;
        bool result = [self sendRequestwithSender:sender withData:piece withGoal:RECEIVED_MARKER];
        if (!result) {
            NSLog(@"Fail to send piece of file %@", filename);
            return false;
        }
    }
    NSString *msgEnd = [self convertMsgToString:FILE_ONE_END_HERE];
    bool result = [self sendRequestwithSender:sender withData:[msgEnd dataUsingEncoding:NSUTF8StringEncoding] withGoal:RECEIVED_MARKER];
    if (!result) {
        NSLog(@"Fail to send EOF of file %@", filename);
        return false;
    }
    return true;
}

- (void)myTimer
{
    double delayInSeconds = self.timerWaiting;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        self.timeOut = true;
    });
}

- (bool)sendRequestwithSender:(GCDAsyncSocket *)sender withData:(NSData *)data withGoal:(StateMessages) idealBack
{
 //   NSInteger
    socket_message_state = -1;
    self.timeOut = false;
    NSLog([[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]);
    [sender writeData:data withTimeout:-1 tag:0];
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(myTimer) object:nil];
    [thread start];
    
    while (!self.timeOut && socket_message_state!= idealBack) {
        continue;
    }
    if (self.timeOut) {
        NSLog(@"warning: Failed, timeOut during data sending, state = %i", socket_message_state);
        return false;
    }
    return true;
}

- (bool)receiveAndSaveFileswithSender:(GCDAsyncSocket *)sender withFolder:(NSString *)folder;
{
    NSString *msgRequestAllow = [self convertMsgToString:REQUEST_REGISTRATION_ALLOWED];
    NSString *msgReceive = [self convertMsgToString:RECEIVED_MARKER];
    have_read_the_message = true;
    [sender writeData:[msgRequestAllow dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    
    NSInteger fileNumber;
    while (have_read_the_message) {
        
    }
    if (!have_read_the_message) {
        NSString *fileNum = [[NSString alloc]initWithData:received_message_data encoding:NSUTF8StringEncoding];
        fileNumber = [fileNum integerValue];
        NSLog(@"%i files will be sent, %@", fileNumber, fileNum);
    }
    have_read_the_message = true;
    [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    while (have_read_the_message) {
        
    }
    
    for (int i = 0; i<fileNumber; i++) {
        NSString *filename;
        if (!have_read_the_message) {
            filename = [[NSString alloc]initWithData:received_message_data encoding:NSUTF8StringEncoding];
        }
        NSLog(@"receiving: %@", filename);
        NSString *filePath = [folder stringByAppendingPathComponent:filename];
        
        if ([[filename pathExtension] isEqualToString:@"txt"]) {
            [self writeTextFile:filePath withSender:sender];
        }
        
        if ([[filename pathExtension] isEqualToString:@"jpg"]) {
            [self writeImageFile:filePath withSender:sender];
        }

        NSLog(@"write file end");
        have_read_the_message = true;
        [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        while (have_read_the_message) {
            
        }
        
        if ([self convertMsgToInt:[[NSString alloc]initWithData:received_message_data encoding:NSUTF8StringEncoding]] == FILE_ALL_END_HERE) {
            break;
        }
    }
    
    while (have_read_the_message) {
        
    }
    
    if (!have_read_the_message) {
        have_read_the_message = true;
        [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
        if ([self convertMsgToInt:[[NSString alloc]initWithData:received_message_data encoding:NSUTF8StringEncoding]] == FILE_ALL_END_HERE) {
            NSLog(@"WRITE END SUCCESSFULLY");
        }
    }
    NSLog(@"write end");
    processing_file = false;
    
    
    return true;
}

- (bool)writeTextFile:(NSString *)filePath withSender:(GCDAsyncSocket *)sender
{
    int totalByte = 0;
    NSString *msgReceive = [self convertMsgToString:RECEIVED_MARKER];
    NSMutableData *text = [NSMutableData data];
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
//    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
    have_read_the_message = true;
    bool file_end_mark = false;
    
    [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    
    if ([received_message_data length] < max_byte_transfer ) {
        file_end_mark = true;
    }
    
    while (have_read_the_message) {
        
    }    
    
    while (true) {
        totalByte = totalByte +[received_message_data length];
        NSLog(@"write piece %i, %i", [received_message_data length], totalByte);
        if (!have_read_the_message) {
            have_read_the_message = true;
            if (file_end_mark) {
                if ([self convertMsgToInt:[[NSString alloc]initWithData:received_message_data encoding:NSUTF8StringEncoding]] == FILE_ONE_END_HERE) {
                    break;
                }
                else
                {
                    NSLog(@"fake end marker");
                    file_end_mark = false;
                }
            }
            [text appendData:received_message_data];
            [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
            if ([received_message_data length] < max_byte_transfer ) {
                file_end_mark = true;
            }
        }
        while (have_read_the_message) {
            
        }
    }
    NSData *textAll = [text copy];
    [textAll writeToFile: filePath atomically: NO];
    
    return true;
}


- (bool)writeImageFile:(NSString *)filePath withSender:(GCDAsyncSocket *)sender
{
    int totalByte = 0;
    NSString *msgReceive = [self convertMsgToString:RECEIVED_MARKER];
    NSMutableData *image = [NSMutableData data];
    have_read_the_message = true;
    bool file_end_mark = false;
    
    [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    
    if ([received_message_data length] < max_byte_transfer ) {
        file_end_mark = true;
    }
    
    while (have_read_the_message) {
        
    }
    
    while (true) {
        totalByte = totalByte +[received_message_data length];
        NSLog(@"write piece %i, %i", [received_message_data length], totalByte);
        if (!have_read_the_message) {
            have_read_the_message = true;
            if (file_end_mark) {
                if ([self convertMsgToInt:[[NSString alloc]initWithData:received_message_data encoding:NSUTF8StringEncoding]] == FILE_ONE_END_HERE) {
                    break;
                }
                else
                {
                    NSLog(@"fake end marker");
                    file_end_mark = false;
                }
            }
            [image appendData:received_message_data];
            [sender writeData:[msgReceive dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
            if ([received_message_data length] < max_byte_transfer ) {
                file_end_mark = true;
            }
        }
        while (have_read_the_message) {
            
        }
    }
    NSData *imageAll = [image copy];
    [imageAll writeToFile: filePath atomically: NO];
    //NSImage *imgFile = [[NSImage alloc] initWithData:imageAll];
    return true;
}
@end
