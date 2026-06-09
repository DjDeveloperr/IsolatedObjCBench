#include <node_api.h>

#include "TestObjectNative.h"

namespace isolated_objc_bench {
namespace {

struct NapiTestObject {
  IOBNativeTestObjectRef native = nullptr;
};

void Finalize(napi_env env, void* data, void* hint) {
  (void)env;
  (void)hint;
  auto* object = static_cast<NapiTestObject*>(data);
  if (object != nullptr) {
    IOBNativeTestObjectRelease(object->native);
    object->native = nullptr;
    delete object;
  }
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

napi_value Constructor(napi_env env, napi_callback_info callbackInfo) {
  napi_value jsThis = nullptr;
  size_t argc = 0;
  if (!Check(env, napi_get_cb_info(env, callbackInfo, &argc, nullptr, &jsThis, nullptr))) {
    return nullptr;
  }

  auto* object = new NapiTestObject();
  object->native = IOBNativeTestObjectCreate();
  if (!Check(env, napi_wrap(env, jsThis, object, Finalize, nullptr, nullptr))) {
    IOBNativeTestObjectRelease(object->native);
    delete object;
    return nullptr;
  }

  return jsThis;
}

napi_value OneOff(napi_env env, napi_callback_info callbackInfo) {
  napi_value jsThis = nullptr;
  size_t argc = 0;
  if (!Check(env, napi_get_cb_info(env, callbackInfo, &argc, nullptr, &jsThis, nullptr))) {
    return nullptr;
  }

  NapiTestObject* object = nullptr;
  if (!Check(env, napi_unwrap(env, jsThis, reinterpret_cast<void**>(&object))) ||
      object == nullptr) {
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

  NapiTestObject* object = nullptr;
  if (!Check(env, napi_unwrap(env, jsThis, reinterpret_cast<void**>(&object))) ||
      object == nullptr) {
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
  napi_property_descriptor methods[] = {
      {"oneOff", nullptr, OneOff, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"add", nullptr, Add, nullptr, nullptr, nullptr, napi_default, nullptr},
  };

  napi_value ctor = nullptr;
  if (!Check(env, napi_define_class(env, "NapiTestObject", NAPI_AUTO_LENGTH, Constructor, nullptr,
                                    2, methods, &ctor))) {
    return nullptr;
  }

  Check(env, napi_set_named_property(env, exports, "TestObject", ctor));
  return exports;
}

}  // namespace
}  // namespace isolated_objc_bench

NAPI_MODULE(NODE_GYP_MODULE_NAME, isolated_objc_bench::Init)
