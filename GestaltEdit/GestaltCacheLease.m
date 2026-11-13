#import "GestaltCacheLease.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

BOOL GestaltWithCacheLink(NSURL *groupRoot, NSString *target,
                         int64_t (^operation)(void), int64_t *result,
                         NSError **error)
{
    NSFileManager *files = NSFileManager.defaultManager;
    NSURL *libraryURL = [groupRoot URLByAppendingPathComponent:@"Library" isDirectory:YES];
    if (![files createDirectoryAtURL:libraryURL withIntermediateDirectories:YES attributes:nil error:error])
        return NO;
    int library = open(libraryURL.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (library < 0) {
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        return NO;
    }
    int lock = openat(library, ".gestaltedit-cache.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0600);
    struct stat lockInfo;
    int failure = 0;
    if (lock < 0) failure = errno;
    else if (fstat(lock, &lockInfo) != 0) failure = errno;
    else if (!S_ISREG(lockInfo.st_mode)) failure = EINVAL;
    else if (flock(lock, LOCK_EX | LOCK_NB) != 0) failure = errno;

    NSString *saved = [@".gestaltedit-cache-" stringByAppendingString:NSUUID.UUID.UUIDString];
    BOOL moved = NO, installed = NO, identified = NO;
    struct stat linkInfo;
    @try {
        if (!failure) {
            struct stat original;
            if (fstatat(library, "Caches", &original, AT_SYMLINK_NOFOLLOW) == 0) {
                if (renameatx_np(library, "Caches", library, saved.fileSystemRepresentation, RENAME_EXCL) == 0)
                    moved = YES;
                else failure = errno;
            } else if (errno != ENOENT) failure = errno;
        }
        if (!failure) {
            if (symlinkat(target.fileSystemRepresentation, library, "Caches") == 0) installed = YES;
            else failure = errno;
        }
        if (!failure) {
            if (fstatat(library, "Caches", &linkInfo, AT_SYMLINK_NOFOLLOW) != 0) failure = errno;
            else if (!S_ISLNK(linkInfo.st_mode)) failure = EBUSY;
            else identified = YES;
        }
        if (!failure) *result = operation();
    } @finally {
        BOOL canRestore = YES;
        BOOL restorationFailed = NO;
        if (installed) {
            struct stat current;
            if (fstatat(library, "Caches", &current, AT_SYMLINK_NOFOLLOW) == 0) {
                if (!identified || !S_ISLNK(current.st_mode) ||
                    current.st_dev != linkInfo.st_dev || current.st_ino != linkInfo.st_ino) {
                    failure = EBUSY;
                    canRestore = NO;
                    restorationFailed = YES;
                } else if (unlinkat(library, "Caches", 0) != 0) {
                    failure = errno;
                    canRestore = NO;
                    restorationFailed = YES;
                }
            } else if (errno != ENOENT) {
                failure = errno;
                canRestore = NO;
                restorationFailed = YES;
            }
        }
        if (moved && canRestore) {
            // Exclusive rename preserves a replacement created by another process.
            if (renameatx_np(library, saved.fileSystemRepresentation, library, "Caches", RENAME_EXCL) != 0) {
                failure = errno;
                restorationFailed = YES;
            } else moved = NO;
        } else if (installed && !moved && canRestore) {
            if (mkdirat(library, "Caches", 0700) != 0) {
                failure = errno;
                restorationFailed = YES;
            }
        }
        if (lock >= 0) close(lock);
        close(library);
        if (failure && error) {
            NSURL *preserved = moved ? [libraryURL URLByAppendingPathComponent:saved] : libraryURL;
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:failure
                                     userInfo:@{NSFilePathErrorKey: preserved.path,
                                                @"GestaltCacheRestorationFailed": @(restorationFailed)}];
        }
    }
    return failure == 0;
}
