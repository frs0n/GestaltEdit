#import <Foundation/Foundation.h>
#import "GestaltCacheLease.h"
#include <sys/stat.h>
#include <unistd.h>

static void Check(BOOL condition, NSString *message)
{
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

static NSURL *Child(NSURL *parent, NSString *name)
{
    return [parent URLByAppendingPathComponent:name];
}

int main(void)
{
    @autoreleasepool {
        NSFileManager *files = NSFileManager.defaultManager;
        NSURL *root = Child([NSURL fileURLWithPath:NSTemporaryDirectory()], NSUUID.UUID.UUIDString);
        NSURL *group = Child(root, @"group");
        NSURL *target = Child(root, @"target");
        NSURL *caches = Child(group, @"Library/Caches");
        Check([files createDirectoryAtURL:target withIntermediateDirectories:YES attributes:nil error:nil], @"target setup");
        NSData *sentinel = [@"preserve me" dataUsingEncoding:NSUTF8StringEncoding];
        Check([sentinel writeToURL:Child(target, @"sentinel") atomically:YES], @"target sentinel");
        int64_t result = -99;
        NSError *error = nil;
        Check(GestaltWithCacheLink(group, target.path, ^int64_t {
            Check([[files destinationOfSymbolicLinkAtPath:caches.path error:nil] isEqualToString:target.path], @"temporary link");
            return 42;
        }, &result, &error), @"missing Library is created");
        Check(result == 42, @"handle returned");
        BOOL directory = NO;
        Check([files fileExistsAtPath:caches.path isDirectory:&directory] && directory, @"cache directory restored");

        Check([files createDirectoryAtURL:Child(caches, @"nested") withIntermediateDirectories:YES attributes:nil error:nil], @"nested cache");
        Check([sentinel writeToURL:Child(caches, @"nested/data") atomically:YES], @"cache data");
        struct stat before, after;
        Check(lstat(caches.fileSystemRepresentation, &before) == 0, @"original inode");
        for (NSNumber *outcome in @[@0, @(-5), @(-6), @(-7)]) {
            Check(GestaltWithCacheLink(group, target.path, ^int64_t { return outcome.longLongValue; }, &result, &error), @"query cleanup");
            Check(result == outcome.longLongValue, @"zero and negative results retained");
            Check(lstat(caches.fileSystemRepresentation, &after) == 0 && before.st_ino == after.st_ino, @"same cache inode");
            Check([[NSData dataWithContentsOfURL:Child(caches, @"nested/data")] isEqual:sentinel], @"nested cache data retained");
        }
        NSString *longTarget = [@"/" stringByPaddingToLength:10000 withString:@"a" startingAtIndex:0];
        Check(!GestaltWithCacheLink(group, longTarget, ^int64_t { Check(NO, @"failed setup must not query"); return 0; }, &result, &error), @"link creation failure");
        Check([[NSData dataWithContentsOfURL:Child(caches, @"nested/data")] isEqual:sentinel], @"setup failure restores data");
        Check(![error.userInfo[@"GestaltCacheRestorationFailed"] boolValue], @"setup failure classified");

        Check(GestaltWithCacheLink(group, target.path, ^int64_t {
            int64_t inner = -99;
            NSError *innerError = nil;
            Check(!GestaltWithCacheLink(group, target.path, ^int64_t { Check(NO, @"overlapping query"); return 0; }, &inner, &innerError), @"overlap rejected");
            return 0;
        }, &result, &error), @"outer lease survives overlapping request");

        @try {
            GestaltWithCacheLink(group, target.path, ^int64_t {
                @throw [NSException exceptionWithName:@"test" reason:nil userInfo:nil];
            }, &result, &error);
            Check(NO, @"exception propagated");
        } @catch (NSException *exception) {
            Check([exception.name isEqual:@"test"], @"expected exception");
        }
        Check([[NSData dataWithContentsOfURL:Child(caches, @"nested/data")] isEqual:sentinel], @"exception restores data");

        Check(!GestaltWithCacheLink(group, target.path, ^int64_t {
            Check([files removeItemAtURL:caches error:nil], @"remove temporary link");
            Check([sentinel writeToURL:caches atomically:YES], @"concurrent replacement");
            return 7;
        }, &result, &error), @"replacement prevents restoration");
        Check([error.userInfo[@"GestaltCacheRestorationFailed"] boolValue], @"restoration failure classified");
        Check([[NSData dataWithContentsOfURL:caches] isEqual:sentinel], @"replacement retained");
        NSURL *preserved = [NSURL fileURLWithPath:error.userInfo[NSFilePathErrorKey]];
        Check([[NSData dataWithContentsOfURL:Child(preserved, @"nested/data")] isEqual:sentinel], @"original retained for recovery");
        Check([[NSData dataWithContentsOfURL:Child(target, @"sentinel")] isEqual:sentinel], @"target unchanged");

        Check([files removeItemAtURL:caches error:nil], @"clear replacement");
        Check([files createSymbolicLinkAtPath:caches.path withDestinationPath:@"/nonexistent/gestaltedit-test" error:nil], @"dangling original");
        Check(GestaltWithCacheLink(group, target.path, ^int64_t { return -5; }, &result, &error), @"dangling original supported");
        Check([[files destinationOfSymbolicLinkAtPath:caches.path error:nil] isEqualToString:@"/nonexistent/gestaltedit-test"], @"dangling original restored");
        Check([files removeItemAtURL:root error:nil], @"test cleanup");
        puts("GestaltCacheLease tests passed");
    }
}
