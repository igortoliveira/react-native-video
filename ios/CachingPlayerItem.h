#import <AVFoundation/AVFoundation.h>
#import "ResourceLoaderDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface CachingPlayerItem : AVPlayerItem

@property (weak) id<CachingPlayerItemDelegate> delegate;
@property (nonatomic, readonly) NSURL *url;

- (instancetype)initWithURL:(NSURL *)URL;

- (instancetype)initWithURL:(NSURL *)URL
        customFileExtension:(nullable NSString *)customFileExtension;

- (instancetype)initWithAsset:(AVAsset *)asset
 automaticallyLoadedAssetKeys:(nullable NSArray<NSString *> *)automaticallyLoadedAssetKeys NS_UNAVAILABLE;

- (void)download;
- (void)buffer;

@end

NS_ASSUME_NONNULL_END
