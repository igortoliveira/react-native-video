#import "CachingPlayerItem.h"

@interface CachingPlayerItem () <CachingPlayerItemDelegate>

@property (nonatomic) ResourceLoaderDelegate *resourceLoaderDelegate;
@property (nonatomic, readwrite) NSURL *url;
@property (nonatomic, nullable) NSString *initialScheme;
@property (nonatomic, nullable) NSString *customFileExtension;
@property (atomic, assign) BOOL isBuffering;

@end

@implementation CachingPlayerItem
static NSString *cachingPlayerItemScheme = @"cachingPlayerItemScheme";

// Used for playing remote files.
- (instancetype)initWithURL:(NSURL *)URL {
    return [self initWithURL:URL customFileExtension:nil];
}

// Override/append custom file extension to URL path.
// This is required for the player to work correctly with the intended file type.
- (instancetype)initWithURL:(NSURL *)url customFileExtension:(nullable NSString *)customFileExtension {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:false];
    NSAssert(components != nil, @"Invalid Url");
    NSAssert(components.scheme != nil, @"Urls without a scheme are not supported");
    self.url = url;
    self.initialScheme = components.scheme;
    NSURL *urlWithCustomScheme = [self urlWithCachingScheme:url];

    if (customFileExtension != nil) {
        self.customFileExtension = customFileExtension;
        urlWithCustomScheme = [[urlWithCustomScheme URLByDeletingPathExtension]
                               URLByAppendingPathExtension:customFileExtension];
    }

    self.resourceLoaderDelegate = [[ResourceLoaderDelegate alloc] initWithOwner:self];

    AVURLAsset *asset = [AVURLAsset assetWithURL:urlWithCustomScheme];
    [asset.resourceLoader setDelegate:self.resourceLoaderDelegate queue:self.resourceLoaderDelegate.dispatchQueue];

    self = [super initWithAsset:asset automaticallyLoadedAssetKeys:nil];

    [self addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playbackStalledHandler)
                                               name:AVPlayerItemPlaybackStalledNotification
                                             object:self];

    return self;
}

- (instancetype)initWithData:(NSData *)data mimeType:(NSString *)mimeType fileExtension:(NSString *)fileExtension {
    NSURL *fakeUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@://whatever/file.%@", cachingPlayerItemScheme, fileExtension]];
    NSAssert1(fakeUrl != nil, @"Error creating an URL with `%@` as extension", fileExtension);

    self.url = fakeUrl;
    self.initialScheme = nil;
    self.resourceLoaderDelegate = [[ResourceLoaderDelegate alloc] initWithData:data
                                                                      mimeType:mimeType
                                                                         owner:self];

    AVURLAsset *asset = [AVURLAsset assetWithURL:fakeUrl];
    [asset.resourceLoader setDelegate:self.resourceLoaderDelegate queue:dispatch_get_main_queue()];
    self = [super initWithAsset:asset automaticallyLoadedAssetKeys:nil];

    [self addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playbackStalledHandler)
                                               name:AVPlayerItemPlaybackStalledNotification
                                             object:self];

    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [self removeObserver:self forKeyPath:@"status"];
    [self.resourceLoaderDelegate.session invalidateAndCancel];
}

#pragma mark - Public

- (void)download {
    if (self.resourceLoaderDelegate.session == nil) {
        [self.resourceLoaderDelegate startDataRequest:self.url];
    }
}

- (void)pause {
    [self.resourceLoaderDelegate suspendRequest];
}

- (void)buffer {
    self.isBuffering = true;
    self.delegate = self;
    [self download];
}

#pragma mark - Private

- (NSURL *)urlWithCachingScheme:(NSURL *)url {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:false];
    components.scheme = cachingPlayerItemScheme;

    return components.URL;
}

#pragma mark - Notification handler / KVO

- (void)playbackStalledHandler {
    if ([self.delegate respondsToSelector:@selector(playerItemPlaybackStalled:)])
        [self.delegate playerItemPlaybackStalled:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {

    if ([self.delegate respondsToSelector:@selector(playerItemReadyToPlay:)])
        [self.delegate playerItemReadyToPlay:self];
}

#pragma mark - CachingPlayerItemDelegate

- (void)playerItem:(CachingPlayerItem *)playerItem didDownloadBytesSoFar:(NSUInteger)bytesDownloaded outOf:(NSUInteger)bytesExpected {
    if (_isBuffering && bytesDownloaded >= 1 * 1024 * 1024) {
        NSLog(@"Download paused (Buffer: %lu bytes)", bytesDownloaded);
        _isBuffering = false;
        [self pause];
    }
}

@end
