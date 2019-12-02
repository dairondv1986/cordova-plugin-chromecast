//
//  ChromecastSession.m
//  ChromeCast
//
//  Created by mac on 2019/9/30.
//

#import "ChromecastSession.h"
#import "CastUtilities.h"

@implementation ChromecastSession
GCKCastSession* currentSession;
CDVInvokedUrlCommand* joinSessionCommand;
BOOL isDisconnecting = NO;
NSMutableArray<CastRequestDelegate*>* requestDelegates;

- (instancetype)initWithListener:(id<CastSessionListener>)listener cordovaDelegate:(id<CDVCommandDelegate>)cordovaDelegate
{
    self = [super init];
    requestDelegates = [NSMutableArray new];
    self.sessionListener = listener;
    self.commandDelegate = cordovaDelegate;
    self.castContext = [GCKCastContext sharedInstance];
    self.sessionManager = self.castContext.sessionManager;
    
    // Ensure we are only listening once after init
    [self.sessionManager removeListener:self];
    [self.sessionManager addListener:self];
    
    return self;
}

- (void)setSession:(GCKCastSession*)session {
    currentSession = session;
}

- (void)tryRejoin {
    if (currentSession != nil) {
            [self.sessionListener onSessionRejoin:[CastUtilities createSessionObject:currentSession]];
    }
}

- (void)joinDevice:(GCKDevice*)device cdvCommand:(CDVInvokedUrlCommand*)command {
    joinSessionCommand = command;
    
    [NSUserDefaults.standardUserDefaults setBool:false forKey:@"jump"];
    [NSUserDefaults.standardUserDefaults synchronize];
    [self.sessionManager startSessionWithDevice:device];
}

-(CastRequestDelegate*)createSessionUpdateRequestDelegate:(CDVInvokedUrlCommand*)command {
    return [self createRequestDelegate:command success:^{
        [self.sessionListener onSessionUpdated:[CastUtilities createSessionObject:currentSession]];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } failure:nil abortion:nil];
}

-(CastRequestDelegate*)createMediaUpdateRequestDelegate:(CDVInvokedUrlCommand*)command {
    return [self createRequestDelegate:command success:^{
        NSLog(@"%@", [NSString stringWithFormat:@"kk requestDelegate(MediaUpdate) finished"]);
        [self.sessionListener onMediaUpdated:[CastUtilities createMediaObject:currentSession]];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } failure:nil abortion:nil];
}

-(CastRequestDelegate*)createRequestDelegate:(CDVInvokedUrlCommand*)command success:(void(^)(void))success failure:(void(^)(GCKError*))failure abortion:(void(^)(GCKRequestAbortReason))abortion {
    // set up any required defaults
    if (success == nil) {
        success = ^{
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };
    }
    if (failure == nil) {
        failure = ^(GCKError * error) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };
    }
    if (abortion == nil) {
        abortion = ^(GCKRequestAbortReason abortReason) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsNSInteger:abortReason];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };
    }
    CastRequestDelegate* delegate = [[CastRequestDelegate alloc] initWithSuccess:^{
        [self checkFinishDelegates];
        success();
    } failure:^(GCKError * error) {
        [self checkFinishDelegates];
        failure(error);
    } abortion:^(GCKRequestAbortReason abortReason) {
        [self checkFinishDelegates];
        abortion(abortReason);
    }];
    
    [requestDelegates addObject:delegate];
    return delegate;
}

- (void)endSession:(CDVInvokedUrlCommand*)command killSession:(BOOL)killSession {
    NSLog(@"kk endSession");
    [self endSessionWithCallback:^{
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } killSession:killSession];
}

- (void)endSessionWithCallback:(void(^)(void))callback killSession:(BOOL)killSession {
    NSLog(@"kk endSessionWithCallback");
    if (killSession) {
        [currentSession endWithAction:GCKSessionEndActionStopCasting];
    } else {
        isDisconnecting = YES;
        [currentSession endWithAction:GCKSessionEndActionLeave];
    }
    callback();
}

- (void)setMediaMutedAndVolumeWIthCommand:(CDVInvokedUrlCommand*)command muted:(BOOL)muted nvewLevel:(float)newLevel {
    
}

- (void)setMediaMutedWIthCommand:(CDVInvokedUrlCommand*)command muted:(BOOL)muted {
    
}

- (void)setMediaVolumeWithCommand:(CDVInvokedUrlCommand*)withCommand newVolumeLevel:(float)newLevel {
    
        GCKRequest* request = [self.remoteMediaClient setStreamVolume:newLevel customData:nil];
        request.delegate = [self createRequestDelegate:command success:setMuted failure:nil abortion:nil];
}

- (void)setReceiverVolumeLevelWithCommand:(CDVInvokedUrlCommand*)withCommand newLevel:(float)newLevel {
    GCKRequest* request = [currentSession setDeviceVolume:newLevel];
    request.delegate = [self createSessionUpdateRequestDelegate:command];
}

- (void)setReceiverMutedWithCommand:(CDVInvokedUrlCommand*)command muted:(BOOL)muted {
    GCKRequest* request = [currentSession setDeviceMuted:muted];
    request.delegate = [self createSessionUpdateRequestDelegate:command];
}

- (void)loadMediaWithCommand:(CDVInvokedUrlCommand*)command mediaInfo:(GCKMediaInformation*)mediaInfo autoPlay:(BOOL)autoPlay currentTime : (double)currentTime {
    [self checkFinishDelegates];
    CastRequestDelegate* requestDelegate = [[CastRequestDelegate alloc] initWithSuccess:^{
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[CastUtilities createMediaObject:currentSession]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } failure:^(GCKError * error) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } abortion:^(GCKRequestAbortReason abortReason) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsNSInteger:abortReason];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    
    [self.requestDelegates addObject:requestDelegate];
    GCKMediaLoadOptions* options = [[GCKMediaLoadOptions alloc] init];
    options.autoplay = autoPlay;
    options.playPosition = currentTime;
    GCKRequest* request = [self.remoteMediaClient loadMedia:mediaInfo withOptions:options];
    request.delegate = requestDelegate;
}

- (void)createMessageChannelWithCommand:(CDVInvokedUrlCommand*)command namespace:(NSString*)namespace{
    GCKGenericChannel* newChannel = [[GCKGenericChannel alloc] initWithNamespace:namespace];
    newChannel.delegate = self;
    self.genericChannels[namespace] = newChannel;
    [currentSession addChannel:newChannel];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)sendMessageWithCommand:(CDVInvokedUrlCommand*)command namespace:(NSString*)namespace message:(NSString*)message {
    GCKGenericChannel* channel = self.genericChannels[namespace];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"Namespace %@ not founded",namespace]];
    
    if (channel != nil) {
        GCKError* error = nil;
        [channel sendTextMessage:message error:&error];
        if (error != nil) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)mediaSeekWithCommand:(CDVInvokedUrlCommand*)command position:(NSTimeInterval)position resumeState:(GCKMediaResumeState)resumeState {
    GCKMediaSeekOptions* options = [[GCKMediaSeekOptions alloc] init];
    options.interval = position;
    options.resumeState = resumeState;
    GCKRequest* request = [self.remoteMediaClient seekWithOptions:options];
    request.delegate = [self createMediaUpdateRequestDelegate:command];
}

- (void)queueJumpToItemWithCommand:(CDVInvokedUrlCommand *)command itemId:(NSUInteger)itemId {
    GCKRequest* request = [self.remoteMediaClient queueJumpToItemWithID:itemId];
    request.delegate = [self createRequestDelegate:command success:nil failure:^(GCKError * error) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } abortion:^(GCKRequestAbortReason abortReason) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsNSInteger:abortReason];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    [NSUserDefaults.standardUserDefaults setBool:true forKey:@"jump"];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void)mediaPlayWithCommand:(CDVInvokedUrlCommand*)command {
    GCKRequest* request = [self.remoteMediaClient play];
    request.delegate = [self createMediaUpdateRequestDelegate:command];
}

- (void)mediaPauseWithCommand:(CDVInvokedUrlCommand*)command {
    GCKRequest* request = [self.remoteMediaClient pause];
    request.delegate = [self createMediaUpdateRequestDelegate:command];
}

- (void)mediaStopWithCommand:(CDVInvokedUrlCommand*)command {
    GCKRequest* request = [self.remoteMediaClient stop];
    request.delegate = [self createMediaUpdateRequestDelegate:command];
}

- (void)setActiveTracksWithCommand:(CDVInvokedUrlCommand*)command activeTrackIds:(NSArray<NSNumber*>*)activeTrackIds textTrackStyle:(GCKMediaTextTrackStyle*)textTrackStyle {
    GCKRequest* request = [self.remoteMediaClient setActiveTrackIDs:activeTrackIds];
    request.delegate = [self createMediaUpdateRequestDelegate:command];
    request = [self.remoteMediaClient setTextTrackStyle:textTrackStyle];
}

- (void)queueLoadItemsWithCommand:(CDVInvokedUrlCommand *)command queueItems:(NSArray *)queueItems startIndex:(NSInteger)startIndex repeatMode:(GCKMediaRepeatMode)repeatMode {
    CastRequestDelegate* requestDelegate = [[CastRequestDelegate alloc] initWithSuccess:^{
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[CastUtilities createMediaObject:currentSession]];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
    } failure:^(GCKError * error) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.description];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } abortion:^(GCKRequestAbortReason abortReason) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsNSInteger:abortReason];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
    
    [self.requestDelegates addObject:requestDelegate];
    GCKMediaQueueItem *item = queueItems[startIndex];
    GCKMediaQueueLoadOptions *options = [[GCKMediaQueueLoadOptions alloc] init];
    options.repeatMode = repeatMode;
    options.startIndex = startIndex;
    options.playPosition = item.startTime;
    [NSUserDefaults.standardUserDefaults setBool:false forKey:@"jump"];
    [NSUserDefaults.standardUserDefaults synchronize];
    GCKRequest* request = [self.remoteMediaClient queueLoadItems:queueItems withOptions:options];
    request.delegate = requestDelegate;
}

- (void) checkFinishDelegates {
    NSMutableArray<CastRequestDelegate*>* tempArray = [NSMutableArray new];
    for (CastRequestDelegate* delegate in requestDelegates) {
        if (!delegate.finished ) {
            [tempArray addObject:delegate];
        }
    }
    requestDelegates = tempArray;
}

#pragma -- GCKSessionManagerListener
- (void)sessionManager:(GCKSessionManager *)sessionManager didStartCastSession:(GCKCastSession *)session {
    [self setSession:session];
    self.remoteMediaClient = session.remoteMediaClient;
    [self.remoteMediaClient addListener:self];
    if (joinSessionCommand != nil) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: [CastUtilities createSessionObject:session] ];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:joinSessionCommand.callbackId];
        joinSessionCommand = nil;
    }
}

- (void)sessionManager:(GCKSessionManager *)sessionManager didEndCastSession:(GCKCastSession *)session withError:(NSError *)error {
    // Clear the session
    currentSession = nil;
    
    // Did we fail on a join session command?
    if (error != nil && joinSessionCommand != nil) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.debugDescription];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:joinSessionCommand.callbackId];
        joinSessionCommand = nil;
        return;
    }
    
    // Else, are we just leaving the session? (leaving results in disconnected status)
    if (isDisconnecting) {
        // Clear is isDisconnecting
        isDisconnecting = NO;
        [self.sessionListener onSessionUpdated:[CastUtilities createSessionObject:session status:@"disconnected"]];
    } else {
        [self.sessionListener onSessionUpdated:[CastUtilities createSessionObject:session]];
    }
    
    // Do we have any additional endSessionCallbacks?
    if (endSessionCallback) {
        endSessionCallback(YES);
    }
}

- (void)sessionManager:(GCKSessionManager *)sessionManager didResumeCastSession:(GCKCastSession *)session {
    [self setSession:session];
    [self.sessionListener onSessionRejoin:[CastUtilities createSessionObject:session]];
}

#pragma -- GCKRemoteMediaClientListener

- (void)remoteMediaClient:(GCKRemoteMediaClient *)client didStartMediaSessionWithID:(NSInteger)sessionID {
}

- (void)remoteMediaClient:(GCKRemoteMediaClient *)client didUpdateMediaStatus:(GCKMediaStatus *)mediaStatus {
    if (currentSession == nil) {
        [self.sessionListener onMediaUpdated:@{} isAlive:false];
        return;
    }
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"jump"]) {
        NSDictionary* media = [CastUtilities createMediaObject:currentSession];
        [self.sessionListener onMediaUpdated:media isAlive:true];
        if (!self.isRequesting) {
            if (mediaStatus.streamPosition > 0) {
                
                if (mediaStatus.queueItemCount > 1) {
                    [self.sessionListener onMediaLoaded:[CastUtilities createMediaObject:currentSession]];
                    isRequesting = YES;
                }
                else {
                    [self.sessionListener onMediaLoaded:media];
                }
            }

        }
    }
    else {
        NSDictionary* media = [CastUtilities createMediaObject:currentSession];
        [self.sessionListener onMediaUpdated:media isAlive:false];
    }
    
}

- (void)remoteMediaClientDidUpdatePreloadStatus:(GCKRemoteMediaClient *)client {
    [self remoteMediaClient:client didUpdateMediaStatus:nil];
}

- (void)remoteMediaClientDidUpdateQueue:(GCKRemoteMediaClient *)client{
    
}
- (void)remoteMediaClient:(GCKRemoteMediaClient *)client didInsertQueueItemsWithIDs:(NSArray<NSNumber *> *)queueItemIDs beforeItemWithID:(GCKMediaQueueItemID)beforeItemID {
    
}

- (void)remoteMediaClient:(GCKRemoteMediaClient *)client didReceiveQueueItems:(NSArray<GCKMediaQueueItem *> *)queueItems {
    
}

- (void)remoteMediaClient:(GCKRemoteMediaClient *)client didReceiveQueueItemIDs:(NSArray<NSNumber *> *)queueItemIDs {
    
}


#pragma -- GCKGenericChannelDelegate
- (void)castChannel:(GCKGenericChannel *)channel didReceiveTextMessage:(NSString *)message withNamespace:(NSString *)protocolNamespace {
    NSDictionary* session = [CastUtilities createSessionObject:currentSession];
    [self.sessionListener onMessageReceived:session namespace:protocolNamespace message:message];
}
@end
