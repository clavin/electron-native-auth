{
  'targets': [
    {
      'target_name': 'electron_native_auth',
      'dependencies': [
        "<!(node -p \"require('node-addon-api').targets\"):node_addon_api_except",
      ],
      'conditions': [
        # https://github.com/nodejs/node-addon-api/blob/294a43f8c6a4c79b3295a8f1b83d4782d44cfe74/doc/setup.md
        ['OS=="mac"', {
          'cflags+': ['-fvisibility=hidden'],
          'xcode_settings': {
            'GCC_SYMBOLS_PRIVATE_EXTERN': 'YES', # -fvisibility=hidden
          }
        }],
        ['OS=="mac"', {
          'sources': ['src/addon_mac.mm'],
          'xcode_settings': {
            'OTHER_CFLAGS': ['-mmacos-version-min=10.15'],
            'OTHER_LDFLAGS': ['-framework AuthenticationServices'],
            'GCC_GENERATE_DEBUGGING_SYMBOLS': 'YES',
            'DEBUG_INFORMATION_FORMAT': 'dwarf-with-dsym',
          },
        },
        # else
        {
          'sources': ['src/addon_none.cc'],
        }],
      ],
    },
  ],
}
