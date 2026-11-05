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

@property(nonatomic, readonly) BOOL lastPseudoSupervisionUpdatedPurpleBuddy;

+ (instancetype)shared;

/// Returns whether this process is running on an iOS or iPadOS 27 build that
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

/// Attempts to read and open Nugget's supervision plist for writing without
/// changing it. Intended as a capability probe only.
- (nullable NSDictionary *)probePseudoSupervisionAccessWithError:(NSError **)error;
- (nullable NSDictionary *)readPseudoSupervisionConfigurationWithError:(NSError **)error;

/// Writes the same cloud-configuration and PurpleBuddy state used by Nugget.
- (BOOL)applyPseudoSupervisionEnabled:(BOOL)enabled
                            skipSetup:(BOOL)skipSetup
                     organizationName:(NSString *)organizationName
                 supervisorCertificate:(nullable NSData *)certificate
                                error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
