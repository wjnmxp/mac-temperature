#import "SMC.h"
#import "AppKitBridge.h"
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSJSONSerialization.h>
#import <Foundation/NSData.h>
#import <dispatch/dispatch.h>
#include <stdio.h>

static NSDictionary *ReadGroup(io_connect_t c,NSArray<NSString *> *keys) {
    NSMutableDictionary *values=[NSMutableDictionary dictionary];
    for(NSString *key in keys) { double v=SMCRead(c,key); if(isfinite(v)) values[key]=@(v); }
    return values;
}
static double Maximum(NSDictionary *values) {
    double v=NAN; for(NSNumber *n in values.allValues) if(!isfinite(v)||n.doubleValue>v) v=n.doubleValue; return v;
}
static double Average(NSDictionary *values) {
    if(!values.count) return NAN; double sum=0; for(NSNumber *n in values.allValues) sum+=n.doubleValue; return sum/values.count;
}
static NSString *Degrees(double v) { return isfinite(v)?[NSString stringWithFormat:@"%.1f°C",v]:@"暂不可用"; }
static NSString *ThermalState(void) {
    switch(NSProcessInfo.processInfo.thermalState) {
        case NSProcessInfoThermalStateNominal: return @"正常";
        case NSProcessInfoThermalStateFair: return @"轻度热压力";
        case NSProcessInfoThermalStateSerious: return @"较高热压力";
        case NSProcessInfoThermalStateCritical: return @"严重热压力";
    }
    return @"未知";
}

@interface TemperatureApp : NSObject <NSApplicationDelegate,NSMenuDelegate>
@property NSStatusItem *statusItem;
@property NSMenu *menu;
@property NSMenuItem *cpuMaxItem,*cpuAverageItem,*gpuMaxItem,*thermalItem,*updatedItem,*cpuChoice,*gpuChoice,*sensorItem;
@property NSArray<NSMenuItem *> *intervalItems;
@property NSTimer *timer;
@property dispatch_queue_t queue;
@property io_connect_t connection;
@property BOOL sampling;
@property NSDictionary *cpuValues,*gpuValues;
@property NSDate *lastSample;
@property NSDateFormatter *dateFormatter;
@property NSString *displayMode;
@property NSTimeInterval interval;
@end

@implementation TemperatureApp
- (NSMenuItem *)row:(NSString *)title action:(SEL)action {
    NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    item.target=action?self:nil; [self.menu addItem:item]; return item;
}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    self.queue=dispatch_queue_create("local.mactemperature.sensors",DISPATCH_QUEUE_SERIAL);
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    self.displayMode=[[defaults stringForKey:@"displayMode"] isEqual:@"gpu"]?@"gpu":@"cpu";
    double saved=[defaults doubleForKey:@"interval"];
    self.interval=(saved==3||saved==5||saved==10)?saved:3;
    self.dateFormatter=[NSDateFormatter new]; self.dateFormatter.dateFormat=@"HH:mm:ss";
    self.statusItem=[NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.font=[NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightMedium];
    NSImage *icon=[NSImage imageWithSystemSymbolName:@"thermometer.medium" accessibilityDescription:@"温度计"];
    icon.template=YES; self.statusItem.button.image=icon;
    self.statusItem.button.imagePosition=NSImageLeft;
    self.statusItem.button.title=@"…°C";
    self.menu=[NSMenu new]; self.menu.delegate=self; self.menu.autoenablesItems=NO;
    [self row:@"温度计 · M5" action:NULL].enabled=NO;
    [self.menu addItem:NSMenuItem.separatorItem];
    self.cpuMaxItem=[self row:@"CPU 最高温度　读取中…" action:NULL];
    self.cpuAverageItem=[self row:@"CPU 平均温度　读取中…" action:NULL];
    self.gpuMaxItem=[self row:@"GPU 最高温度　读取中…" action:NULL];
    self.thermalItem=[self row:@"系统散热状态　读取中…" action:NULL];
    self.updatedItem=[self row:@"正在读取传感器…" action:NULL]; self.updatedItem.enabled=NO;
    [self.menu addItem:NSMenuItem.separatorItem];
    self.sensorItem=[self row:@"传感器详情" action:NULL];
    self.sensorItem.submenu=[NSMenu new]; self.sensorItem.submenu.autoenablesItems=NO;
    [self.menu addItem:NSMenuItem.separatorItem];
    self.cpuChoice=[self row:@"顶部显示 CPU 最高温度" action:@selector(selectCPU:)];
    self.gpuChoice=[self row:@"顶部显示 GPU 最高温度" action:@selector(selectGPU:)];
    NSMenuItem *refresh=[self row:@"刷新间隔" action:NULL];
    refresh.submenu=[NSMenu new]; refresh.submenu.autoenablesItems=NO;
    NSMutableArray *intervals=[NSMutableArray array];
    for(NSNumber *n in @[@3,@5,@10]) {
        NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"每 %@ 秒",n] action:@selector(selectInterval:) keyEquivalent:@""];
        item.target=self; item.tag=n.integerValue; [refresh.submenu addItem:item]; [intervals addObject:item];
    }
    self.intervalItems=intervals;
    [self row:@"立即刷新" action:@selector(tick:)];
    [self.menu addItem:NSMenuItem.separatorItem];
    [self row:@"芯片传感器温度 · 非机身表面温度" action:NULL].enabled=NO;
    [self row:@"仅本地读取 · 无需管理员权限" action:NULL].enabled=NO;
    [self.menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit=[self row:@"退出温度计" action:@selector(quit:)]; quit.keyEquivalent=@"q";
    self.statusItem.menu=self.menu;
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(woke:) name:NSWorkspaceDidWakeNotification object:nil];
    [self configureTimer]; [self updateDisplay]; [self tick:nil];
}
- (void)configureTimer {
    [self.timer invalidate];
    self.timer=[NSTimer timerWithTimeInterval:self.interval target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    self.timer.tolerance=self.interval*0.15;
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    for(NSMenuItem *item in self.intervalItems) item.state=item.tag==self.interval?NSControlStateValueOn:NSControlStateValueOff;
}
- (void)tick:(id)sender {
    if(self.sampling) return; self.sampling=YES;
    dispatch_async(self.queue,^{ @autoreleasepool {
        if(!self.connection) self.connection=OpenSMC();
        NSDictionary *cpu=ReadGroup(self.connection,CPUKeys()),*gpu=ReadGroup(self.connection,GPUKeys());
        if(!cpu.count&&!gpu.count&&self.connection) { IOServiceClose(self.connection); self.connection=0; }
        dispatch_async(dispatch_get_main_queue(),^{
            self.cpuValues=cpu; self.gpuValues=gpu; self.lastSample=[NSDate date]; self.sampling=NO;
            [self updateDisplay];
        });
    }});
}
- (void)updateDisplay {
    BOOL gpu=[self.displayMode isEqual:@"gpu"];
    double cpuMax=Maximum(self.cpuValues),gpuMax=Maximum(self.gpuValues),selected=gpu?gpuMax:cpuMax;
    self.statusItem.button.title=isfinite(selected)?[NSString stringWithFormat:@"%.0f°C",selected]:@"--°C";
    self.statusItem.button.toolTip=[NSString stringWithFormat:@"%@ 传感器最高温度：%@\nCPU：%@ · GPU：%@\n每 %.0f 秒刷新 · 点击查看详情",gpu?@"GPU":@"CPU",Degrees(selected),Degrees(cpuMax),Degrees(gpuMax),self.interval];
    self.cpuMaxItem.title=[@"CPU 最高温度　" stringByAppendingString:Degrees(cpuMax)];
    self.cpuAverageItem.title=[@"CPU 平均温度　" stringByAppendingString:Degrees(Average(self.cpuValues))];
    self.gpuMaxItem.title=[@"GPU 最高温度　" stringByAppendingString:Degrees(gpuMax)];
    self.thermalItem.title=[@"系统散热状态　" stringByAppendingString:ThermalState()];
    self.updatedItem.title=self.lastSample?[NSString stringWithFormat:@"更新于 %@ · CPU %lu / GPU %lu 个传感器",[self.dateFormatter stringFromDate:self.lastSample],(unsigned long)self.cpuValues.count,(unsigned long)self.gpuValues.count]:@"正在读取传感器…";
    if(self.lastSample&&!self.cpuValues.count&&!self.gpuValues.count) self.updatedItem.title=@"传感器暂不可用 · 将自动重试";
    self.cpuChoice.state=gpu?NSControlStateValueOff:NSControlStateValueOn;
    self.gpuChoice.state=gpu?NSControlStateValueOn:NSControlStateValueOff;
    // Keep submenu items stable while the menu is open.
    NSMenu *details=self.sensorItem.submenu;
    NSArray *keys=[CPUKeys() arrayByAddingObjectsFromArray:GPUKeys()];
    if(!details.numberOfItems) for(NSString *key in keys) {
        NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:key action:NULL keyEquivalent:@""]; item.representedObject=key; [details addItem:item];
    }
    for(NSMenuItem *item in details.itemArray) {
        NSString *key=item.representedObject; NSNumber *v=self.cpuValues[key]?:self.gpuValues[key];
        item.hidden=(v==nil); item.title=[NSString stringWithFormat:@"%@  %@　%@",[key hasPrefix:@"Tp"]?@"CPU":@"GPU",key,Degrees(v?v.doubleValue:NAN)];
    }
}
- (void)menuWillOpen:(NSMenu *)menu { [self tick:nil]; }
- (void)selectCPU:(id)sender { self.displayMode=@"cpu"; [NSUserDefaults.standardUserDefaults setObject:self.displayMode forKey:@"displayMode"]; [self updateDisplay]; }
- (void)selectGPU:(id)sender { self.displayMode=@"gpu"; [NSUserDefaults.standardUserDefaults setObject:self.displayMode forKey:@"displayMode"]; [self updateDisplay]; }
- (void)selectInterval:(NSMenuItem *)sender { self.interval=sender.tag; [NSUserDefaults.standardUserDefaults setDouble:self.interval forKey:@"interval"]; [self configureTimer]; [self updateDisplay]; }
- (void)woke:(NSNotification *)note {
    dispatch_async(self.queue,^{ if(self.connection) IOServiceClose(self.connection); self.connection=0; });
    [self tick:nil];
}
- (void)quit:(id)sender { [NSApp terminate:nil]; }
- (void)applicationWillTerminate:(NSNotification *)note {
    [self.timer invalidate]; [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    dispatch_sync(self.queue,^{ if(self.connection) IOServiceClose(self.connection); self.connection=0; });
}
@end

int main(int argc,const char *argv[]) { @autoreleasepool {
    if(argc>1&&strcmp(argv[1],"--check")==0) {
        io_connect_t c=OpenSMC(); NSDictionary *cpu=ReadGroup(c,CPUKeys()),*gpu=ReadGroup(c,GPUKeys());
        NSDictionary *report=@{@"cpuSensors":cpu,@"gpuSensors":gpu,@"thermalState":ThermalState(),@"userID":@(getuid())};
        NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:NULL];
        fwrite(data.bytes,1,data.length,stdout); printf("\n"); if(c) IOServiceClose(c); return cpu.count?0:1;
    }
    NSApplication *app=[NSApplication sharedApplication];
    // Avoid duplicate menu bar items when the app is opened twice.
    NSArray *running=[NSRunningApplication runningApplicationsWithBundleIdentifier:@"local.yanyan.MacTemperature"];
    if(running.count>1) return 0;
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
    TemperatureApp *delegate=[TemperatureApp new]; app.delegate=delegate; [app run];
} return 0; }
