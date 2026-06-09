{
  "targets": [
    {
      "target_name": "testobject",
      "type": "shared_library",
      "product_name": "testobject",
      "sources": [
        "src/TestObjectNative.mm"
      ],
      "libraries": [
        "-framework Foundation"
      ],
      "xcode_settings": {
        "CLANG_CXX_LANGUAGE_STANDARD": "c++20",
        "CLANG_ENABLE_OBJC_ARC": "NO",
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
        "GCC_ENABLE_CPP_RTTI": "YES",
        "LD_DYLIB_INSTALL_NAME": "@rpath/testobject.dylib"
      }
    },
    {
      "target_name": "direct",
      "sources": [
        "src/direct_addon.mm"
      ],
      "dependencies": [
        "testobject"
      ],
      "xcode_settings": {
        "CLANG_CXX_LANGUAGE_STANDARD": "c++20",
        "CLANG_ENABLE_OBJC_ARC": "NO",
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
        "GCC_ENABLE_CPP_RTTI": "YES",
        "OTHER_LDFLAGS": [
          "-Wl,-rpath,@loader_path"
        ]
      }
    },
    {
      "target_name": "napi",
      "sources": [
        "src/napi_addon.mm"
      ],
      "dependencies": [
        "testobject"
      ],
      "xcode_settings": {
        "CLANG_CXX_LANGUAGE_STANDARD": "c++20",
        "CLANG_ENABLE_OBJC_ARC": "NO",
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
        "GCC_ENABLE_CPP_RTTI": "YES",
        "OTHER_LDFLAGS": [
          "-Wl,-rpath,@loader_path"
        ]
      }
    },
    {
      "target_name": "napi_hostobject",
      "sources": [
        "src/napi_hostobject_addon.mm"
      ],
      "dependencies": [
        "testobject"
      ],
      "xcode_settings": {
        "CLANG_CXX_LANGUAGE_STANDARD": "c++20",
        "CLANG_ENABLE_OBJC_ARC": "NO",
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
        "GCC_ENABLE_CPP_RTTI": "YES",
        "OTHER_LDFLAGS": [
          "-Wl,-rpath,@loader_path"
        ]
      }
    }
  ]
}
