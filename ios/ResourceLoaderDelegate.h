#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "CachingPlayerItemDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface ResourceLoaderDelegate : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, AVAssetResourceLoaderDelegate>

@property (nonatomic, readonly) NSURLSession *session;
@property (readonly) dispatch_queue_t dispatchQueue;

- (instancetype)initWithOwner:(CachingPlayerItem *)owner;
- (instancetype)initWithData:(NSData *)data mimeType:(NSString *)mimeType owner:(CachingPlayerItem *)owner;
- (void)startDataRequest:(NSURL *)url;
- (void)suspendRequest;

@end

NS_ASSUME_NONNULL_END
