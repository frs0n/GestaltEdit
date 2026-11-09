// SPDX-License-Identifier: GPL-3.0-or-later
#import "GestaltAppGroupResolver.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <libkern/OSByteOrder.h>

// Copy fixed-size structures only after validating the complete range.
static BOOL ReadBytes(NSData *data, NSUInteger offset, void *out, NSUInteger length)
{
    if (offset > data.length || length > data.length - offset) return NO;
    [data getBytes:out range:NSMakeRange(offset, length)];
    return YES;
}

static NSData *ReadSlice(NSData *data, uint64_t offset, uint64_t length)
{
    if (offset > data.length || length > data.length - offset) return nil;
    return [data subdataWithRange:NSMakeRange((NSUInteger)offset, (NSUInteger)length)];
}

static NSArray *GroupsFromDictionary(id dictionary)
{
    if (![dictionary isKindOfClass:NSDictionary.class]) return nil;
    id groups = dictionary[@"com.apple.security.application-groups"];
    return [groups isKindOfClass:NSArray.class] ? groups : nil;
}

static NSArray *ProcessGroups(void)
{
    void *security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_NOW | RTLD_LOCAL);
    if (!security) return nil;
    CFTypeRef (*makeTask)(CFAllocatorRef) = dlsym(security, "SecTaskCreateFromSelf");
    CFTypeRef (*copyValue)(CFTypeRef, CFStringRef, CFErrorRef *) = dlsym(security, "SecTaskCopyValueForEntitlement");
    NSArray *groups = nil;
    if (makeTask && copyValue) {
        CFTypeRef task = makeTask(NULL);
        if (task) {
            CFTypeRef value = copyValue(task, CFSTR("com.apple.security.application-groups"), NULL);
            if (value) {
                id object = CFBridgingRelease(value);
                if ([object isKindOfClass:NSArray.class]) groups = [object copy];
            }
            CFRelease(task);
        }
    }
    dlclose(security);
    return groups;
}

// Locate the active architecture in an on-disk universal executable.
static NSData *ActiveMachO(NSData *file)
{
    struct fat_header header;
    if (!ReadBytes(file, 0, &header, sizeof(header))) return nil;
    uint32_t magic = OSSwapBigToHostInt32(header.magic);
    if (magic != FAT_MAGIC && magic != FAT_MAGIC_64) return file;
    BOOL wide = magic == FAT_MAGIC_64;
    NSUInteger recordSize = wide ? sizeof(struct fat_arch_64) : sizeof(struct fat_arch);
    uint32_t count = OSSwapBigToHostInt32(header.nfat_arch);
    if (count > (file.length - sizeof(header)) / recordSize) return nil;
    const struct mach_header *active = _dyld_get_image_header(0);
    if (!active) return nil;
    for (uint32_t i = 0; i < count; ++i) {
        NSUInteger position = sizeof(header) + (NSUInteger)i * recordSize;
        cpu_type_t cpu;
        cpu_subtype_t subtype;
        uint64_t offset, size;
        if (wide) {
            struct fat_arch_64 arch;
            if (!ReadBytes(file, position, &arch, sizeof(arch))) return nil;
            cpu = OSSwapBigToHostInt32(arch.cputype);
            subtype = OSSwapBigToHostInt32(arch.cpusubtype);
            offset = OSSwapBigToHostInt64(arch.offset);
            size = OSSwapBigToHostInt64(arch.size);
        } else {
            struct fat_arch arch;
            if (!ReadBytes(file, position, &arch, sizeof(arch))) return nil;
            cpu = OSSwapBigToHostInt32(arch.cputype);
            subtype = OSSwapBigToHostInt32(arch.cpusubtype);
            offset = OSSwapBigToHostInt32(arch.offset);
            size = OSSwapBigToHostInt32(arch.size);
        }
        if (cpu == active->cputype &&
            (subtype & ~CPU_SUBTYPE_MASK) == (active->cpusubtype & ~CPU_SUBTYPE_MASK))
            return ReadSlice(file, offset, size);
    }
    return nil;
}

static NSArray *SignatureGroups(NSData *signature)
{
    uint32_t header[3];
    if (!ReadBytes(signature, 0, header, sizeof(header))) return nil;
    if (OSSwapBigToHostInt32(header[0]) != 0xfade0cc0) return nil;
    NSUInteger length = OSSwapBigToHostInt32(header[1]);
    NSUInteger count = OSSwapBigToHostInt32(header[2]);
    if (length < sizeof(header) || length > signature.length ||
        count > (length - sizeof(header)) / 8) return nil;
    NSData *container = ReadSlice(signature, 0, length);
    for (NSUInteger i = 0; i < count; ++i) {
        uint32_t entry[2], blob[2];
        if (!ReadBytes(container, sizeof(header) + i * sizeof(entry), entry, sizeof(entry))) return nil;
        NSUInteger offset = OSSwapBigToHostInt32(entry[1]);
        if (!ReadBytes(container, offset, blob, sizeof(blob))) continue;
        if (OSSwapBigToHostInt32(blob[0]) != 0xfade7171) continue;
        NSUInteger blobLength = OSSwapBigToHostInt32(blob[1]);
        if (blobLength < sizeof(blob) || !ReadSlice(container, offset, blobLength)) continue;
        NSData *xml = ReadSlice(container, offset + sizeof(blob), blobLength - sizeof(blob));
        id plist = [NSPropertyListSerialization propertyListWithData:xml options:0 format:NULL error:nil];
        NSArray *groups = GroupsFromDictionary(plist);
        if (groups) return groups;
    }
    return nil;
}

static NSArray *ExecutableGroups(void)
{
    const char *image = _dyld_get_image_name(0);
    if (!image) return nil;
    NSData *file = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:image]
                                        options:NSDataReadingMappedIfSafe error:nil];
    NSData *binary = file ? ActiveMachO(file) : nil;
    if (!binary) return nil;
    struct mach_header header;
    if (!ReadBytes(binary, 0, &header, sizeof(header))) return nil;
    if (header.magic != MH_MAGIC && header.magic != MH_MAGIC_64) return nil;
    NSUInteger start = header.magic == MH_MAGIC_64 ? sizeof(struct mach_header_64) : sizeof(header);
    NSData *commands = ReadSlice(binary, start, header.sizeofcmds);
    if (!commands || header.ncmds > commands.length / sizeof(struct load_command)) return nil;
    NSUInteger cursor = 0;
    for (uint32_t i = 0; i < header.ncmds; ++i) {
        struct load_command command;
        if (!ReadBytes(commands, cursor, &command, sizeof(command)) ||
            command.cmdsize < sizeof(command) || command.cmdsize > commands.length - cursor) return nil;
        if (command.cmd == LC_CODE_SIGNATURE) {
            struct linkedit_data_command location;
            if (command.cmdsize < sizeof(location) || !ReadBytes(commands, cursor, &location, sizeof(location))) return nil;
            NSData *signature = ReadSlice(binary, location.dataoff, location.datasize);
            return signature ? SignatureGroups(signature) : nil;
        }
        cursor += command.cmdsize;
    }
    return nil;
}

@implementation GestaltAppGroupResolver
+ (NSString *)usableAppGroup
{
    NSArray *groups = ProcessGroups();
    if (!groups) groups = ExecutableGroups();
    NSMutableOrderedSet *candidates = [NSMutableOrderedSet orderedSet];
    NSString *identifier = NSBundle.mainBundle.bundleIdentifier;
    NSString *preferred = identifier ? [@"group." stringByAppendingString:identifier] : nil;
    if (preferred && [groups containsObject:preferred]) [candidates addObject:preferred];
    for (id group in groups) {
        if ([group isKindOfClass:NSString.class] && [group hasPrefix:@"group."])
            [candidates addObject:group];
    }
    for (NSString *group in candidates) {
        if ([NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group])
            return group;
    }
    return nil;
}
@end
