//
//  KWQQLogInView.m
//  KWMac
//
//  Created by 魏志强 on 16/1/20.
//  Copyright © 2016年 Kuwo Beijing Co., Ltd. All rights reserved.
//

#import "KWQQLogInView.h"
#import "JSONKit.h"
#import "LoginInfoModel.h"
#import "KWCommonDef.h"
#import "CoreNotification.h"

NSString* const QQ_AUTH_CODE_URL_PREFIX = @"https://graph.qq.com/oauth2.0/authorize?response_type=token";
NSString* const QQ_APPID = @"100243533";
NSString* const QQ_APPKEY = @"93616593bbf489cde5151687e66b5b8c";
NSString* const QQ_REDIRECT_URL_ENCODE = @"http%3a%2f%2fi.kuwo.cn%2fUS%2f2013%2fmobile%2flogin_ar_qq.htm";
NSString* const QQ_REDIRECT_URL = @"http://i.kuwo.cn/US/2013/mobile/login_ar_qq.htm";
NSString* const QQ_ACCESS_TOKEN_URL_PREFIX = @"https://graph.qq.com/oauth2.0/me";

@implementation KWQQLogInView

- (void)loadUrl
{
    NSString *authCodeURLString;
    authCodeURLString = [NSString stringWithFormat:@"%@&client_id=%@&redirect_uri=%@&scope=get_user_info,add_t,get_info,add_pic_t", QQ_AUTH_CODE_URL_PREFIX, QQ_APPID, QQ_REDIRECT_URL_ENCODE];
    
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
    if([request.URL.absoluteString containsString:[NSString stringWithFormat:@"%@?#access_token=", QQ_REDIRECT_URL]])
    {
        NSString * urlString = request.URL.absoluteString;
        NSRange range = [urlString rangeOfString:[NSString stringWithFormat:@"%@?#", QQ_REDIRECT_URL] options:NSBackwardsSearch];
        if(range.location!=NSNotFound)
        {
            NSString* retParamInfo = [urlString substringFromIndex:(range.location+range.length)];
            NSArray* arrString = [retParamInfo componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"&="]];
            NSUInteger nAccessTokenIndex = [arrString indexOfObject:@"access_token"];
            NSUInteger nExpireIndex = [arrString indexOfObject:@"expires_in"];
            if(nAccessTokenIndex!=NSNotFound && nExpireIndex!= NSNotFound)
            {
                _tokenCode = arrString[nAccessTokenIndex+1];
                _expireDate = arrString[nExpireIndex+1];
            }
            NSLog(@"the access_token=[%@], expire_in=[%@]", _tokenCode, _expireDate);
            
            NSString *tokenURLString = [NSString stringWithFormat:@"%@?access_token=%@", QQ_ACCESS_TOKEN_URL_PREFIX, _tokenCode];
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
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
    //    [self failedWithError:error];
    _responseData = nil;
    [_connection cancel];
}

#pragma mark private method
-(void)_handleResponseData:(NSData*)data
{
    NSString *aString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //access_token=C74EC56A67709C28496569BE6CA53D76&expires_in=7776000&refresh_token=65052FAD995D39D5C324C1AEE5EB08CA
    NSLog(@"the content is %@", aString);
    NSLog(@"the currentRequest.URL=%@", _connection.currentRequest.URL.path);
        if([_connection.currentRequest.URL.path compare:@"/oauth2.0/me"]==NSOrderedSame)
        {
            NSLog(@"get OpenID");
            //        callback( {"client_id":"101264135","openid":"BAAF22731B85309DE13FBF3A1BF4285A"} );
            
            NSArray* arrString = [aString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
            NSString* strJsonInfo = [self _getComponetStringValueIndexByArrayString:arrString andKey:@"callback"];
            NSData *jsonData = [strJsonInfo dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];
            NSString* openId = dict[@"openid"];
            NSString* appId = dict[@"client_id"];
            if(openId)
            {
                _openId = openId;
                [self _getUserInfo];
            }
            else
            {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"登录失败" forKey:KWErrorMessageKey];
                [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationQQLoginDidFail object:nil userInfo:userInfo];
            }
        }
}

-(void) _getUserInfo
{
    NSString* host;
    NSString* param;
    host = @"https://graph.qq.com/user/get_user_info";
    param = [NSString stringWithFormat:@"?access_token=%@&oauth_consumer_key=%@&openid=%@&format=json", _tokenCode, QQ_APPID, _openId];
    
    NSString* urlEncodeParam = param;
    NSString *strUrl = [host stringByAppendingString:urlEncodeParam];
    NSURL *url = [NSURL URLWithString:strUrl];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setTimeoutInterval:30.0f];
    [urlRequest setHTTPMethod:@"GET"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
//    __weak typeof(self) weakSelf = self;
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
                                       [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationQQLoginDidFail object:nil userInfo:userInfo];
                                   }
                                   else
                                   {
                                       LoginInfoModel *loginInfo = [[LoginInfoModel alloc] init];
                                       loginInfo.accessToken = _tokenCode;
                                       loginInfo.tokenExpired = _expireDate;
                                       loginInfo.loginType = LoginMethodType_LoginByQQ;
                                       loginInfo.isPreLogin = YES;
                                       [LogInManager saveLoginInfo:loginInfo];
                                       [LogInManager sendQQLoginRequest:_tokenCode withExpireDateString:_expireDate];
                                   }
                               } else {
                                   NSString *errorString = error != nil ? error.localizedFailureReason : @"登录失败";
                                   NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorString forKey:KWErrorMessageKey];
                                   [[NSNotificationCenter defaultCenter] postNotificationName:kwNotificationQQLoginDidFail object:nil userInfo:userInfo];
                               }
                           }];
}

//-(void) _shareContentToTencentWeiBo:(NSString*)content
//{
//    NSString *urlAsString = @"https://graph.qq.com/t/add_t";
//    NSURL *url = [NSURL URLWithString:urlAsString];
//    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
//    [urlRequest setTimeoutInterval:30.0f];
//    [urlRequest setHTTPMethod:@"POST"];
//    //access_token=YOUR_ACCESS_TOKEN&oauth_consumer_key=YOUR_APP_ID&openid=YOUR_OPENID
//    NSString *body = [NSString stringWithFormat:@"access_token=%@&oauth_consumer_key=%@&openid=%@&format=json&content=%@", _tokenCode, QQ_APPID, _openId, content];
//    [urlRequest setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
//    
//    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
//    [NSURLConnection sendAsynchronousRequest:urlRequest
//                                       queue:queue
//                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
//                               if ([data length] >0 &&
//                                   error == nil){
//                                   NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//                                   NSLog(@"HTML = %@", html);
//                                   [_webView close];
//                               }
//                               else if ([data length] == 0 &&
//                                        error == nil){
//                                   NSLog(@"Nothing was downloaded.");
//                               }
//                               else if (error != nil){
//                                   NSLog(@"Error happened = %@", error);
//                               }
//                           }];
//}

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
