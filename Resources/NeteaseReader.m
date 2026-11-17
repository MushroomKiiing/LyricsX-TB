// Local LyricsX repair: query only NetEase's registered media client.
// Private API signatures cross-checked against Yudaotor/lyrimuse's
// nowplaying-clients implementation. No network, playback control or logging.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <dispatch/dispatch.h>
typedef void (*Clients)(dispatch_queue_t, void (^)(NSArray *));
typedef void (*Info)(void *, void *, long, dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*State)(void *, void *, dispatch_queue_t, void (^)(uint32_t));
static void emit(id payload) {
    NSData *data = payload ? [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL] : nil;
    if (data) fwrite(data.bytes,1,data.length,stdout); else fputs("null",stdout);
    fputc('\n',stdout); fflush(stdout);
}
void lyricsx_netease_snapshot(void *interpreter, void *call) {
    @autoreleasepool {
        void *handle=dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",RTLD_NOW|RTLD_LOCAL);
        Clients clients=handle?(Clients)dlsym(handle,"MRMediaRemoteGetNowPlayingClients"):NULL;
        Info info=handle?(Info)dlsym(handle,"MRMediaRemoteGetNowPlayingInfoForClient"):NULL;
        State state=handle?(State)dlsym(handle,"MRMediaRemoteGetPlaybackStateForClient"):NULL;
        if (!clients||!info||!state) { emit(nil); return; }
        dispatch_queue_t queue=dispatch_get_global_queue(QOS_CLASS_UTILITY,0);
        dispatch_semaphore_t ready=dispatch_semaphore_create(0);
        __block NSArray *list=nil;
        clients(queue,^(NSArray *value){ list=[value copy]; dispatch_semaphore_signal(ready); });
        if(dispatch_semaphore_wait(ready,dispatch_time(DISPATCH_TIME_NOW,700*NSEC_PER_MSEC))) {emit(nil);return;}
        for(id client in list) {
            SEL selector=sel_registerName("bundleIdentifier");
            if(![client respondsToSelector:selector]) continue;
            id bundle=((id(*)(id,SEL))objc_msgSend)(client,selector);
            if(![bundle isKindOfClass:NSString.class]||![bundle isEqualToString:@"com.netease.163music"]) continue;
            dispatch_semaphore_t infoReady=dispatch_semaphore_create(0), stateReady=dispatch_semaphore_create(0);
            __block NSDictionary *raw=nil; __block uint32_t playback=UINT32_MAX;
            info((__bridge void*)client,NULL,getenv("LYRICSX_NETEASE_ARTWORK")?1:0,queue,^(CFDictionaryRef value){if(value)raw=[(__bridge NSDictionary*)value copy]; dispatch_semaphore_signal(infoReady);});
            state((__bridge void*)client,NULL,queue,^(uint32_t value){playback=value;dispatch_semaphore_signal(stateReady);});
            if(dispatch_semaphore_wait(infoReady,dispatch_time(DISPATCH_TIME_NOW,700*NSEC_PER_MSEC))) {emit(nil);return;}
            BOOL stateKnown=dispatch_semaphore_wait(stateReady,dispatch_time(DISPATCH_TIME_NOW,150*NSEC_PER_MSEC))==0;
            NSString *title=raw[@"kMRMediaRemoteNowPlayingInfoTitle"];
            if(![title isKindOfClass:NSString.class]||title.length==0){emit(nil);return;}
            NSMutableDictionary *out=[@{@"title":title,@"bundleIdentifier":@"com.netease.163music",@"applicationName":@"网易云音乐"} mutableCopy];
            NSDictionary *fields=@{@"Artist":@"artist",@"Album":@"album"};
            for(NSString *key in fields){id value=raw[[@"kMRMediaRemoteNowPlayingInfo" stringByAppendingString:key]]; if([value isKindOfClass:NSString.class])out[fields[key]]=value;}
            NSNumber *rate=raw[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
            BOOL playing;
            if(stateKnown&&(playback==2||playback==3||playback==4)) playing=NO;
            else if(stateKnown&&playback==1) playing=!rate||rate.doubleValue>0;
            else playing=rate.doubleValue>0;
            if(stateKnown||rate)out[@"isPlaying"]=playing?@YES:@NO;
            for(NSString *key in @[@"Duration",@"ElapsedTime"]){id value=raw[[@"kMRMediaRemoteNowPlayingInfo" stringByAppendingString:key]]; if([value isKindOfClass:NSNumber.class]&&isfinite([value doubleValue]))out[[key isEqualToString:@"Duration"]?@"durationMicros":@"elapsedTimeMicros"]=@([value doubleValue]*1000000);}
            id stamp=raw[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
            if([stamp isKindOfClass:NSDate.class])out[@"timestampEpochMicros"]=@([stamp timeIntervalSince1970]*1000000);
            id artwork=raw[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
            if([artwork isKindOfClass:NSData.class]&&[artwork length]<8000000) out[@"artworkDataBase64"]=[artwork base64EncodedStringWithOptions:0];
            emit(out);return;
        }
        emit(nil);
    }
}
