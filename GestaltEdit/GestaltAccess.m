//
//  GestaltAccess.m
//  GestaltEdit
//
//  Access via the forcequitOS/worse_query App Group symlink PoC.

#import "GestaltAccess.h"
#import "worse_query.h"
#import "GestaltAppGroupResolver.h"

#import <errno.h>
#import <fcntl.h>
#import <unistd.h>

static NSString * const kGestaltPlistFileName = @"com.apple.MobileGestalt.plist";

static NSString * const kMobileGestaltCacheDirectory =
    @"/private/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";
static NSString * const kWorseQueryMobileGestaltCacheDirectory =
    @"/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";

static NSError *GestaltError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"com.gestaltedit.access"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

static BOOL GestaltCanOpenReadWrite(NSString *path)
{
    int fd = open(path.fileSystemRepresentation,
                  O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return NO;
    close(fd);
    return YES;
}

static NSString *GestaltAccessFailureReason(int64_t code)
{
    switch (code) {
        case -1: return NSLocalizedString(@"The signed App Group container is unavailable.", nil);
        case -2: return NSLocalizedString(@"Required system access APIs are unavailable.", nil);
        case -3: return NSLocalizedString(@"The system access query could not be created.", nil);
        case -4: return NSLocalizedString(@"The App Group cache could not be prepared.", nil);
        case -5: return NSLocalizedString(@"The system rejected the container query.", nil);
        case -6: return NSLocalizedString(@"The system did not issue an access token.", nil);
        case -7: return NSLocalizedString(@"The access token could not be activated.", nil);
        case -8: return NSLocalizedString(@"The App Group cache could not be restored. Its original contents have been preserved.", nil);
        case -9: return NSLocalizedString(@"The access token did not allow reading and writing MobileGestalt.", nil);
        case -255: return NSLocalizedString(@"The MobileGestalt cache directory is unavailable.", nil);
        default: return NSLocalizedString(@"System access failed.", nil);
    }
}

static BOOL GestaltWriteAll(int fd, NSData *data)
{
    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return NO;
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    return YES;
}

@interface GestaltAccess ()
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, copy) NSString *plistPath;
@property (nonatomic, assign) NSPropertyListFormat lastReadFormat;
@end

@implementation GestaltAccess
{
    int64_t _sandboxHandle;
    BOOL _hasSandboxHandle;
}

+ (instancetype)shared
{
    static GestaltAccess *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [GestaltAccess new]; });
    return shared;
}

#pragma mark - Connection

- (BOOL)connectWithError:(NSError **)error
{
    @synchronized (self) {
        if (self.isConnected && _hasSandboxHandle && self.plistPath.length > 0 &&
            GestaltCanOpenReadWrite(self.plistPath)) {
            if (error) *error = nil;
            return YES;
        }

        if (_hasSandboxHandle) worse_query_release(_sandboxHandle);
        _hasSandboxHandle = NO;
        self.isConnected = NO;
        self.plistPath = nil;

        NSString *target = kWorseQueryMobileGestaltCacheDirectory;
        NSString *plist = [kMobileGestaltCacheDirectory
            stringByAppendingPathComponent:kGestaltPlistFileName];
        NSArray<NSString *> *groups = [GestaltAppGroupResolver usableAppGroups];
        if (groups.count == 0) {
            if (error) *error = GestaltError(1, NSLocalizedString(@"No usable App Group was found in the app signature. Sign with a provisioning profile that includes an App Group.", nil));
            return NO;
        }

        NSMutableArray<NSString *> *attempts = [NSMutableArray array];
        for (NSUInteger index = 0; index < groups.count; ++index) {
            for (NSUInteger variant = 0; variant < 2; ++variant) {
                errno = 0;
                int64_t handle = worse_query(target, groups[index], variant != 0, false);
                int savedErrno = errno;
                if (handle >= 0) {
                    if (GestaltCanOpenReadWrite(plist)) {
                        _sandboxHandle = handle;
                        _hasSandboxHandle = YES;
                        self.isConnected = YES;
                        self.plistPath = plist;
                        if (error) *error = nil;
                        return YES;
                    }
                    savedErrno = errno;
                    worse_query_release(handle);
                    handle = -9;
                }
                NSString *reason = GestaltAccessFailureReason(handle);
                [attempts addObject:[NSString stringWithFormat:@"%lu/%lu: %@ (code=%lld, errno=%d)",
                    (unsigned long)(index + 1), (unsigned long)(variant + 1), reason,
                    (long long)handle, savedErrno]];
                // These failures cannot be repaired by changing query flags.
                if (handle == -1 || handle == -4) break;
                // Stop if cleanup failed; do not touch the preserved cache again.
                if (handle == -8 || handle == -2 || handle == -3 || handle == -255) {
                    if (error) *error = GestaltError(2, [attempts componentsJoinedByString:@"\n"]);
                    return NO;
                }
            }
        }
        if (error) *error = GestaltError(2, [attempts componentsJoinedByString:@"\n"]);
        return NO;
    }
}

#pragma mark - Read / Write

- (NSData *)readGestaltDataWithError:(NSError **)error
{
    if (![self connectWithError:error]) return nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.plistPath]) {
        if (error) *error = GestaltError(3,
            [NSString stringWithFormat:NSLocalizedString(@"The plist does not exist: %@", nil), self.plistPath]);
        return nil;
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.plistPath
                                          options:NSDataReadingMappedIfSafe
                                            error:&readError];
    if (!data) {
        if (error) *error = readError ?: GestaltError(4, NSLocalizedString(@"Failed to read the plist.", nil));
        return nil;
    }
    if (error) *error = nil;
    return data;
}

- (NSDictionary *)readGestaltWithError:(NSError **)error
{
    NSData *data = [self readGestaltDataWithError:error];
    if (!data) return nil;

    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    NSError *parseError = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:0
                                                          format:&format
                                                           error:&parseError];
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = parseError ?: GestaltError(5,
            NSLocalizedString(@"The plist top level is not a dictionary.", nil));
        return nil;
    }
    self.lastReadFormat = format;
    return plist;
}

- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error
{
    if (![self connectWithError:error]) return NO;
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = GestaltError(6, NSLocalizedString(@"The content to save is not a dictionary.", nil));
        return NO;
    }

    NSPropertyListFormat format = self.lastReadFormat;
    if (format != NSPropertyListXMLFormat_v1_0 &&
        format != NSPropertyListBinaryFormat_v1_0)
        format = NSPropertyListBinaryFormat_v1_0;

    NSError *serializeError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:format
                                                             options:0
                                                               error:&serializeError];
    if (!data) {
        if (error) *error = serializeError ?: GestaltError(7, NSLocalizedString(@"Failed to serialize the plist.", nil));
        return NO;
    }

    NSString *targetPath = self.plistPath;
    NSError *readError = nil;
    NSData *original = [NSData dataWithContentsOfFile:targetPath
                                              options:0
                                                error:&readError];
    if (!original) {
        if (error) *error = readError ?: GestaltError(8, NSLocalizedString(@"Failed to read the original plist.", nil));
        return NO;
    }

    int fd = open(targetPath.fileSystemRepresentation,
                  O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) {
        if (error) *error = GestaltError(9,
            [NSString stringWithFormat:NSLocalizedString(@"Failed to open the plist (errno=%d).", nil), errno]);
        return NO;
    }

    BOOL wrote = ftruncate(fd, 0) == 0 &&
        lseek(fd, 0, SEEK_SET) == 0 &&
        GestaltWriteAll(fd, data) &&
        fsync(fd) == 0;
    int writeErrno = errno;

    if (!wrote) {
        ftruncate(fd, 0);
        lseek(fd, 0, SEEK_SET);
        GestaltWriteAll(fd, original);
        fsync(fd);
        close(fd);
        if (error) *error = GestaltError(10,
            [NSString stringWithFormat:NSLocalizedString(@"Failed to write the plist (errno=%d).", nil), writeErrno]);
        return NO;
    }
    close(fd);

    NSData *verification = [NSData dataWithContentsOfFile:targetPath];
    if (![verification isEqualToData:data]) {
        if (error) *error = GestaltError(11, NSLocalizedString(@"Post-write verification failed.", nil));
        return NO;
    }

    if (error) *error = nil;
    return YES;
}

@end
