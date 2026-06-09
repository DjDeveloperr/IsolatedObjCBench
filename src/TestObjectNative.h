#pragma once

using IOBNativeTestObjectRef = void*;

extern "C" IOBNativeTestObjectRef IOBNativeTestObjectCreate();
extern "C" void IOBNativeTestObjectRelease(IOBNativeTestObjectRef object);
extern "C" double IOBNativeTestObjectOneOff(IOBNativeTestObjectRef object);
extern "C" double IOBNativeTestObjectAdd(IOBNativeTestObjectRef object, double a, double b);

