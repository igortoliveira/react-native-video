#import <Foundation/Foundation.h>

@class CachingPlayerItem;

@protocol CachingPlayerItemDelegate <NSObject>
@optional
/// Called when the media file is fully downloaded.
- (void)playerItem:(CachingPlayerItem *)playerItem didFinishDownloadingData:(NSData *)data;

/// Called every time a new portion of data is received.
- (void)playerItem:(CachingPlayerItem *)playerItem didDownloadBytesSoFar:(NSUInteger)bytesDownloaded outOf:(NSUInteger)bytesExpected;

/// Called after initial prebuffering is finished, means
/// we are ready to play.
- (void)playerItemReadyToPlay:(CachingPlayerItem *)playterItem;

/// Called when the data being downloaded did not arrive in time to continue playback.
- (void)playerItemPlaybackStalled:(CachingPlayerItem *)playerItem;

/// Called on downloading error.
- (void)playerItem:(CachingPlayerItem *)playerItem downloadingFailedWithError:(NSError *)error;

@end
