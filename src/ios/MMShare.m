#import "MMShare.h"

@interface MMShare ()

@property (nonatomic, copy) NSString* pendingCallbackId;

@end

@implementation MMShare

- (void)share:(CDVInvokedUrlCommand*)command
{
    NSString* message = [command.arguments objectAtIndex:0];
    NSString* subject = [command.arguments objectAtIndex:1];
    NSArray* toEmails = [command.arguments objectAtIndex:2];
    NSArray* filesArray = [command.arguments objectAtIndex:3];

    if (![message isKindOfClass:[NSString class]]) {
        message = @"";
    }
    if (![subject isKindOfClass:[NSString class]]) {
        subject = @"";
    }
    if (![toEmails isKindOfClass:[NSArray class]]) {
        toEmails = @[];
    }
    if (![filesArray isKindOfClass:[NSArray class]]) {
        filesArray = @[];
    }

    if (![MFMailComposeViewController canSendMail]) {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                      messageAsString:@"There are no email clients installed."];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }

    self.pendingCallbackId = command.callbackId;

    MFMailComposeViewController* mailComposer = [[MFMailComposeViewController alloc] init];
    mailComposer.mailComposeDelegate = self;
    [mailComposer setToRecipients:toEmails];
    [mailComposer setSubject:subject];
    [mailComposer setMessageBody:message isHTML:NO];

    for (NSDictionary* fileObj in filesArray) {
        if (![fileObj isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString* fileName = fileObj[@"fileName"];
        NSString* base64Data = fileObj[@"base64"];
        NSString* mimeType = fileObj[@"mimeType"];
        if (![mimeType isKindOfClass:[NSString class]] || mimeType.length == 0) {
            mimeType = @"application/octet-stream";
        }

        if (![fileName isKindOfClass:[NSString class]] || ![base64Data isKindOfClass:[NSString class]]) {
            continue;
        }

        NSData* decodedData = [self decodeBase64:base64Data];
        if (!decodedData || decodedData.length == 0) {
            continue;
        }

        [mailComposer addAttachmentData:decodedData mimeType:mimeType fileName:[self sanitizeFileName:fileName]];
    }

    [self.viewController presentViewController:mailComposer animated:YES completion:nil];
}

- (NSData*)decodeBase64:(NSString*)base64Data
{
    NSRange commaRange = [base64Data rangeOfString:@","];
    if (commaRange.location != NSNotFound) {
        base64Data = [base64Data substringFromIndex:(commaRange.location + 1)];
    }

    return [[NSData alloc] initWithBase64EncodedString:base64Data
                                                options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

- (NSString*)sanitizeFileName:(NSString*)fileName
{
    if (fileName.length == 0) {
        return @"attachment";
    }

    NSCharacterSet* invalidChars = [NSCharacterSet characterSetWithCharactersInString:@"<>:\"|?*\\/"];
    NSString* sanitized = [[fileName componentsSeparatedByCharactersInSet:invalidChars] componentsJoinedByString:@"_"];
    sanitized = [sanitized stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (sanitized.length == 0) {
        sanitized = @"attachment";
    }

    if (sanitized.length > 200) {
        NSString* extension = [sanitized pathExtension];
        NSString* baseName = [sanitized stringByDeletingPathExtension];
        NSInteger maxBaseLength = 200 - (extension.length > 0 ? extension.length + 1 : 0);
        if (baseName.length > maxBaseLength) {
            baseName = [baseName substringToIndex:MAX(maxBaseLength, 0)];
        }
        sanitized = extension.length > 0 ? [baseName stringByAppendingPathExtension:extension] : baseName;
    }

    return sanitized;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
           didFinishWithResult:(MFMailComposeResult)result
                         error:(NSError*)error
{
    [controller dismissViewControllerAnimated:YES completion:nil];

    CDVPluginResult* pluginResult;
    if (error) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                          messageAsString:[error localizedDescription]];
    } else if (result == MFMailComposeResultFailed) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                          messageAsString:@"Error sending email"];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                          messageAsString:@"Email sent successfully"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.pendingCallbackId];
    self.pendingCallbackId = nil;
}

@end
