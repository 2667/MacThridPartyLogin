//
//  KWWeChatLogInView.m
//  KWMac
//
//  Created by 魏志强 on 16/1/21.
//  Copyright © 2016年 Kuwo Beijing Co., Ltd. All rights reserved.
//

#import "KWWeChatLogInView.h"
#import "JSONKit.h"
#import "LoginInfoModel.h"
#import "KWCommonDef.h"
#import "CoreNotification.h"

NSString* const WECHAT_AUTH_CODE_URL_PREFIX = @"https://open.weixin.qq.com/connect/qrconnect";
NSString* const WECHAT_APPID = @"wx41c1275bb3e28427";
NSString* const WECHAT_REDIRECT_URL_ENCODE = @"i.kuwo.cn";
NSString* const WECHAT_REDIRECT_URL = @"i.kuwo.cn";
NSString* const WECHAT_ACCESS_TOKEN_URL_PREFIX = @"https://api.weixin.qq.com/sns/oauth2/access_token";
NSString* const WECHAT_APPKEY = @"8f7ef5520c4700bd74c16e04e6e21737";

@implementation KWWeChatLogInView

- (void)loadUrl
{
    NSString *authCodeURLString;
    authCodeURLString = [NSString stringWithFormat:@"%@?appid=%@&redirect_uri=%@&response_type=code&scope=snsapi_login", WECHAT_AUTH_CODE_URL_PREFIX, WECHAT_APPID, WECHAT_REDIRECT_URL_ENCODE];
    
    [[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:authCodeURLString]]];
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

#pragma mark ------- WebResourceLoadDelegate -------

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
    if([request.URL.absoluteString containsString:[NSString stringWithFormat:@"%@?code=", WECHAT_REDIRECT_URL]])
    {
        NSString * urlString = request.URL.absoluteString;
        NSRange range = [urlString rangeOfString:[NSString stringWithFormat:@"%@?", WECHAT_REDIRECT_URL] options:NSBackwardsSearch];
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
            
            NSString *tokenURLString = [NSString stringWithFormat:@"%@?appid=%@&secret=%@&code=%@&grant_type=authorization_code", WECHAT_ACCESS_TOKEN_URL_PREFIX, WECHAT_APPID, WECHAT_APPKEY, _code];
            _newPageUrl = tokenURLString;
            NSLog(@"new page url =%@", _newPageUrl);
            
            NSURLRequest* request = [[NSURLRequest alloc]initWithURL:[NSURL URLWithString:_newPageUrl]];
            _connection = [[NSURLConnection alloc]initWithRequest:request delegate:self];
        }
    }
    
    return request;
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _responseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_responseData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse
{
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
{
    [self _handleResponseData:_responseData];
    
    NSURL *curTempURL = _connection.currentRequest.URL;
    [_connection cancel];
    
    if( ! [[NSURL URLWithString:_newPageUrl] isEqual:curTempURL])
    {
        _responseData = nil;
        NSURLRequest *request = [[NSURLRequest alloc]initWithURL:[NSURL URLWithString:_newPageUrl]];
        _connection = [[NSURLConnection alloc]initWithRequest:request delegate:self];
    }
    
    //    [sinaweibo requestDidFinish:self];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
    //    [self failedWithError:error];
    
    _responseData = nil;
    
    [_connection cancel];
    
    //    [sinaweibo requestDidFinish:self];
}

#pragma mark private method
-(void)_handleResponseData:(NSData*)data
{
    NSString *aString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //access_token=C74EC56A67709C28496569BE6CA53D76&expires_in=7776000&refresh_token=65052FAD995D39D5C324C1AEE5EB08CA
    NSLog(@"the content is %@", aString);
    NSLog(@"the currentRequest.URL=%@", _connection.currentRequest.URL.path);
    if([_connection.currentRequest.URL.path compare:@"/sns/oauth2/access_token"]==NSOrderedSame)
    {
        NSLog(@"get OpenID");
        //        callback( {"client_id":"101264135","openid":"BAAF22731B85309DE13FBF3A1BF4285A"} );
        NSData *jsonData = [aString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];
        NSString* openId = dict[@"openid"];
        _tokenCode = dict[@"access_token"];
//        _expireDate = dict[@"expires_in"];
        _expireDate = [NSString stringWithFormat:@"%ld", [dict[@"expires_in"] integerValue]];
        if(openId)
        {
            _openId = openId;
            [self _getUserInfo];
        }
        else
        {
            NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"登录失败" forKey:KWErrorMessageKey];
            [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationWechatLoginDidFail object:nil userInfo:userInfo];
        }
    }
}

-(void) _getUserInfo
{
    NSString* host;
    NSString* param;
    host = @"https://api.weixin.qq.com/sns/userinfo";
    param = [NSString stringWithFormat:@"?access_token=%@&openid=%@", _tokenCode, _openId];
    
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
                                       [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationWechatLoginDidFail object:nil userInfo:userInfo];
                                   }
                                   else
                                   {
                                       LoginInfoModel *loginInfo = [[LoginInfoModel alloc] init];
                                       loginInfo.accessToken = _tokenCode;
                                       loginInfo.tokenExpired = _expireDate;
                                       loginInfo.loginType = LoginMethodType_LoginByWeixin;
                                       loginInfo.openId = _openId;
                                       loginInfo.isPreLogin = YES;
                                       [LogInManager saveLoginInfo:loginInfo];
                                       [LogInManager sendWechatLoginRequest:_tokenCode withExpireDateString:_expireDate withOpenId:_openId];
//                                       weakSelf.LoginSuccess((NSDictionary*)result);
                                   }
                               } else {
                                   NSString *errorString = error != nil ? error.localizedFailureReason : @"登录失败";
                                   NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorString forKey:KWErrorMessageKey];
                                   [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationWechatLoginDidFail object:nil userInfo:userInfo];
                               }
                           }];
}

-(NSString*)_getComponetStringValueIndexByArrayString:(NSArray*)array andKey:(NSString*)key
{
    NSUInteger valueIndex = NSNotFound;
    NSUInteger keyIndex = [array indexOfObject:key];
    if(keyIndex!=NSNotFound)
    {
        valueIndex = keyIndex+1;
        if(valueIndex<array.count)
        {
            return array[valueIndex];
        }
        else
        {
            NSLog(@"the value index is equal or larger than the container count");
            assert(false);
            return nil;
        }
    }
    return nil;
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

@end
