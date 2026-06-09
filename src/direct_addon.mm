#include <node.h>
#include <node_object_wrap.h>

#include "TestObjectNative.h"

namespace isolated_objc_bench {
namespace {

class DirectTestObject final : public node::ObjectWrap {
 public:
  static void Init(v8::Local<v8::Object> exports, v8::Local<v8::Context> context) {
    v8::Isolate* isolate = v8::Isolate::GetCurrent();
    v8::Local<v8::FunctionTemplate> tpl =
        v8::FunctionTemplate::New(isolate, New);
    tpl->SetClassName(v8::String::NewFromUtf8Literal(isolate, "V8DirectTestObject"));
    tpl->InstanceTemplate()->SetInternalFieldCount(1);

    NODE_SET_PROTOTYPE_METHOD(tpl, "oneOff", OneOff);
    NODE_SET_PROTOTYPE_METHOD(tpl, "add", Add);

    v8::Local<v8::Function> ctor = tpl->GetFunction(context).ToLocalChecked();
    exports
        ->Set(context, v8::String::NewFromUtf8Literal(isolate, "TestObject"), ctor)
        .FromJust();
  }

 private:
  DirectTestObject() : native_(IOBNativeTestObjectCreate()) {}

  ~DirectTestObject() override {
    IOBNativeTestObjectRelease(native_);
    native_ = nullptr;
  }

  static void New(const v8::FunctionCallbackInfo<v8::Value>& info) {
    v8::Isolate* isolate = info.GetIsolate();
    if (!info.IsConstructCall()) {
      isolate->ThrowException(v8::Exception::TypeError(
          v8::String::NewFromUtf8Literal(isolate, "Use new TestObject().")));
      return;
    }

    auto* object = new DirectTestObject();
    object->Wrap(info.This());
    info.GetReturnValue().Set(info.This());
  }

  static void OneOff(const v8::FunctionCallbackInfo<v8::Value>& info) {
    auto* object = node::ObjectWrap::Unwrap<DirectTestObject>(info.This());
    double result = IOBNativeTestObjectOneOff(object->native_);
    info.GetReturnValue().Set(v8::Number::New(info.GetIsolate(), result));
  }

  static void Add(const v8::FunctionCallbackInfo<v8::Value>& info) {
    v8::Isolate* isolate = info.GetIsolate();
    v8::Local<v8::Context> context = isolate->GetCurrentContext();
    auto* object = node::ObjectWrap::Unwrap<DirectTestObject>(info.This());

    double a = info.Length() > 0 ? info[0]->NumberValue(context).FromMaybe(0.0) : 0.0;
    double b = info.Length() > 1 ? info[1]->NumberValue(context).FromMaybe(0.0) : 0.0;
    double result = IOBNativeTestObjectAdd(object->native_, a, b);
    info.GetReturnValue().Set(v8::Number::New(isolate, result));
  }

  IOBNativeTestObjectRef native_ = nullptr;
};

}  // namespace
}  // namespace isolated_objc_bench

void InitDirectAddon(v8::Local<v8::Object> exports,
                     v8::Local<v8::Value> module,
                     v8::Local<v8::Context> context,
                     void* privateData) {
  (void)module;
  (void)privateData;
  isolated_objc_bench::DirectTestObject::Init(exports, context);
}

NODE_MODULE_CONTEXT_AWARE(NODE_GYP_MODULE_NAME, InitDirectAddon)
