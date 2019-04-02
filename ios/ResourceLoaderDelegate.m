#import "ResourceLoaderDelegate.h"
#import "CachingPlayerItem.h"

@interface ResourceLoaderDelegate ()

@property (assign) BOOL playingFromData;
@property (nonatomic, nullable) NSString *mimeType; // required when playing from Data
@property (nonatomic, readwrite) NSURLSession *session;
@property (nonatomic, nullable) NSURLResponse *response;
@property (nonatomic, strong) NSMutableData *mediaData;
@property (nonatomic) NSMutableSet<AVAssetResourceLoadingRequest *> *pendingRequests;
@property (weak, nullable) CachingPlayerItem *owner;
@property (nonatomic, nullable) NSURLSessionDataTask *task;

@property NSOperationQueue *operationQueue;
@property dispatch_queue_t dispatchQueue;

@end

@implementation ResourceLoaderDelegate

- (instancetype)initWithOwner:(CachingPlayerItem *)owner {
    self = [super init];

    self.playingFromData = false;
    self.pendingRequests = [NSMutableSet new];
    self.owner = owner;

    self.dispatchQueue = dispatch_queue_create("CachingPlayerItem.dispatchQueue", DISPATCH_QUEUE_SERIAL);
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.name = @"CachingPlayerItem.operationQueue";
    self.operationQueue.underlyingQueue = self.dispatchQueue;
    self.operationQueue.maxConcurrentOperationCount = 1;

    return self;
}

- (instancetype)initWithData:(NSData *)data mimeType:(NSString *)mimeType owner:(CachingPlayerItem *)owner {
    self = [self initWithOwner:owner];

    self.mediaData = [NSMutableData dataWithData:data];
    self.playingFromData = true;

    return self;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
}

- (void)startDataRequest:(NSURL *)url {
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.defaultSessionConfiguration;
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;

    self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:_operationQueue];
    self.task = [self.session dataTaskWithURL:url];
    [self.task resume];
}

- (void)suspendRequest {
    [self.task suspend];
}

#pragma mark - Private

- (void)processPendingRequests {
    __block NSMutableSet<AVAssetResourceLoadingRequest *> *requestsFulfilled = [NSMutableSet new];
    [self.pendingRequests enumerateObjectsUsingBlock:^(AVAssetResourceLoadingRequest *obj, BOOL *stop) {
        [self fillInContentInformationRequest:obj.contentInformationRequest];

        if ([self haveEnoughDataToFulfillRequest:obj.dataRequest]) {
            [obj finishLoading];
            [requestsFulfilled addObject:obj];
        }
    }];

    [requestsFulfilled enumerateObjectsUsingBlock:^(AVAssetResourceLoadingRequest *obj, BOOL *stop) {
        [self.pendingRequests removeObject:obj];
    }];
}

- (void)fillInContentInformationRequest:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest {
    // if we play from Data we make no url requests, therefore we have no responses, so we need to fill in contentInformationRequest manually
    if (self.playingFromData) {
        contentInformationRequest.contentType = self.mimeType;
        contentInformationRequest.contentLength = self.mediaData.length;
        contentInformationRequest.byteRangeAccessSupported = true;
        return;
    }

    if (self.response == nil) {
        // have no response from server yet
        return;
    }

    contentInformationRequest.contentType = self.response.MIMEType;
    contentInformationRequest.contentLength = self.response.expectedContentLength;
    contentInformationRequest.byteRangeAccessSupported = true;
}

- (BOOL)haveEnoughDataToFulfillRequest:(AVAssetResourceLoadingDataRequest *)dataRequest {
    if (self.mediaData == nil || self.mediaData.length < 1 || self.mediaData.length < dataRequest.currentOffset) {
        // Don't have any data at all for this request
        return false;
    }

    NSUInteger bytesToRespond = MIN(self.mediaData.length - dataRequest.currentOffset, dataRequest.requestedLength);
    NSRange dataRange = NSMakeRange(dataRequest.currentOffset, bytesToRespond);

    @try {
        NSData *dataToRespond = [self.mediaData subdataWithRange:dataRange];
        [dataRequest respondWithData:dataToRespond];

    } @catch (NSException *exception) {
        NSLog(@"");
    }

    return self.mediaData.length >= dataRequest.requestedLength + dataRequest.requestedOffset;
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error == nil) { // Request is completed
        [self processPendingRequests];

        if ([self.owner.delegate respondsToSelector:@selector(playerItem:downloadingFailedWithError:)])
            [self.owner.delegate playerItem:_owner downloadingFailedWithError:error];

        return;
    }

    if ([self.owner.delegate respondsToSelector:@selector(playerItem:didFinishDownloadingData:)])
        [self.owner.delegate playerItem:_owner didFinishDownloadingData:_mediaData];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    @synchronized(self.mediaData) {
        [self.mediaData appendData:data];
    }

    [self processPendingRequests];

    if ([self.owner.delegate respondsToSelector:@selector(playerItem:didDownloadBytesSoFar:outOf:)])
        [self.owner.delegate playerItem:_owner didDownloadBytesSoFar:_mediaData.length outOf:dataTask.countOfBytesExpectedToReceive];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {

    completionHandler(NSURLSessionResponseAllow);
    self.mediaData = [NSMutableData new];
    self.response = response;
    [self processPendingRequests];
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    if (self.session == nil) {
        // If we're playing from a url, we need to download the file.
        // We start loading the file on first request only.

        NSAssert(self.owner.url != nil, @"URL should not be nil");
        [self startDataRequest:self.owner.url];
    } else if (self.task != nil) {
        [self.task resume];
    }

    [self.pendingRequests addObject:loadingRequest];
    [self processPendingRequests];

    return true;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self.pendingRequests removeObject:loadingRequest];
}

@end
