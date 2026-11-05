//
//  GestaltAccess.m
//  GestaltEdit
//
//  bad_query path traversal (iOS 26 / 27):
//       class 13, MobileGestalt SystemGroup, part 3, target absolute path,
//       flags 0x8000000000; directly consumes the sandbox token

#import "GestaltAccess.h"
#import "BadQueryBridge.h"

#import <errno.h>
#import <fcntl.h>
#import <sys/sysctl.h>
#import <unistd.h>

static NSString * const kGestaltPlistFileName = @"com.apple.MobileGestalt.plist";

static NSString * const kMobileGestaltCacheDirectory =
    @"/private/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";
static NSString * const kBadQueryMobileGestaltCacheDirectory =
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

static void GestaltRestoreDataAtPath(NSString *path, NSData *data)
{
    if (!data) {
        unlink(path.fileSystemRepresentation);
        return;
    }
    int fd = open(path.fileSystemRepresentation, O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return;
    ftruncate(fd, 0);
    lseek(fd, 0, SEEK_SET);
    GestaltWriteAll(fd, data);
    fsync(fd);
    close(fd);
}

@interface GestaltAccess ()
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, copy) NSString *plistPath;
@property (nonatomic, assign) NSPropertyListFormat lastReadFormat;
@property (nonatomic, assign, readwrite) BOOL lastPseudoSupervisionUpdatedPurpleBuddy;
@end

@implementation GestaltAccess
{
    BadQueryLease *_activeBadQueryLease;
}

+ (instancetype)shared
{
    static GestaltAccess *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [GestaltAccess new]; });
    return shared;
}

+ (NSString *)currentOSBuild
{
    size_t length = 0;
    if (sysctlbyname("kern.osversion", NULL, &length, NULL, 0) != 0 ||
        length == 0) {
        return @"";
    }

    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (sysctlbyname("kern.osversion", data.mutableBytes, &length, NULL, 0) != 0)
        return @"";

    return [NSString stringWithUTF8String:data.bytes] ?: @"";
}

+ (BOOL)isRunningSupportedOS
{
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    NSString *build = self.currentOSBuild;

    return version.majorVersion == 27 && (
        [build isEqualToString:@"24A5355q"] || // iOS / iPadOS 27 beta 1
        [build isEqualToString:@"24A5370h"] || // iOS / iPadOS 27 beta 2
        [build isEqualToString:@"24A5380h"] || // iOS / iPadOS 27 beta 3
        [build isEqualToString:@"24A5380i"] || // iPadOS 27 beta 3 v2
        [build isEqualToString:@"24A5380l"] || // iOS / iPadOS 27 Public Beta 1 (revised beta 3, see issue #51)
        [build isEqualToString:@"24A5390f"]    // iOS / iPadOS 27 beta 4
    );
}

#pragma mark - Connection

- (BOOL)connectWithError:(NSError **)error
{
    if (!GestaltAccess.isRunningSupportedOS) {
        if (error) *error = GestaltError(0, NSLocalizedString(
            @"GestaltEdit currently supports only iOS and iPadOS 27 beta 1 through beta 4.", nil));
        return NO;
    }

    if (self.isConnected && _activeBadQueryLease.isActive &&
        self.plistPath.length > 0) {
        if (error) *error = nil;
        return YES;
    }

    if (!BadQueryBridgeAvailable()) {
        if (error) *error = GestaltError(1, NSLocalizedString(
            @"bad_query is unavailable (required ContainerManager or sandbox extension APIs are missing).", nil));
        return NO;
    }

    [_activeBadQueryLease invalidate];
    _activeBadQueryLease = nil;
    self.isConnected = NO;
    self.plistPath = nil;

    NSString *badQueryTarget = [kBadQueryMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];
    NSString *badQueryPlist = [kMobileGestaltCacheDirectory
        stringByAppendingPathComponent:kGestaltPlistFileName];
    NSString *badQueryDetail = nil;
    BadQueryLease *badQueryLease = [BadQueryLease leaseForPath:badQueryTarget
                                                        error:&badQueryDetail];
    if (!badQueryLease) {
        if (error) *error = GestaltError(2,
            badQueryDetail ?: NSLocalizedString(@"bad_query failed.", nil));
        return NO;
    }
    if (!GestaltCanOpenReadWrite(badQueryPlist)) {
        [badQueryLease invalidate];
        if (error) *error = GestaltError(3, NSLocalizedString(
            @"bad_query acquired a sandbox extension, but the MobileGestalt plist is not writable.", nil));
        return NO;
    }

    _activeBadQueryLease = badQueryLease;
    self.isConnected = YES;
    self.plistPath = badQueryPlist;
    if (error) *error = nil;
    return YES;
}

- (NSDictionary *)readPseudoSupervisionConfigurationWithError:(NSError **)error
{
    NSString * const group = @"systemgroup.com.apple.configurationprofiles";
    NSString *directory = @"/private/var/containers/Shared/SystemGroup/"
                          "systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles";
    NSString *path = [directory stringByAppendingPathComponent:
        @"CloudConfigurationDetails.plist"];
    NSString *detail = nil;
    BadQueryLease *lease = [BadQueryLease leaseForPath:path
                                   containerIdentifier:group
                                                 error:&detail];
    if (!lease) {
        if (error) *error = GestaltError(20, detail ?: NSLocalizedString(
            @"Could not acquire access to the supervision configuration.", nil));
        return nil;
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&readError];
    [lease invalidate];
    if (!data) {
        if (error) *error = readError ?: GestaltError(22,
            NSLocalizedString(@"Could not read the supervision plist.", nil));
        return nil;
    }
    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    id value = [NSPropertyListSerialization propertyListWithData:data
        options:NSPropertyListImmutable format:&format error:&readError];
    if (![value isKindOfClass:NSDictionary.class]) {
        if (error) *error = readError ?: GestaltError(23,
            NSLocalizedString(@"The supervision plist is not a dictionary.", nil));
        return nil;
    }
    if (error) *error = nil;
    return value;
}

- (NSDictionary *)probePseudoSupervisionAccessWithError:(NSError **)error
{
    NSDictionary *value = [self readPseudoSupervisionConfigurationWithError:error];
    if (!value) return nil;
    NSString *cloudPath = @"/private/var/containers/Shared/SystemGroup/"
                          "systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles/CloudConfigurationDetails.plist";
    NSString *cloudDetail = nil;
    BadQueryLease *cloudLease = [BadQueryLease leaseForPath:cloudPath
        containerIdentifier:@"systemgroup.com.apple.configurationprofiles" error:&cloudDetail];
    if (!cloudLease) {
        if (error) *error = GestaltError(21, cloudDetail ?: NSLocalizedString(
            @"Could not acquire write access to the supervision plist.", nil));
        return nil;
    }
    int cloudFD = open(cloudPath.fileSystemRepresentation, O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (cloudFD < 0) {
        int openError = errno;
        [cloudLease invalidate];
        if (error) *error = GestaltError(22, [NSString stringWithFormat:
            NSLocalizedString(@"Supervision plist is not writable (errno=%d).", nil), openError]);
        return nil;
    }
    close(cloudFD);
    [cloudLease invalidate];

    if (error) *error = nil;
    return value;
}

- (BOOL)applyPseudoSupervisionEnabled:(BOOL)enabled
                            skipSetup:(BOOL)skipSetup
                     organizationName:(NSString *)organizationName
                 supervisorCertificate:(NSData *)certificate
                                error:(NSError **)error
{
    self.lastPseudoSupervisionUpdatedPurpleBuddy = NO;
    NSString * const group = @"systemgroup.com.apple.configurationprofiles";
    NSString *cloudPath = @"/private/var/containers/Shared/SystemGroup/"
                          "systemgroup.com.apple.configurationprofiles/Library/ConfigurationProfiles/CloudConfigurationDetails.plist";
    NSString *purplePath = @"/var/Managed Preferences/mobile/com.apple.purplebuddy.plist";
    NSString *cloudDetail = nil;
    BadQueryLease *cloudLease = [BadQueryLease leaseForPath:cloudPath
                                        containerIdentifier:group error:&cloudDetail];
    if (!cloudLease) {
        if (error) *error = GestaltError(24, cloudDetail ?: NSLocalizedString(
            @"Could not acquire access to the supervision configuration.", nil));
        return NO;
    }

    NSError *readError = nil;
    NSData *cloudOriginal = [NSData dataWithContentsOfFile:cloudPath options:0 error:&readError];
    if (!cloudOriginal) {
        [cloudLease invalidate];
        if (error) *error = readError ?: GestaltError(25,
            NSLocalizedString(@"Could not read the supervision configuration.", nil));
        return NO;
    }
    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    id cloudValue = [NSPropertyListSerialization propertyListWithData:cloudOriginal
        options:NSPropertyListMutableContainersAndLeaves format:&format error:&readError];
    if (![cloudValue isKindOfClass:NSMutableDictionary.class]) {
        [cloudLease invalidate];
        if (error) *error = readError ?: GestaltError(26,
            NSLocalizedString(@"The supervision configuration is not a dictionary.", nil));
        return NO;
    }

    NSMutableDictionary *cloud = (NSMutableDictionary *)cloudValue;
    cloud[@"AllowPairing"] = @YES;
    cloud[@"ConfigurationWasApplied"] = @YES;
    cloud[@"CloudConfigurationUIComplete"] = @YES;
    cloud[@"ConfigurationSource"] = @0;
    cloud[@"PostSetupProfileWasInstalled"] = @YES;
    if (skipSetup) {
        cloud[@"SkipSetup"] = @[
            @"Location", @"Restore", @"SIMSetup", @"Android", @"AppleID", @"IntendedUser", @"TOS",
            @"Siri", @"ScreenTime", @"Diagnostics", @"SoftwareUpdate", @"Passcode", @"Biometric",
            @"Payment", @"Zoom", @"DisplayTone", @"MessagingActivationUsingPhoneNumber",
            @"HomeButtonSensitivity", @"CloudStorage", @"ScreenSaver", @"TapToSetup", @"Keyboard",
            @"PreferredLanguage", @"SpokenLanguage", @"WatchMigration", @"OnBoarding",
            @"TVProviderSignIn", @"TVHomeScreenSync", @"Privacy", @"TVRoom", @"iMessageAndFaceTime",
            @"AppStore", @"Safety", @"Multitasking", @"ActionButton", @"TermsOfAddress",
            @"AccessibilityAppearance", @"Welcome", @"Appearance", @"RestoreCompleted", @"UpdateCompleted",
            @"WiFi", @"Display", @"Tone", @"LanguageAndLocale", @"TouchID", @"TrueToneDisplay",
            @"FileVault", @"iCloudStorage", @"iCloudDiagnostics", @"Registration", @"DeviceToDeviceMigration",
            @"UnlockWithWatch", @"Accessibility", @"All", @"ExpressLanguage", @"Language", @"N/A",
            @"Region", @"Avatar", @"DeviceProtection", @"Key", @"LockdownMode", @"Wallpaper",
            @"PrivacySubtitle", @"SecuritySubtitle", @"DataSubtitle", @"AppleIDSubtitle", @"AppearanceSubtitle",
            @"PreferredLang", @"OnboardingSubtitle", @"AppleTVSubtitle", @"Intelligence", @"WebContentFiltering",
            @"CameraButton", @"AdditionalPrivacySettings", @"EnableLockdownMode", @"OSShowcase",
            @"SafetyAndHandling", @"Tips", @"AgeBasedSafetySettings"
        ];
    } else {
        [cloud removeObjectForKey:@"SkipSetup"];
    }

    cloud[@"IsSupervised"] = @(enabled);
    NSString *organization = [organizationName stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (enabled && organization.length > 0) {
        cloud[@"OrganizationName"] = organization;
        cloud[@"OrganizationMagic"] = NSUUID.UUID.UUIDString;
        cloud[@"IsMDMUnremovable"] = @NO;
        if (certificate.length > 0) cloud[@"SupervisorHostCertificates"] = @[certificate];
    } else {
        [cloud removeObjectForKey:@"OrganizationName"];
        [cloud removeObjectForKey:@"OrganizationMagic"];
        [cloud removeObjectForKey:@"IsMDMUnremovable"];
        [cloud removeObjectForKey:@"SupervisorHostCertificates"];
    }

    NSData *cloudUpdated = [NSPropertyListSerialization dataWithPropertyList:cloud
        format:format options:0 error:&readError];
    if (!cloudUpdated) {
        [cloudLease invalidate];
        if (error) *error = readError ?: GestaltError(27,
            NSLocalizedString(@"Could not serialize the supervision configuration.", nil));
        return NO;
    }

    NSString *purpleDetail = nil;
    BadQueryLease *purpleLease = nil;
    if (skipSetup) {
        purpleLease = [BadQueryLease leaseForPath:purplePath
                              containerIdentifier:group error:&purpleDetail];
    }

    NSError *purpleReadError = nil;
    BOOL canWritePurple = purpleLease != nil;
    BOOL purpleExisted = canWritePurple && [[NSFileManager defaultManager] fileExistsAtPath:purplePath];
    NSData *purpleOriginal = skipSetup && canWritePurple
        ? [NSData dataWithContentsOfFile:purplePath options:0 error:&purpleReadError]
        : nil;
    if (skipSetup && canWritePurple && purpleExisted && !purpleOriginal) {
        [purpleLease invalidate];
        [cloudLease invalidate];
        if (error) *error = purpleReadError ?: GestaltError(36,
            NSLocalizedString(@"Could not read existing PurpleBuddy setup state.", nil));
        return NO;
    }
    NSMutableDictionary *purple = [NSMutableDictionary dictionary];
    if (purpleOriginal) {
        id existing = [NSPropertyListSerialization propertyListWithData:purpleOriginal
            options:NSPropertyListMutableContainersAndLeaves format:nil error:&readError];
        if ([existing isKindOfClass:NSDictionary.class]) [purple addEntriesFromDictionary:existing];
    }
    NSData *purpleUpdated = purpleOriginal;
    if (skipSetup && canWritePurple) {
        purple[@"SetupDone"] = @YES;
        purple[@"SetupFinishedAllSteps"] = @YES;
        purple[@"UserChoseLanguage"] = @YES;
        purpleUpdated = [NSPropertyListSerialization dataWithPropertyList:purple
            format:NSPropertyListBinaryFormat_v1_0 options:0 error:&readError];
    }
    if (skipSetup && canWritePurple && !purpleUpdated) {
        [purpleLease invalidate];
        [cloudLease invalidate];
        if (error) *error = readError ?: GestaltError(29,
            NSLocalizedString(@"Could not serialize PurpleBuddy setup state.", nil));
        return NO;
    }

    // Keep a local copy of both original files before either write.
    NSString *backupRoot = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
        NSUserDomainMask, YES).firstObject;
    NSString *backupDir = [[backupRoot stringByAppendingPathComponent:@"Pseudo-Supervision Backups"]
        stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSError *backupError = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:backupDir
        withIntermediateDirectories:YES attributes:nil error:&backupError];
    BOOL backupOK = backupError == nil && [cloudOriginal writeToFile:
        [backupDir stringByAppendingPathComponent:@"CloudConfigurationDetails.plist"]
        options:NSDataWritingAtomic error:&backupError];
    if (backupOK && purpleOriginal) {
        backupOK = [purpleOriginal writeToFile:[backupDir stringByAppendingPathComponent:
            @"com.apple.purplebuddy.plist"] options:NSDataWritingAtomic error:&backupError];
    }
    if (!backupOK) {
        [purpleLease invalidate];
        [cloudLease invalidate];
        if (error) *error = backupError ?: GestaltError(30,
            NSLocalizedString(@"Could not back up supervision files.", nil));
        return NO;
    }

    int cloudFD = open(cloudPath.fileSystemRepresentation, O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
    BOOL cloudWritten = cloudFD >= 0 && ftruncate(cloudFD, 0) == 0 &&
        lseek(cloudFD, 0, SEEK_SET) == 0 && GestaltWriteAll(cloudFD, cloudUpdated) && fsync(cloudFD) == 0;
    int cloudWriteError = errno;
    if (cloudFD >= 0) close(cloudFD);
    if (!cloudWritten) {
        GestaltRestoreDataAtPath(cloudPath, cloudOriginal);
        [purpleLease invalidate];
        [cloudLease invalidate];
        if (error) *error = GestaltError(31, [NSString stringWithFormat:
            NSLocalizedString(@"Could not write CloudConfigurationDetails.plist (errno=%d). The original was restored.", nil), cloudWriteError]);
        return NO;
    }

    int purpleFD = skipSetup && canWritePurple ? open(purplePath.fileSystemRepresentation,
        O_WRONLY | O_CLOEXEC | O_NOFOLLOW | O_CREAT, 0644) : -1;
    BOOL purpleWritten = !skipSetup || !canWritePurple || (purpleFD >= 0 && ftruncate(purpleFD, 0) == 0 &&
        lseek(purpleFD, 0, SEEK_SET) == 0 && GestaltWriteAll(purpleFD, purpleUpdated) && fsync(purpleFD) == 0);
    int purpleWriteError = errno;
    if (purpleFD >= 0) close(purpleFD);
    if (!purpleWritten) {
        // Roll back the cloud plist if the companion setup file cannot be written.
        GestaltRestoreDataAtPath(cloudPath, cloudOriginal);
        GestaltRestoreDataAtPath(purplePath, purpleOriginal);
        [purpleLease invalidate];
        [cloudLease invalidate];
        if (error) *error = GestaltError(32, [NSString stringWithFormat:
            NSLocalizedString(@"Could not write PurpleBuddy setup state (errno=%d). Both originals were restored.", nil), purpleWriteError]);
        return NO;
    }

    NSData *cloudVerification = [NSData dataWithContentsOfFile:cloudPath options:0 error:nil];
    NSData *purpleVerification = [NSData dataWithContentsOfFile:purplePath options:0 error:nil];
    [purpleLease invalidate];
    [cloudLease invalidate];
    if (![cloudVerification isEqualToData:cloudUpdated] ||
        (skipSetup && canWritePurple && ![purpleVerification isEqualToData:purpleUpdated])) {
        // Verification failed: restore the exact original data before reporting.
        cloudLease = [BadQueryLease leaseForPath:cloudPath containerIdentifier:group error:nil];
        purpleLease = [BadQueryLease leaseForPath:purplePath containerIdentifier:group error:nil];
        GestaltRestoreDataAtPath(cloudPath, cloudOriginal);
        GestaltRestoreDataAtPath(purplePath, purpleOriginal);
        [purpleLease invalidate];
        [cloudLease invalidate];
        if (error) *error = GestaltError(33, NSLocalizedString(
            @"Post-write verification failed; original file contents were restored.", nil));
        return NO;
    }
    self.lastPseudoSupervisionUpdatedPurpleBuddy = skipSetup && canWritePurple;
    if (error) *error = nil;
    return YES;
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
