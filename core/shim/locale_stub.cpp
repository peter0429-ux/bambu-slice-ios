//
//  locale_stub.cpp —— 顶掉 boost.locale 的 to_utf<wchar_t>
//
//  OBJ.cpp 用 boost::locale::conv::to_utf<wchar_t>() 把材质名/文件名从
//  字节串转成宽字符。完整编 boost.locale 要拖 ICU 或 iconv（体积大、链路长），
//  而我们要的能力只是「字节 → 宽字符」，用逐字节扩展就够了。
//
//  这是一个模板显式特化：链接符号与 boost.locale 库里那个实例完全一致，
//  所以不需要再链 -lboost_locale。
//

#include <string>

#include <boost/locale/encoding.hpp>

namespace boost {
namespace locale {
namespace conv {

template <>
std::wstring to_utf<wchar_t>(const char *begin,
                             const char *end,
                             const std::string & /*charset*/,
                             method_type /*how*/) {
    std::wstring out;
    if (begin && end && end > begin)
        out.reserve(static_cast<std::size_t>(end - begin));
    for (const char *p = begin; p != nullptr && p != end; ++p)
        out.push_back(static_cast<wchar_t>(static_cast<unsigned char>(*p)));
    return out;
}

} // namespace conv
} // namespace locale
} // namespace boost
