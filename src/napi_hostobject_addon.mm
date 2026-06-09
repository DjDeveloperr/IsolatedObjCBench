#include <node_api.h>
#include <v8.h>
#include <v8-version.h>

#include <cstring>

#include "TestObjectNative.h"

namespace isolated_objc_bench {
namespace {

struct HostObjectTestObject {
  IOBNativeTestObjectRef native = nullptr;
};

struct HostObjectInfo {
  napi_env env = nullptr;
  HostObjectTestObject* data = nullptr;
  v8::Global<v8::Value> target;

  HostObjectInfo(napi_env napiEnv,
                 HostObjectTestObject* nativeData,
                 v8::Isolate* isolate,
                 v8::Local<v8::Value> targetValue)
      : env(napiEnv), data(nativeData), target(isolate, targetValue) {}

  ~HostObjectInfo() {
    target.Reset();
  }
};

static_assert(sizeof(v8::Local<v8::Value>) == sizeof(napi_value),
              "Cannot convert between v8::Local<v8::Value> and napi_value");

napi_value JsValueFromV8LocalValue(v8::Local<v8::Value> local) {
  return reinterpret_cast<napi_value>(*local);
}

v8::Local<v8::Value> V8LocalValueFromJsValue(napi_value value) {
  v8::Local<v8::Value> local;
  std::memcpy(static_cast<void*>(&local), &value, sizeof(value));
  return local;
}

bool Check(napi_env env, napi_status status) {
  if (status == napi_ok) {
    return true;
  }

  const napi_extended_error_info* info = nullptr;
  napi_get_last_error_info(env, &info);
  const char* message =
      info != nullptr && info->error_message != nullptr ? info->error_message : "Node-API error";
  napi_throw_error(env, nullptr, message);
  return false;
}

void FinalizeHostObject(napi_env env, void* data, void* hint) {
  (void)env;
  (void)hint;

  auto* hostInfo = static_cast<HostObjectInfo*>(data);
  if (hostInfo == nullptr) {
    return;
  }

  HostObjectTestObject* object = hostInfo->data;
  if (object != nullptr) {
    IOBNativeTestObjectRelease(object->native);
    object->native = nullptr;
    delete object;
  }

  delete hostInfo;
}

HostObjectInfo* GetHostInfo(v8::Local<v8::Object> object) {
  if (object->InternalFieldCount() != 4) {
    return nullptr;
  }
#if V8_MAJOR_VERSION >= 14
  constexpr v8::EmbedderDataTypeTag kHostObjectDataTag = v8::kEmbedderDataTypeTagDefault;
  return static_cast<HostObjectInfo*>(
      object->GetAlignedPointerFromInternalField(0, kHostObjectDataTag));
#else
  return static_cast<HostObjectInfo*>(object->GetAlignedPointerFromInternalField(0));
#endif
}

v8::Local<v8::Object> CallbackHolder(const v8::PropertyCallbackInfo<v8::Value>& info) {
#if V8_MAJOR_VERSION >= 14
  return info.HolderV2();
#else
  return info.Holder();
#endif
}

v8::Local<v8::Object> CallbackHolder(const v8::PropertyCallbackInfo<void>& info) {
#if V8_MAJOR_VERSION >= 14
  return info.HolderV2();
#else
  return info.Holder();
#endif
}

v8::Local<v8::Object> CallbackHolder(const v8::PropertyCallbackInfo<v8::Integer>& info) {
#if V8_MAJOR_VERSION >= 14
  return info.HolderV2();
#else
  return info.Holder();
#endif
}

v8::Local<v8::Object> CallbackHolder(const v8::PropertyCallbackInfo<v8::Boolean>& info) {
#if V8_MAJOR_VERSION >= 14
  return info.HolderV2();
#else
  return info.Holder();
#endif
}

v8::Local<v8::Object> CallbackHolder(const v8::PropertyCallbackInfo<v8::Array>& info) {
#if V8_MAJOR_VERSION >= 14
  return info.HolderV2();
#else
  return info.Holder();
#endif
}

v8::Local<v8::Value> GetPrototype(v8::Local<v8::Object> object) {
#if V8_MAJOR_VERSION >= 14
  return object->GetPrototypeV2();
#else
  return object->GetPrototype();
#endif
}

v8::Maybe<bool> SetPrototype(v8::Local<v8::Object> object,
                             v8::Local<v8::Context> context,
                             v8::Local<v8::Value> prototype) {
#if V8_MAJOR_VERSION >= 14
  return object->SetPrototypeV2(context, prototype);
#else
  return object->SetPrototype(context, prototype);
#endif
}

void SetHostInfo(v8::Local<v8::Object> object, HostObjectInfo* hostInfo) {
#if V8_MAJOR_VERSION >= 14
  constexpr v8::EmbedderDataTypeTag kHostObjectDataTag = v8::kEmbedderDataTypeTagDefault;
  object->SetAlignedPointerInInternalField(0, hostInfo, kHostObjectDataTag);
#else
  object->SetAlignedPointerInInternalField(0, hostInfo);
#endif
}

v8::Intercepted HostGetter(v8::Local<v8::Name> property,
                           const v8::PropertyCallbackInfo<v8::Value>& info) {
  HostObjectInfo* hostInfo = GetHostInfo(CallbackHolder(info));
  if (hostInfo == nullptr) {
    return v8::Intercepted::kNo;
  }

  v8::Isolate* isolate = info.GetIsolate();
  v8::Local<v8::Value> targetValue = hostInfo->target.Get(isolate);
  if (!targetValue->IsObject()) {
    return v8::Intercepted::kNo;
  }

  v8::Local<v8::Value> result;
  if (targetValue.As<v8::Object>()->Get(isolate->GetCurrentContext(), property).ToLocal(&result)) {
    info.GetReturnValue().Set(result);
    return v8::Intercepted::kYes;
  }

  return v8::Intercepted::kNo;
}

v8::Intercepted HostSetter(v8::Local<v8::Name> property,
                           v8::Local<v8::Value> value,
                           const v8::PropertyCallbackInfo<void>& info) {
  HostObjectInfo* hostInfo = GetHostInfo(CallbackHolder(info));
  if (hostInfo == nullptr) {
    return v8::Intercepted::kNo;
  }

  v8::Isolate* isolate = info.GetIsolate();
  v8::Local<v8::Value> targetValue = hostInfo->target.Get(isolate);
  if (!targetValue->IsObject()) {
    return v8::Intercepted::kNo;
  }

  targetValue.As<v8::Object>()->Set(isolate->GetCurrentContext(), property, value).FromMaybe(false);
  return v8::Intercepted::kYes;
}

v8::Intercepted HostQuery(v8::Local<v8::Name> property,
                          const v8::PropertyCallbackInfo<v8::Integer>& info) {
  HostObjectInfo* hostInfo = GetHostInfo(CallbackHolder(info));
  if (hostInfo == nullptr) {
    return v8::Intercepted::kNo;
  }

  v8::Isolate* isolate = info.GetIsolate();
  v8::Local<v8::Value> targetValue = hostInfo->target.Get(isolate);
  if (targetValue->IsObject() &&
      targetValue.As<v8::Object>()->Has(isolate->GetCurrentContext(), property).FromMaybe(false)) {
    info.GetReturnValue().Set(v8::Integer::New(isolate, v8::None));
    return v8::Intercepted::kYes;
  }

  return v8::Intercepted::kNo;
}

v8::Intercepted HostDeleter(v8::Local<v8::Name> property,
                            const v8::PropertyCallbackInfo<v8::Boolean>& info) {
  HostObjectInfo* hostInfo = GetHostInfo(CallbackHolder(info));
  if (hostInfo == nullptr) {
    return v8::Intercepted::kNo;
  }

  v8::Isolate* isolate = info.GetIsolate();
  v8::Local<v8::Value> targetValue = hostInfo->target.Get(isolate);
  if (!targetValue->IsObject()) {
    return v8::Intercepted::kNo;
  }

  bool deleted =
      targetValue.As<v8::Object>()->Delete(isolate->GetCurrentContext(), property).FromMaybe(false);
  info.GetReturnValue().Set(deleted);
  return v8::Intercepted::kYes;
}

void HostEnumerator(const v8::PropertyCallbackInfo<v8::Array>& info) {
  HostObjectInfo* hostInfo = GetHostInfo(CallbackHolder(info));
  if (hostInfo == nullptr) {
    return;
  }

  v8::Isolate* isolate = info.GetIsolate();
  v8::Local<v8::Value> targetValue = hostInfo->target.Get(isolate);
  if (!targetValue->IsObject()) {
    return;
  }

  v8::Local<v8::Array> names =
      targetValue.As<v8::Object>()->GetPropertyNames(isolate->GetCurrentContext()).ToLocalChecked();
  info.GetReturnValue().Set(names);
}

v8::Intercepted HostIndexedGetter(uint32_t index,
                                  const v8::PropertyCallbackInfo<v8::Value>& info) {
  HostObjectInfo* hostInfo = GetHostInfo(CallbackHolder(info));
  if (hostInfo == nullptr) {
    return v8::Intercepted::kNo;
  }

  v8::Isolate* isolate = info.GetIsolate();
  v8::Local<v8::Value> targetValue = hostInfo->target.Get(isolate);
  if (!targetValue->IsObject()) {
    return v8::Intercepted::kNo;
  }

  v8::Local<v8::Value> result;
  if (targetValue.As<v8::Object>()->Get(isolate->GetCurrentContext(), index).ToLocal(&result)) {
    info.GetReturnValue().Set(result);
    return v8::Intercepted::kYes;
  }

  return v8::Intercepted::kNo;
}

v8::Intercepted HostIndexedSetter(uint32_t index,
                                  v8::Local<v8::Value> value,
                                  const v8::PropertyCallbackInfo<void>& info) {
  HostObjectInfo* hostInfo = GetHostInfo(CallbackHolder(info));
  if (hostInfo == nullptr) {
    return v8::Intercepted::kNo;
  }

  v8::Isolate* isolate = info.GetIsolate();
  v8::Local<v8::Value> targetValue = hostInfo->target.Get(isolate);
  if (!targetValue->IsObject()) {
    return v8::Intercepted::kNo;
  }

  targetValue.As<v8::Object>()->Set(isolate->GetCurrentContext(), index, value).FromMaybe(false);
  return v8::Intercepted::kYes;
}

v8::Intercepted HostIndexedQuery(uint32_t index,
                                 const v8::PropertyCallbackInfo<v8::Integer>& info) {
  HostObjectInfo* hostInfo = GetHostInfo(CallbackHolder(info));
  if (hostInfo == nullptr) {
    return v8::Intercepted::kNo;
  }

  v8::Isolate* isolate = info.GetIsolate();
  v8::Local<v8::Value> targetValue = hostInfo->target.Get(isolate);
  if (targetValue->IsObject() &&
      targetValue.As<v8::Object>()->Has(isolate->GetCurrentContext(), index).FromMaybe(false)) {
    info.GetReturnValue().Set(v8::Integer::New(isolate, v8::None));
    return v8::Intercepted::kYes;
  }

  return v8::Intercepted::kNo;
}

v8::Intercepted HostIndexedDeleter(uint32_t index,
                                   const v8::PropertyCallbackInfo<v8::Boolean>& info) {
  HostObjectInfo* hostInfo = GetHostInfo(CallbackHolder(info));
  if (hostInfo == nullptr) {
    return v8::Intercepted::kNo;
  }

  v8::Isolate* isolate = info.GetIsolate();
  v8::Local<v8::Value> targetValue = hostInfo->target.Get(isolate);
  if (!targetValue->IsObject()) {
    return v8::Intercepted::kNo;
  }

  bool deleted =
      targetValue.As<v8::Object>()->Delete(isolate->GetCurrentContext(), index).FromMaybe(false);
  info.GetReturnValue().Set(deleted);
  return v8::Intercepted::kYes;
}

bool GetHostObjectData(napi_env env, napi_value objectValue, HostObjectTestObject** data) {
  v8::Local<v8::Value> value = V8LocalValueFromJsValue(objectValue);
  if (!value->IsObject()) {
    *data = nullptr;
    return true;
  }

  HostObjectInfo* hostInfo = GetHostInfo(value.As<v8::Object>());
  *data = hostInfo != nullptr ? hostInfo->data : nullptr;
  if (*data == nullptr) {
    napi_throw_error(env, nullptr, "Expected a Node-API host object.");
    return false;
  }

  return true;
}

napi_value CreateHostObject(napi_env env, napi_value targetValue, HostObjectTestObject* object) {
  v8::Local<v8::Value> target = V8LocalValueFromJsValue(targetValue);
  if (!target->IsObject()) {
    napi_throw_error(env, nullptr, "Host object target must be an object.");
    return nullptr;
  }

  v8::Local<v8::Object> targetObject = target.As<v8::Object>();
  v8::Local<v8::Context> context = targetObject->GetCreationContextChecked();
  v8::Isolate* isolate = v8::Isolate::GetCurrent();

  v8::Local<v8::ObjectTemplate> hostTemplate = v8::ObjectTemplate::New(isolate);
  hostTemplate->SetInternalFieldCount(4);
  hostTemplate->SetHandler(v8::NamedPropertyHandlerConfiguration(
      HostGetter,
      HostSetter,
      HostQuery,
      HostDeleter,
      HostEnumerator,
      v8::Local<v8::Value>(),
      v8::PropertyHandlerFlags::kNonMasking));
  hostTemplate->SetHandler(v8::IndexedPropertyHandlerConfiguration(
      HostIndexedGetter,
      HostIndexedSetter,
      HostIndexedQuery,
      HostIndexedDeleter,
      nullptr,
      nullptr,
      nullptr,
      v8::Local<v8::Value>()));

  v8::Local<v8::Object> hostObject;
  if (!hostTemplate->NewInstance(context).ToLocal(&hostObject)) {
    napi_throw_error(env, nullptr, "Failed to create host object.");
    return nullptr;
  }

  auto* hostInfo = new HostObjectInfo(env, object, isolate, target);
  SetHostInfo(hostObject, hostInfo);
  SetPrototype(hostObject, context, GetPrototype(targetObject)).FromMaybe(false);

  napi_value result = JsValueFromV8LocalValue(hostObject);
  if (!Check(env, napi_add_finalizer(env, result, hostInfo, FinalizeHostObject, nullptr, nullptr))) {
    delete hostInfo;
    return nullptr;
  }

  return result;
}

napi_value Constructor(napi_env env, napi_callback_info callbackInfo) {
  napi_value jsThis = nullptr;
  size_t argc = 0;
  if (!Check(env, napi_get_cb_info(env, callbackInfo, &argc, nullptr, &jsThis, nullptr))) {
    return nullptr;
  }

  auto* object = new HostObjectTestObject();
  object->native = IOBNativeTestObjectCreate();

  napi_value hostObject = CreateHostObject(env, jsThis, object);
  if (hostObject == nullptr) {
    IOBNativeTestObjectRelease(object->native);
    delete object;
    return nullptr;
  }

  return hostObject;
}

napi_value OneOff(napi_env env, napi_callback_info callbackInfo) {
  napi_value jsThis = nullptr;
  size_t argc = 0;
  if (!Check(env, napi_get_cb_info(env, callbackInfo, &argc, nullptr, &jsThis, nullptr))) {
    return nullptr;
  }

  HostObjectTestObject* object = nullptr;
  if (!GetHostObjectData(env, jsThis, &object)) {
    return nullptr;
  }

  napi_value result = nullptr;
  Check(env, napi_create_double(env, IOBNativeTestObjectOneOff(object->native), &result));
  return result;
}

napi_value Add(napi_env env, napi_callback_info callbackInfo) {
  napi_value jsThis = nullptr;
  napi_value args[2] = {nullptr, nullptr};
  size_t argc = 2;
  if (!Check(env, napi_get_cb_info(env, callbackInfo, &argc, args, &jsThis, nullptr))) {
    return nullptr;
  }

  HostObjectTestObject* object = nullptr;
  if (!GetHostObjectData(env, jsThis, &object)) {
    return nullptr;
  }

  double a = 0.0;
  double b = 0.0;
  if (argc > 0 && args[0] != nullptr &&
      !Check(env, napi_get_value_double(env, args[0], &a))) {
    return nullptr;
  }
  if (argc > 1 && args[1] != nullptr &&
      !Check(env, napi_get_value_double(env, args[1], &b))) {
    return nullptr;
  }

  napi_value result = nullptr;
  Check(env, napi_create_double(env, IOBNativeTestObjectAdd(object->native, a, b), &result));
  return result;
}

napi_value Init(napi_env env, napi_value exports) {
  napi_value ctor = nullptr;
  if (!Check(env, napi_create_function(env, "NapiHostObjectTestObject", NAPI_AUTO_LENGTH,
                                       Constructor, nullptr, &ctor))) {
    return nullptr;
  }

  napi_value prototype = nullptr;
  napi_value oneOff = nullptr;
  napi_value add = nullptr;
  if (!Check(env, napi_create_object(env, &prototype)) ||
      !Check(env, napi_create_function(env, "oneOff", NAPI_AUTO_LENGTH, OneOff, nullptr, &oneOff)) ||
      !Check(env, napi_create_function(env, "add", NAPI_AUTO_LENGTH, Add, nullptr, &add)) ||
      !Check(env, napi_set_named_property(env, prototype, "oneOff", oneOff)) ||
      !Check(env, napi_set_named_property(env, prototype, "add", add)) ||
      !Check(env, napi_set_named_property(env, ctor, "prototype", prototype))) {
    return nullptr;
  }

  Check(env, napi_set_named_property(env, exports, "TestObject", ctor));
  return exports;
}

}  // namespace
}  // namespace isolated_objc_bench

NAPI_MODULE(NODE_GYP_MODULE_NAME, isolated_objc_bench::Init)
