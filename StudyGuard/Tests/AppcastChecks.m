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
                NSCAssert([item.versionString isEqualToString:@"151"], @"Latest announced build must be 151");
                if (dictionary[@"enclosure"] != nil) {
                    NSCAssert(!item.informationOnlyUpdate, @"A signed archive must support in-app installation");
                    NSCAssert([item.fileURL.absoluteString isEqualToString:@"https://github.com/Sumi1124/Focus/releases/download/studyguard-v1.5.1/StudyGuard-1.5.1-macOS-universal.dmg"], @"The installer must use the exact published DMG");
                    NSData *signature = [[NSData alloc] initWithBase64EncodedString:dictionary[@"enclosure"][@"sparkle:edSignature"] options:0];
                    NSCAssert(signature.length == 64, @"The signed update must contain an Ed25519 signature");
                } else {
                    NSCAssert(item.informationOnlyUpdate && item.fileURL == nil, @"Announcement must use Sparkle's supported informational mode");
                    NSCAssert([item.infoURL.absoluteString isEqualToString:@"https://github.com/Sumi1124/Focus/releases/tag/studyguard-v1.5.1"], @"Learn More must open the published release");
                }
            } else {
                NSCAssert(!item.informationOnlyUpdate && item.fileURL != nil, @"Existing signed installation updates must remain available");
                NSCAssert([dictionary[@"enclosure"][@"sparkle:edSignature"] length] > 0, @"Existing update signature was removed");
            }
            index++;
        }
        puts("PASS: Sparkle recognizes the 1.5.1 update mode and retains signed older updates");
    }
    return 0;
}
