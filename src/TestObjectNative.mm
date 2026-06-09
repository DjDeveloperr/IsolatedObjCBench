#import "TestObjectNative.h"
#import <Foundation/Foundation.h>

@interface IOBTestObject : NSObject {
 @private
  double seed_;
}

- (instancetype)initWithSeed:(double)seed;
- (double)oneOff;
- (double)add:(double)a b:(double)b;

@end

@implementation IOBTestObject

- (instancetype)init {
  return [self initWithSeed:7.0];
}

- (instancetype)initWithSeed:(double)seed {
  self = [super init];
  if (self != nil) {
    seed_ = seed;
  }
  return self;
}

- (double)oneOff {
  return seed_;
}

- (double)add:(double)a b:(double)b {
  return a + b + seed_;
}

@end

extern "C" IOBNativeTestObjectRef IOBNativeTestObjectCreate() {
  return [[IOBTestObject alloc] init];
}

extern "C" void IOBNativeTestObjectRelease(IOBNativeTestObjectRef object) {
  [(id)object release];
}

extern "C" double IOBNativeTestObjectOneOff(IOBNativeTestObjectRef object) {
  return [(IOBTestObject*)object oneOff];
}

extern "C" double IOBNativeTestObjectAdd(IOBNativeTestObjectRef object, double a, double b) {
  return [(IOBTestObject*)object add:a b:b];
}
