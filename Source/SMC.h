// Read-only AppleSMC interface, informed by exelban/Stats (MIT).
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#include <unistd.h>
#import <IOKit/IOKitLib.h>
#include <math.h>
#include <stddef.h>
typedef struct { uint8_t major,minor,build,reserved; uint16_t release; } SMCVersion;
typedef struct { uint16_t version,length; uint32_t cpu,gpu,mem; } SMCLimits;
typedef struct { uint32_t size,type; uint8_t attributes; } SMCInfo;
typedef struct { uint32_t key; SMCVersion version; SMCLimits limits; SMCInfo info; uint8_t result,status,command; uint32_t index; uint8_t bytes[32]; } SMCData;
_Static_assert(sizeof(SMCData)==80, "SMC ABI size");
_Static_assert(offsetof(SMCData,bytes)==48, "SMC ABI offset");
static uint32_t FourCC(const char *s) { return ((uint32_t)(uint8_t)s[0]<<24)|((uint32_t)(uint8_t)s[1]<<16)|((uint32_t)(uint8_t)s[2]<<8)|(uint8_t)s[3]; }
static io_connect_t OpenSMC(void) {
    io_service_t svc=IOServiceGetMatchingService(kIOMainPortDefault,IOServiceMatching("AppleSMC"));
    if(!svc) return 0;
    io_connect_t c=0; kern_return_t r=IOServiceOpen(svc,mach_task_self(),0,&c); IOObjectRelease(svc);
    return r==KERN_SUCCESS?c:0;
}
static BOOL SMCCall(io_connect_t c,SMCData *in,SMCData *out) {
    size_t size=sizeof(*out); memset(out,0,size);
    return c && IOConnectCallStructMethod(c,2,in,sizeof(*in),out,&size)==KERN_SUCCESS && size==sizeof(*out) && out->result==0;
}
static double SMCRead(io_connect_t c,NSString *key) {
    if(key.length!=4) return NAN;
    SMCData in={0},out={0}; in.key=FourCC(key.UTF8String); in.command=9;
    if(!SMCCall(c,&in,&out) || out.info.size==0 || out.info.size>32) return NAN;
    SMCInfo info=out.info; in.info.size=info.size; in.command=5;
    if(!SMCCall(c,&in,&out)) return NAN;
    double v=NAN;
    if(info.type==FourCC("flt ") && info.size==4) { float f; memcpy(&f,out.bytes,4); v=f; }
    else if(info.type==FourCC("sp78") && info.size==2) { v=(int16_t)((out.bytes[0]<<8)|out.bytes[1])/256.0; }
    return isfinite(v) && v>=1 && v<=130 ? v : NAN;
}
static NSArray<NSString *> *CPUKeys(void) { return @[@"Tp00",@"Tp04",@"Tp08",@"Tp0C",@"Tp0G",@"Tp0K",@"Tp0O",@"Tp0R",@"Tp0U",@"Tp0X",@"Tp0a",@"Tp0d",@"Tp0g",@"Tp0j",@"Tp0m",@"Tp0p",@"Tp0u",@"Tp0y"]; }
static NSArray<NSString *> *GPUKeys(void) { return @[@"Tg0U",@"Tg0X",@"Tg0d",@"Tg0g",@"Tg0j",@"Tg1Y",@"Tg1c",@"Tg1g"]; }
