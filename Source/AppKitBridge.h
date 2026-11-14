// Minimal public AppKit declarations for this machine's incomplete SDK.
// Runtime implementations are supplied entirely by Apple's AppKit framework.
// No private AppKit methods are used. Keep signatures aligned with SDK headers.
#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>
@class NSString, NSImage, NSFont, NSMenu, NSMenuItem, NSStatusItem, NSStatusBarButton, NSNotificationCenter;
@protocol NSApplicationDelegate <NSObject> @end
@protocol NSMenuDelegate <NSObject> @end
@interface NSApplication : NSObject
+ (NSApplication *)sharedApplication;
@property(weak) id delegate;
- (BOOL)setActivationPolicy:(NSInteger)policy;
- (void)run;
- (void)terminate:(id)sender;
@end
extern NSApplication *NSApp;
enum { NSApplicationActivationPolicyAccessory=1, NSControlStateValueOff=0, NSControlStateValueOn=1, NSImageLeft=2 };
static const CGFloat NSVariableStatusItemLength = -1.0;
extern const CGFloat NSFontWeightMedium;
@interface NSStatusBar : NSObject
+ (NSStatusBar *)systemStatusBar;
- (NSStatusItem *)statusItemWithLength:(CGFloat)length;
@end
@interface NSStatusItem : NSObject
@property(readonly) NSStatusBarButton *button;
@property(strong) NSMenu *menu;
@end
@interface NSStatusBarButton : NSObject
@property(strong) NSFont *font;
@property(copy) NSString *title;
@property(copy) NSString *toolTip;
@property(strong) NSImage *image;
@property NSInteger imagePosition;
@end
@interface NSFont : NSObject
+ (NSFont *)monospacedDigitSystemFontOfSize:(CGFloat)size weight:(CGFloat)weight;
@end
@interface NSImage : NSObject
+ (NSImage *)imageWithSystemSymbolName:(NSString *)name accessibilityDescription:(NSString *)description;
@property(getter=isTemplate) BOOL template;
@end
@interface NSMenu : NSObject
@property(weak) id delegate;
@property BOOL autoenablesItems;
@property(readonly) NSInteger numberOfItems;
@property(readonly,copy) NSArray<NSMenuItem *> *itemArray;
- (void)addItem:(NSMenuItem *)item;
@end
@interface NSMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)equivalent;
+ (NSMenuItem *)separatorItem;
@property(copy) NSString *title;
@property(copy) NSString *keyEquivalent;
@property(weak) id target;
@property SEL action;
@property(getter=isEnabled) BOOL enabled;
@property(getter=isHidden) BOOL hidden;
@property NSInteger state;
@property NSInteger tag;
@property(strong) id representedObject;
@property(strong) NSMenu *submenu;
@end
@interface NSWorkspace : NSObject
+ (NSWorkspace *)sharedWorkspace;
@property(readonly,strong) NSNotificationCenter *notificationCenter;
@end
extern NSString * const NSWorkspaceDidWakeNotification;
@interface NSRunningApplication : NSObject
+ (NSArray<NSRunningApplication *> *)runningApplicationsWithBundleIdentifier:(NSString *)bundleID;
@end
