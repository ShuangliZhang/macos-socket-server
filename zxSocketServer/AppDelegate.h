#import <Cocoa/Cocoa.h>
#import "GCDAsyncSocket.h"

@interface AppDelegate : NSObject <NSApplicationDelegate,GCDAsyncSocketDelegate>
{
    GCDAsyncSocket *socket;
    GCDAsyncSocket *s;
    GCDAsyncSocket *s1;
    bool s_ocp;
    bool s_received_mark;
    bool s_file_trans_mark;
    bool s1_ocp;
}
@property(strong)  GCDAsyncSocket *socket;


- (IBAction)listen:(id)sender;
@property (unsafe_unretained) IBOutlet NSTextView *status;
@property (unsafe_unretained) IBOutlet NSTextField *port;
@property (unsafe_unretained) IBOutlet NSTextField *host;


@property (assign) IBOutlet NSWindow *window;

@end
