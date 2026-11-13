#import <Foundation/Foundation.h>
#include <stdint.h>

// Returns NO if setup or restoration fails. The caller must release any
// acquired handle in that case. Existing cache contents are never deleted.
BOOL GestaltWithCacheLink(NSURL *groupRoot, NSString *target,
                         int64_t (^operation)(void), int64_t *result,
                         NSError **error);
