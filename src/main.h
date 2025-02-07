#if defined(__GNUC__)
// Attributes to prevent 'unused' function from being removed and to make it visible
#define FUNCTION_ATTRIBUTE __attribute__((visibility("default"))) __attribute__((used))
#elif defined(_MSC_VER)
// Marking a function for export
#define FUNCTION_ATTRIBUTE __declspec(dllexport)
#endif

#ifdef __cplusplus
extern "C"
{
#endif

    // 定义进度回调函数类型
    typedef void (*dart_progress_callback)(double progress);

    // 添加注册回调的函数声明
    FUNCTION_ATTRIBUTE void register_progress_callback(dart_progress_callback callback);
    FUNCTION_ATTRIBUTE char *request(char *body);

#ifdef __cplusplus
}
#endif