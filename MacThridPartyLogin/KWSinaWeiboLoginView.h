//
//  KWSinaWeiboLoginView.h
//  KWMac
//
//  Created by 魏志强 on 16/1/25.
//  Copyright © 2016年 Kuwo Beijing Co., Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface KWSinaWeiboLoginView : NSView
{
    IBOutlet WebView *_webView;
    IBOutlet NSProgressIndicator *_progressIndicator;
    NSString        *_code;
    NSString        *_tokenCode;
    NSString        *_expireDate;
    NSString        *_openId;
    
//    NSMutableData   *_responseData;
//    NSURLConnection *_connection;
//    NSString        *_newPageUrl;
}

//@property(nonatomic, copy) void (^LoginSuccess)(NSDictionary* result);
//@property(nonatomic, copy) void (^LoginFailure)();

- (void)loadUrl;

@end
