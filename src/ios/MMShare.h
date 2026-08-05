#import <Cordova/CDVPlugin.h>
#import <MessageUI/MessageUI.h>

@interface MMShare : CDVPlugin <MFMailComposeViewControllerDelegate>

- (void)share:(CDVInvokedUrlCommand*)command;

@end
