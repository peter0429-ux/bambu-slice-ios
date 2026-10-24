//
//  occt_fake.hxx —— OpenCASCADE 的最小桩
//
//  背景：libslic3r 的 Format/STEP.hpp 无条件 include 了四个 OCCT 头文件，
//  没有 feature guard。而 STEP 只是「打开 STEP 文件」用的，iOS 上我们不需要，
//  也不该为了它去交叉编译几十万行的 OpenCASCADE。
//
//  所以这里只提供 **让声明通过** 的最小类型集合：
//    - TopoDS_Shape            值语义的空壳（STEP.hpp 里只作为成员/参数类型）
//    - Message_ProgressIndicator / Message_ProgressScope
//    - XCAFApp_Application / XCAFDoc_ShapeTool / XCAFDoc_DocumentTool / TDocStd_Document
//    - Handle(T) 宏（简化成裸指针）
//
//  注意：这里没有任何实现。凡是真正用到 OCCT 行为的代码路径都不可用——
//  对应地，Format/STEP.cpp 已经被排除在源文件清单之外。
//

#ifndef BBS_OCCT_FAKE_HXX
#define BBS_OCCT_FAKE_HXX

// OCCT 的智能指针宏，桩成裸指针即可满足声明
#ifndef Handle
#define Handle(T) T *
#endif

typedef bool            Standard_Boolean;
typedef int             Standard_Integer;
typedef double          Standard_Real;
typedef char            Standard_Character;
typedef const char *    Standard_CString;

// 必须先于类定义，类内方法要用到
static const Standard_Boolean Standard_False = false;
static const Standard_Boolean Standard_True  = true;

// 值语义的空壳。STEP.hpp 里它是 NamedSolid 的 const 成员，
// 需要有默认构造和拷贝语义。
struct TopoDS_Shape {
    int _placeholder = 0;
};

class Message_ProgressScope {
public:
    Message_ProgressScope() = default;
};

class Message_ProgressIndicator {
public:
    virtual ~Message_ProgressIndicator() = default;
    // 子类会 override 这两个，签名必须完全一致
    virtual Standard_Boolean UserBreak() { return Standard_False; }
    virtual void Show(const Message_ProgressScope &, const Standard_Boolean) {}
    void SetRange(const Standard_Real, const Standard_Real) {}
    void Next() {}
};

class TDocStd_Document {
public:
    TDocStd_Document() = default;
};

class XCAFDoc_ShapeTool {
public:
    XCAFDoc_ShapeTool() = default;
    static XCAFDoc_ShapeTool *GetShapeTool(const void *) { return nullptr; }
    Standard_Boolean IsAssembly(const TopoDS_Shape &) const { return Standard_False; }
    Standard_Boolean IsSimpleShape(const TopoDS_Shape &) const { return Standard_True; }
};

class XCAFDoc_DocumentTool {
public:
    XCAFDoc_DocumentTool() = default;
    static XCAFDoc_ShapeTool *ShapeTool(const void *) { return nullptr; }
};

class XCAFApp_Application {
public:
    XCAFApp_Application() = default;
    static XCAFApp_Application *GetApplication() {
        static XCAFApp_Application instance;
        return &instance;
    }
};

#endif // BBS_OCCT_FAKE_HXX
