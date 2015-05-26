//
//  OpenShare+Weixin.m
//  openshare
//
//  Created by LiuLogan on 15/5/18.
//  Copyright (c) 2015年 OpenShare <http://openshare.gfzj.us/>. All rights reserved.
//

#import "OpenShare+Weixin.h"

@implementation OpenShare (Weixin)
static NSString *schema=@"Weixin";
+(void)connectWeixinWithAppId:(NSString *)appId{
    [self set:schema Keys:@{@"appid":appId}];

}
+(BOOL)isWeixinInstalled{
    return [self canOpen:@"weixin://"];
}

+(void)shareToWeixinSession:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genWeixinShareUrl:msg to:0]];
    }
}
+(void)shareToWeixinTimeline:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genWeixinShareUrl:msg to:1]];
    }
}
+(void)shareToWeixinFavorite:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genWeixinShareUrl:msg to:2]];
    }
}


/**
 *  把msg分享到shareTO
 *
 *  @param msg     OSmessage
 *  @param shareTo 0是好友／1是QQ空间。
 *
 *  @return 需要打开的url
 */
+(NSString*)genWeixinShareUrl:(OSMessage*)msg to:(int)shareTo{
    NSMutableDictionary *dic=[[NSMutableDictionary alloc] initWithDictionary:@{@"result":@"1",@"returnFromApp" :@"0",@"scene" : [NSString stringWithFormat:@"%d",shareTo],@"sdkver" : @"1.5",@"command" : @"1010"}];
    if (msg.multimediaType==OSMultimediaTypeNews) {
        msg.multimediaType=0;
    }
    if (!msg.multimediaType) {
        //不指定类型
        if ([msg isEmpty:@[@"image",@"link"] AndNotEmpty:@[@"title"]]) {
            //文本
            dic[@"command"]=@"1020";
            dic[@"title"]=msg.title;
        }else if([msg isEmpty:@[@"link"] AndNotEmpty:@[@"image"]]){
            //图片
            dic[@"fileData"]=msg.image;
            dic[@"thumbData"]=msg.thumbnail?:msg.image;
            dic[@"objectType"]=@"2";
        }else if([msg isEmpty:nil AndNotEmpty:@[@"link",@"title",@"image"]]){
            //有链接。
            dic[@"description"]=msg.desc?:msg.title;
            dic[@"mediaUrl"]=msg.link;
            dic[@"objectType"]=@"5";
            dic[@"thumbData"]=msg.thumbnail?:msg.image;
            dic[@"title"] =msg.title;
        }
    }else if(msg.multimediaType==OSMultimediaTypeAudio){
        //music
        dic[@"description"]=msg.desc?:msg.title;
        dic[@"mediaUrl"]=msg.link;
        dic[@"mediaDataUrl"]=msg.mediaDataUrl;
        dic[@"objectType"]=@"3";
        dic[@"thumbData"]=msg.thumbnail?:msg.image;
        dic[@"title"] =msg.title;
    }else if(msg.multimediaType==OSMultimediaTypeVideo){
        //video
        dic[@"description"]=msg.desc?:msg.title;
        dic[@"mediaUrl"]=msg.link;
        dic[@"objectType"]=@"4";
        dic[@"thumbData"]=msg.thumbnail?:msg.image;
        dic[@"title"] =msg.title;
    }else if(msg.multimediaType==OSMultimediaTypeApp){
        //app
        dic[@"description"]=msg.desc?:msg.title;
        if(msg.extInfo)dic[@"extInfo"]=msg.extInfo;
        dic[@"fileData"]=msg.image;
        dic[@"mediaUrl"]=msg.link;
        dic[@"objectType"]=@"7";
        dic[@"thumbData"]=msg.thumbnail?:msg.image;
        dic[@"title"] =msg.title;
    }else if(msg.multimediaType==OSMultimediaTypeFile){
        //file
        dic[@"description"]=msg.desc?:msg.title;
        dic[@"fileData"]=msg.image;
        dic[@"objectType"]=@"6";
        dic[@"fileExt"]=msg.fileExt?:@"";
        dic[@"thumbData"]=msg.thumbnail?:msg.image;
        dic[@"title"] =msg.title;
    }
    NSData *output=[NSPropertyListSerialization dataWithPropertyList:@{[self keyFor:schema][@"appid"]:dic} format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    [[UIPasteboard generalPasteboard] setData:output forPasteboardType:@"content"];
    return [NSString stringWithFormat:@"weixin://app/%@/sendreq/?",[self keyFor:schema][@"appid"]];
}


/**
 *  注意：微信登录权限仅限已获得认证的开发者申请，请先进行开发者认证
 *
 *  @param scope   scope
 *  @param success 登录成功回调
 *  @param fail    登录失败回调
 */
+(void)WeixinAuth:(NSString*)scope Success:(authSuccess)success Fail:(authFail)fail{
    if ([self beginAuth:schema Success:success Fail:fail]) {
        [self openURL:[NSString stringWithFormat:@"weixin://app/%@/auth/?scope=%@&state=Weixinauth",[self keyFor:schema][@"appid"],scope]];
    }
}


+(BOOL)Weixin_handleOpenURL{
    NSURL* url=[self returnedURL];
    if ([url.scheme hasPrefix:@"wx"]) {
        NSDictionary *retDic=[NSPropertyListSerialization propertyListWithData:[[UIPasteboard generalPasteboard] dataForPasteboardType:@"content"] options:0 format:0 error:nil][[self keyFor:schema][@"appid"]];
        if ([url.absoluteString rangeOfString:@"://oauth"].location!=NSNotFound) {
            //login succcess
            if ([self authSuccesCallback]) {
                [self authSuccesCallback]([self parseUrl:url]);
            }
        }else{
            if (retDic[@"state"]&&[retDic[@"state"] isEqualToString:@"Weixinauth"]&&[retDic[@"result"] intValue]!=0) {
                //登录失败
                if ([self authFailCallback]) {
                    [self authFailCallback](retDic,[NSError errorWithDomain:@"weixin_auth" code:[retDic[@"result"] intValue] userInfo:retDic]);
                }
            }else if([retDic[@"result"] intValue]==0){
                //分享成功
                if ([self shareSuccesCallback]) {
                    [self shareSuccesCallback]([self message]);
                }
            }else{
                //分享失败
                if ([self shareFailCallback]) {
                    [self shareFailCallback]([self message],[NSError errorWithDomain:@"weixin_share" code:[retDic[@"result"] intValue] userInfo:retDic]);
                }
            }
            
        }
        return YES;
    }else{
        return NO;
    }
}
@end
