//
//  KWWeChatLogInView.h
//  KWMac
//
//  Created by 魏志强 on 16/1/21.
//  Copyright © 2016年 Kuwo Beijing Co., Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface KWWeChatLogInView : NSView
{
    IBOutlet WebView             *_webView;
    IBOutlet NSProgressIndicator *_progressIndicator;
    NSString        *_code;
    NSString        *_tokenCode;
    NSString        *_expireDate;
    NSString        *_openId;
    
    NSMutableData   *_responseData;
    NSURLConnection *_connection;
    NSString        *_newPageUrl;
}

- (void)loadUrl;

@end
