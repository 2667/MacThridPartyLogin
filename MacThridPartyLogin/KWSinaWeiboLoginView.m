//
//  KWSinaWeiboLoginView.m
//  KWMac
//
//  Created by 魏志强 on 16/1/25.
//  Copyright © 2016年 Kuwo Beijing Co., Ltd. All rights reserved.
//

#import "KWSinaWeiboLoginView.h"
#import "JSONKit.h"
#import "LoginInfoModel.h"
#import "KWCommonDef.h"
#import "CoreNotification.h"

#pragma mark 新浪微博登录begin
NSString* const SINA_APPID = @"2972927130";
NSString* const SINA_APPKEY = @"356ade2f59d6356aa176027850979cdb";
NSString* const SINA_REDIRECT_URL = @"http://www.kuwo.cn/";
NSString* const SINA_REDIRECT_URL_ENCODE = @"http%3a%2f%2fwww.kuwo.cn%2f";
//NSString* const SINA_REDIRECT_URL = @"https://api.weibo.com/oauth2/default.html";
//NSString* const SINA_REDIRECT_URL_ENCODE = @"https%3a%2f%2fapi.weibo.com%2foauth2%2fdefault.html";
NSString* const SINA_AUTH_CODE_URL_PREFIX = @"https://api.weibo.com/oauth2/authorize";
NSString* const SINA_ACCESS_TOKEN_URL_PREFIX = @"https://api.weibo.com/oauth2/access_token";
#pragma mark 新浪微博登录end
typedef enum _LaunchStatus
{
    LAUNCH_UNKONW = 0,
    LAUNCH_STATUS_ING = 1,
    LAUNCH_STATUS_ED = 2
}LaunchStatus;

@interface KWSinaWeiboLoginView()
{
    BOOL _bTrigLogin;
    BOOL _bTrigCancel;
    NSURLRequest* _origRequest;
    LaunchStatus _launchStatus;
}
@end

@implementation KWSinaWeiboLoginView

- (void)loadUrl
{
    //https://api.weibo.com/oauth2/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=YOUR_REGISTERED_REDIRECT_URI
    NSString *authCodeURLString;
    authCodeURLString = [NSString stringWithFormat:@"%@?client_id=%@&response_type=code&redirect_uri=%@&forcelogin=true", SINA_AUTH_CODE_URL_PREFIX, SINA_APPID, SINA_REDIRECT_URL_ENCODE];
    _origRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:authCodeURLString]];
    [[_webView mainFrame] loadRequest:_origRequest];
    
    [self updateProgress:YES];
}

#pragma mark ------  WebFrameLoadDelegate -------
/*
 - (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
 {
 NSLog(@"(void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame");
 }
 
 - (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
 {
 NSLog(@"(void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame");
 }
 
 - (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
 {
 NSLog(@"(void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame");
 }
 */

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [self updateProgress:NO];
}


/*
 - (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
 {
 NSLog(@"(void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame");
 }
 */

#pragma mark ------- WebResourceLoadDelegate Start -------

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource
{
    NSLog(@"identifierForInitialRequest request.URL.absoluteString=%@", request.URL.absoluteString);
    //https://login.sina.com.cn/sso/login.php?client=
    if(_launchStatus==LAUNCH_UNKONW || [request.URL.absoluteString containsString:@"https://api.weibo.com/oauth2/authorize?client_id="])
    {
        _launchStatus = LAUNCH_STATUS_ING;
            _origRequest = request;
    }
    else if(_launchStatus == LAUNCH_STATUS_ING && [request.URL.absoluteString containsString:@"https://api.weibo.com/oauth2/js/sso/ssologin.js?version="])
    {
        _launchStatus = LAUNCH_STATUS_ED;
    }
    if(_launchStatus==LAUNCH_STATUS_ED)
    {
        if(_bTrigLogin || [request.URL.absoluteString containsString:@"https://login.sina.com.cn/sso/login.php?client="])
        {
            _bTrigLogin = YES;
        }
        else if(_bTrigCancel || [request.URL.absoluteString containsString:@"https://api.weibo.com/oauth2/authorize"])
        {
            _bTrigCancel = YES;
        }
    }

    NSString* identifierString;
    assert(_launchStatus!=LAUNCH_UNKONW);
    if(_launchStatus>LAUNCH_UNKONW && _launchStatus<LAUNCH_STATUS_ED)
    {
        identifierString = @"launch";
    }
    else if(_bTrigLogin)
    {
        identifierString = @"login";
    }
    else if(_bTrigCancel)
    {
        identifierString = @"cancel";
    }
    else
    {
        identifierString = @"other";
    }
    
    return identifierString;
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
    ////请求
    //https://api.weibo.com/oauth2/authorize?client_id=123050457758183&redirect_uri=http://www.example.com/response&response_type=code
    //
    ////同意授权后会重定向
    //http://www.example.com/response&code=CODE
    //https://api.weibo.com/oauth2/authorize
    NSLog(@"redirectResponse identifier=%@, request.URL.absoluteString=%@", (NSString*)identifier, request.URL.absoluteString);
    if([identifier isEqualToString:@"login"] && [request.URL.absoluteString containsString:[NSString stringWithFormat:@"%@?code=", SINA_REDIRECT_URL]])
    {
        NSString * urlString = request.URL.absoluteString;
        NSRange range = [urlString rangeOfString:[NSString stringWithFormat:@"%@?", SINA_REDIRECT_URL] options:NSBackwardsSearch];
        if(range.location != NSNotFound)
        {
            NSString* retParamInfo = [urlString substringFromIndex:(range.location+range.length)];
            NSArray* arrString = [retParamInfo componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"&="]];
            NSUInteger nCodeIndex = [arrString indexOfObject:@"code"];
            if(nCodeIndex!=NSNotFound)
            {
                _code = arrString[nCodeIndex+1];
            }
            NSLog(@"the code is=[%@]", _code);
            
            [self _asyncGetAccessToken];
        }
    }
    else if([identifier isEqualToString:@"launch"])
    {
        //do nothing
    }
    else if([identifier isEqualToString:@"cancel"])
    {
        request = _origRequest;
    }
    else
    {
        //do nothing
    }
//    else if([request.URL.absoluteString containsString:[NSString stringWithFormat:@"%@?error_uri=", SINA_REDIRECT_URL]])
//    {
//        return _origRequest;
//    }
    
    return request;
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource
{
//    {
//        identifierString = @"launch";
//    }
//    else if(_bTrigLogin)
//    {
//        identifierString = @"login";
//    }
//    else if(_bCancel)
//    {
//        identifierString = @"cancel";
//    }
//    else
//    {
//        identifierString = @"other";
//        
    if([identifier isEqualToString:@"launch"])
    {
        _launchStatus = LAUNCH_STATUS_ED;
    }
//    else if([identifier isEqualToString:@"login"])
//    {
//        _bTrigLogin = NO;
//    }
    else if([identifier isEqualToString:@"cancel"])
    {
        _bTrigCancel = NO;
    }
    else if([identifier isEqualToString:@"other"])
    {
        
    }
    NSLog(@"didFinishLoadingFromDataSource is called, idenifier=%@", (NSString*)identifier);
}

- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource
{
    if([identifier isEqualToString:@"launch"])
    {
        _launchStatus = LAUNCH_STATUS_ED;
    }
    else if([identifier isEqualToString:@"login"])
    {
        _bTrigLogin = NO;
    }
    else if([identifier isEqualToString:@"cancel"])
    {
        _bTrigCancel = NO;
    }
    else if([identifier isEqualToString:@"other"])
    {
        
    }
    NSLog(@"didFailLoadingWithError is called, idenifier=%@", (NSString*)identifier);
}

#pragma mark ------- WebResourceLoadDelegate End -------



-(void) _asyncGetAccessToken
{
    NSURL *url = [NSURL URLWithString:SINA_ACCESS_TOKEN_URL_PREFIX];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setTimeoutInterval:30.0f];
    [urlRequest setHTTPMethod:@"POST"];
    //access_token=YOUR_ACCESS_TOKEN&oauth_consumer_key=YOUR_APP_ID&openid=YOUR_OPENID
    NSString *body = [NSString stringWithFormat:@"client_id=%@&client_secret=%@&grant_type=authorization_code&code=%@&redirect_uri=%@", SINA_APPID, SINA_APPKEY, _code, SINA_REDIRECT_URL_ENCODE];

    [urlRequest setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:urlRequest
                                       queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               if ([data length] >0 && error == nil){
                                      /*
                                       成功：
                                       {
                                       "access_token": "ACCESS_TOKEN",
                                       "expires_in": 1234,
                                       "remind_in":"798114",
                                       "uid":"12341234"
                                       }

                                       失败：
                                       {
                                       "error": "unsupported_response_type",
                                       "error_code": 21329,
                                       "error_description": "不支持的ResponseType."
                                       }
                                       //*/
                                       NSError *parseError = nil;
                                       id result =[data objectFromJSONDataWithParseOptions:JKParseOptionStrict error:&parseError];
                                       if(parseError)
                                       {
                                           NSDictionary *userInfo = [NSDictionary dictionaryWithObject:parseError.debugDescription forKey:KWErrorMessageKey];
                                           [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationSinaLoginDidFail object:nil userInfo:userInfo];
                                       }
                                       else
                                       {
                                           if(result[@"error_code"])
                                           {
                                               NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"登录失败" forKey:KWErrorMessageKey];
                                               [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationSinaLoginDidFail object:nil userInfo:userInfo];
                                           }
                                           else
                                           {
                                               _tokenCode = result[@"access_token"];
                                               _expireDate = [NSString stringWithFormat:@"%ld", [result[@"expires_in"] integerValue]];
                                               // _expireDate = result[@"expires_in"];
                                               _openId = result[@"uid"];
                                               [self _getUserInfo];
                                           }
                                       }
                               } else {
                                   NSString *errorString = error != nil ? error.localizedFailureReason : @"登录失败";
                                   NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorString forKey:KWErrorMessageKey];
                                   [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationSinaLoginDidFail object:nil userInfo:userInfo];
                               }
                           }];
}

-(void) _getUserInfo
{
    NSString* host;
    NSString* param;
    host = @"https://api.weibo.com/2/users/show.json";
    param = [NSString stringWithFormat:@"?source=%@&access_token=%@&uid=%@", SINA_APPKEY, _tokenCode, _openId];
    NSString* urlEncodeParam = param;
    NSString *strUrl = [host stringByAppendingString:urlEncodeParam];
    NSURL *url = [NSURL URLWithString:strUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setTimeoutInterval:30.0f];
    [urlRequest setHTTPMethod:@"GET"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest
                                       queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               if ([data length] >0 &&
                                   error == nil){
//                                   NSString *userInfo = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//                                   NSLog(@"USERInfo = %@", userInfo);
                                   [_webView setHidden:YES];
                                   NSError *parseError = nil;
                                   [data objectFromJSONDataWithParseOptions:JKParseOptionStrict error:&parseError];
                                   if(parseError)
                                   {
                                       NSDictionary *userInfo = [NSDictionary dictionaryWithObject:parseError.debugDescription forKey:KWErrorMessageKey];
                                       [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationSinaLoginDidFail object:nil userInfo:userInfo];
                                   }
                                   else
                                   {
                                       LoginInfoModel *loginInfo = [[LoginInfoModel alloc] init];
                                       loginInfo.accessToken = _tokenCode;
                                       loginInfo.tokenExpired = _expireDate;
                                       loginInfo.openId = _openId;
                                       loginInfo.loginType = LoginMethodType_LoginByWeibo;
                                       loginInfo.isPreLogin = YES;
                                       [LogInManager saveLoginInfo:loginInfo];
                                       [LogInManager sendSinaLoginRequest:_tokenCode withExpireDateString:_expireDate];
                                   }
                               } else {
                                   NSString *errorString = error != nil ? error.localizedFailureReason : @"登录失败";
                                   NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorString forKey:KWErrorMessageKey];
                                   [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationSinaLoginDidFail object:nil userInfo:userInfo];
                               }
                           }];
}

- (void)updateProgress:(BOOL)begin
{
    if (begin) {
        [_webView setHidden:YES];
        [_progressIndicator setHidden:NO];
        [_progressIndicator startAnimation:nil];
    } else {
        [_webView setHidden:NO];
        [_progressIndicator setHidden:YES];
        [_progressIndicator stopAnimation:nil];
    }
}

//- (void)revoke
//{
//    //https://api.weibo.com/oauth2/revokeoauth2
//
//    NSString* host;
//    NSString* param;
//    host = @"https://api.weibo.com/oauth2/revokeoauth2";
//    param = [NSString stringWithFormat:@"?access_token=%@", _tokenCode];
//    NSString* urlEncodeParam = param;
//    NSString *strUrl = [host stringByAppendingString:urlEncodeParam];
//    NSURL *url = [NSURL URLWithString:strUrl];
//    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
//    [urlRequest setTimeoutInterval:30.0f];
//    [urlRequest setHTTPMethod:@"GET"];
//    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
//    
//    [NSURLConnection sendAsynchronousRequest:urlRequest
//                                       queue:queue
//                           completionHandler:nil];
//
//}

@end

