#import <Foundation/Foundation.h>
#import <Sparkle/Sparkle.h>

static NSString *qualifiedName(NSXMLNode *node) {
    return node.prefix.length > 0 ? [NSString stringWithFormat:@"%@:%@", node.prefix, node.localName] : node.name;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSCAssert(argc == 2, @"Pass the appcast XML path");
        NSError *error = nil;
        NSURL *url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSXMLDocument *document = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:&error];
        NSCAssert(document != nil, @"Appcast XML could not be read: %@", error);
        NSArray<NSXMLNode *> *items = [document nodesForXPath:@"/rss/channel/item" error:&error];
        NSCAssert(items.count >= 3, @"Expected the new announcement and existing signed releases");
        NSUInteger index = 0;
        for (NSXMLNode *node in items) {
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            for (NSXMLNode *child in node.children) {
                if (child.kind != NSXMLElementKind) { continue; }
                NSString *name = qualifiedName(child);
                if ([name isEqualToString:@"enclosure"]) {
                    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
                    for (NSXMLNode *attribute in ((NSXMLElement *)child).attributes) {
                        attributes[qualifiedName(attribute)] = attribute.stringValue;
                    }
                    dictionary[name] = attributes;
                } else if (![name isEqualToString:@"pubDate"]) {
                    dictionary[name] = child.stringValue;
                }
            }
            NSString *failure = nil;
            SUAppcastItem *item = [[SUAppcastItem alloc] initWithDictionary:dictionary failureReason:&failure];
            NSCAssert(item != nil, @"Sparkle rejected the feed item: %@", failure);
            if (index == 0) {
                NSCAssert(item.versionString.integerValue >= 151, @"The latest announcement must cover Study Notebook or newer");
                NSString *version = dictionary[@"sparkle:shortVersionString"];
                NSCAssert(version.length > 0, @"The update must have a visible version");
                NSString *archiveURL = [NSString stringWithFormat:@"https://github.com/Sumi1124/Focus/releases/download/studyguard-v%@/StudyGuard-%@-macOS-universal.dmg", version, version];
                if (dictionary[@"enclosure"] != nil) {
                    NSCAssert(!item.informationOnlyUpdate, @"A signed archive must support in-app installation");
                    NSCAssert([item.fileURL.absoluteString isEqualToString:archiveURL], @"The installer must use the exact published DMG");
                    NSData *signature = [[NSData alloc] initWithBase64EncodedString:dictionary[@"enclosure"][@"sparkle:edSignature"] options:0];
                    NSCAssert(signature.length == 64, @"The signed update must contain an Ed25519 signature");
                } else {
                    NSCAssert(item.informationOnlyUpdate && item.fileURL == nil, @"Announcement must use Sparkle's supported informational mode");
                    NSCAssert([item.infoURL.absoluteString isEqualToString:archiveURL], @"Learn More must download the exact published installer directly");
                }
            } else if (dictionary[@"enclosure"] != nil) {
                NSCAssert(!item.informationOnlyUpdate && item.fileURL != nil, @"Existing signed installation updates must remain available");
                NSCAssert([dictionary[@"enclosure"][@"sparkle:edSignature"] length] > 0, @"Existing update signature was removed");
            } else {
                NSCAssert(item.informationOnlyUpdate && item.infoURL != nil, @"Older manual-download announcements must remain valid");
            }
            index++;
        }
        puts("PASS: Sparkle recognizes the latest update mode and retains signed older updates");
    }
    return 0;
}
