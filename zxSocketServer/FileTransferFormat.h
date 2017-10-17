//
//  FileTransferFormat.h
//  socket-client
//
//  Created by hzzhangshuangli on 2017/9/27.
//  Copyright © 2017年 hzzhangshuangli. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

extern NSInteger socket_message_state;
extern BOOL have_read_the_message;
extern BOOL processing_file;
extern NSData *received_message_data;
extern int max_byte_transfer;
@interface FileTransferFormat : NSObject
typedef enum
{
    REQUEST_REGISTRATION = 0x00,
    REQUEST_REGISTRATION_ALLOWED = 0x01,
    REQUEST_REGISTRATION_DENY = 0x02,
    FILE_ONE_END_HERE = 0x10,
    FILE_ALL_END_HERE = 0x11,
    PROCESS_REGISTRATION_FINISHED = 0x20,
    RECEIVED_MARKER = 0x30
}StateMessages;

@property (nonatomic) bool timeOut;
@property (nonatomic) float timerWaiting;

- (NSString*) convertMsgToString:(StateMessages) messageID;
- (StateMessages) convertMsgToInt:(NSString *)messageText;

- (bool)sendRegistrationRequestwithSender:(GCDAsyncSocket *)sender withFiles:(NSArray *) files;
- (bool)receiveAndSaveFileswithSender:(GCDAsyncSocket *)sender withFolder:(NSString *)folder;

@end
