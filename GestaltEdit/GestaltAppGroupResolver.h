#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface GestaltAppGroupResolver : NSObject
+ (nullable NSString *)usableAppGroup;
+ (NSArray<NSString *> *)usableAppGroups;
@end
NS_ASSUME_NONNULL_END
