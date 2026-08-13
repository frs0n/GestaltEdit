//
//  GestaltAccess.h
//  GestaltEdit
//
//  High-level service that uses bad_query to acquire a read/write sandbox
//  extension, then reads, edits, saves and backs up
//  com.apple.MobileGestalt.plist.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GestaltAccess : NSObject

+ (instancetype)shared;

/// Returns whether this process is running on an iOS or visionOS 27 build that
/// GestaltEdit currently supports (developer beta 1 through beta 4).
+ (BOOL)isRunningSupportedOS;

/// The Darwin build identifier used by the supported-OS check, such as
/// "24A5390f". An empty string means the build identifier could not be read.
+ (NSString *)currentOSBuild;

/// Acquires a bad_query lease and verifies the plist is writable. Idempotent.
- (BOOL)connectWithError:(NSError **)error;

/// Reads and parses the live plist. Detects the on-disk format (XML/binary).
- (nullable NSDictionary *)readGestaltWithError:(NSError **)error;
/// Reads the live plist without parsing or re-serializing it.
- (nullable NSData *)readGestaltDataWithError:(NSError **)error;
/// Rewrites the existing plist inode and preserves its ownership, flags and
/// extended attributes.
- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
