{
  "targets": [
    {
      "target_name": "get_running_process_exit_code",
      "sources": ["get-running-process-exit-code.cpp"],
      "defines!": ["_HAS_EXCEPTIONS=0"],
      "cflags_cc!": ["-fno-exceptions"],
      "conditions": [
        [ "OS==\"win\"", {
          "defines": ["_HAS_EXCEPTIONS=1"],
          "msvs_settings": {
            "VCCLCompilerTool": {
              "ExceptionHandling": 1
            }
          }
        }]
      ],
      "xcode_settings": {
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES"
      },
      "cflags_cc": ["-fexceptions"]
    }
  ]
}
