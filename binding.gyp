{
  'targets': [
    {
      'target_name': 'electron_native_auth',
      'sources': [
        'src/addon.cc',
        'src/impl_errs.cc'
      ],
      'include_dirs': [
        "<!@(node -p \"require('node-addon-api').include\")",
      ],
      'dependencies': [
        "<!(node -p \"require('node-addon-api').gyp\")",
      ],
      'defines': [
        'NAPI_DISABLE_CPP_EXCEPTIONS',
        'NODE_ADDON_API_ENABLE_MAYBE',
      ],
      'conditions': [
        [
          'OS=="mac"',
          {
            'sources': ['src/impl_mac.mm'],
            'xcode_settings': {
              'OTHER_LDFLAGS': ['-framework AuthenticationServices'],
              'GCC_GENERATE_DEBUGGING_SYMBOLS': 'YES',
              "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
            },
          },
          # else
          {
            'sources': ['src/impl_none.cc'],
          }
        ],
      ],
    },
  ],
}
