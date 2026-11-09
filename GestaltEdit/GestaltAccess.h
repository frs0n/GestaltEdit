//
//  GestaltAccess.h
//  GestaltEdit
//
//  High-level service that uses worse_query to acquire a read/write sandbox
//  extension, then reads, edits, saves and backs up
//  com.apple.MobileGestalt.plist.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GestaltAccess : NSObject

+ (instancetype)shared;

/// Acquires a worse_query lease and verifies the plist is writable. Idempotent.
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
