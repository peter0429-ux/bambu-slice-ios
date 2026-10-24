//
//  opencv2/opencv.hpp —— 兼容层
//
//  libslic3r 里只有「多色涂色」相关代码（ObjColorUtils / TexturePainting）
//  用到 OpenCV，而 OpenCV 在 iOS 上体积巨大，我们不做这块功能。
//
//  这个桩只提供让声明通过的最小表面：cv::Mat / cv::Point / cv::Vec3b
//  和几个读写函数。凡是真正要用图像处理的地方都返回空结果。
//  真正需要图像功能的源文件已经排除在构建之外。
//

#ifndef BBS_OPENCV_SHIM_HPP
#define BBS_OPENCV_SHIM_HPP

#include <string>
#include <vector>
#include <cstddef>

// 全局 typedef：libslic3r 里 uchar / uint64 都不加命名空间直接用
using uchar  = unsigned char;
using uint64 = unsigned long long;

namespace cv {

struct Size;

// 必须是宏，不是枚举：调用方写的是不带 cv:: 的 CV_32FC3，
// 用 enum 的话会出现 "use of undeclared identifier 'CV_32FC3'"。
// 而且宏没定义会导致后面 cv::Mat(...) 构造失败，连带出一串
// "no viable overloaded '='" 的假错误。
#define CV_8UC1   0
#define CV_8UC2   8
#define CV_8UC3   16
#define CV_8UC4   24
#define CV_16UC1  2
#define CV_32S    4
#define CV_32FC1  5
#define CV_32FC2  13
#define CV_32FC3  21
#define CV_32FC4  29


enum ImreadModes {
    IMREAD_UNCHANGED = -1,
    IMREAD_GRAYSCALE = 0,
    IMREAD_COLOR     = 1,
    IMREAD_ANYCOLOR  = 4
};

enum ImwriteFlags {
    IMWRITE_PNG_COMPRESSION = 16
};

// kmeans 的初始化方式。必须是命名空间内的枚举，不能是宏——
// 调用方写 cv::KMEANS_PP_CENTERS，宏会展开成 cv::2 直接语法错。
// 颜色空间转换代码（桩里不真的转换，只占位）
enum ColorConversionCodes {
    COLOR_BGR2RGB  = 4,
    COLOR_RGB2BGR  = 4,
    COLOR_BGR2GRAY = 6,
    COLOR_RGB2HSV  = 40,
    COLOR_HSV2RGB  = 54,
    COLOR_RGB2Lab  = 44,
    COLOR_Lab2RGB  = 56,
    COLOR_RGBA2RGB = 1,
    COLOR_RGB2RGBA = 0
};

enum KmeansFlags {
    KMEANS_RANDOM_CENTERS     = 0,
    KMEANS_USE_INITIAL_LABELS = 1,
    KMEANS_PP_CENTERS         = 2
};



class Mat {
public:
    Mat() = default;
    Mat(int rows_, int cols_, int type_) : rows(rows_), cols(cols_), type_(type_) {}
    Mat(int rows_, int cols_, int type_, const struct Scalar &);

    int rows = 0;
    int cols = 0;
    int type_ = 0;

    int type() const { return type_; }
    bool empty() const { return rows == 0 || cols == 0; }
    std::size_t total() const { return static_cast<std::size_t>(rows) * static_cast<std::size_t>(cols); }
    void release() { rows = cols = 0; }

    unsigned char *ptr() { return nullptr; }
    const unsigned char *ptr() const { return nullptr; }
    Mat clone() const { return *this; }
    Mat &operator=(const Mat &) = default;

    Mat row(int) const { return Mat(); }
    Mat col(int) const { return Mat(); }
    Mat rowRange(int, int) const { return Mat(); }
    Mat colRange(int, int) const { return Mat(); }

    // ObjColorUtils 还会遍历 Mat 的元素、按行取子矩阵、转换类型
    unsigned char *data = nullptr;
    int rows_placeholder = 0;

    unsigned char *begin() { return nullptr; }
    unsigned char *end() { return nullptr; }
    const unsigned char *begin() const { return nullptr; }
    const unsigned char *end() const { return nullptr; }

    Size size() const { return Size(cols, rows); }
    int dims = 2;

    void clear() { rows = cols = 0; }

    template <typename T>
    void emplace_back(T) {}

    // convertTo：桩实现直接赋值（不做真实类型转换）
    void convertTo(Mat &dst, int) const { dst = *this; }
    void convertTo(Mat &dst, int, double, double) const { dst = *this; }

    // ObjColorUtils 会用 at<Vec3f>(y, x) 取像素。桩实现返回静态哑元，
    // 只要不真的读图就不会有问题——这些代码路径我们本来就不执行。
    template <typename T>
    T &at(int = 0, int = 0) {
        static T dummy{};
        return dummy;
    }
    template <typename T>
    const T &at(int = 0, int = 0) const {
        static T dummy{};
        return dummy;
    }
};

struct Point {
    int x = 0;
    int y = 0;
    Point() = default;
    Point(int x_, int y_) : x(x_), y(y_) {}
};

struct Point2f {
    float x = 0;
    float y = 0;
    Point2f() = default;
    Point2f(float x_, float y_) : x(x_), y(y_) {}
};

struct Size {
    int width = 0;
    int height = 0;
    Size() = default;
    Size(int w, int h) : width(w), height(h) {}
};

struct Scalar {
    double v[4] = {0, 0, 0, 0};
    Scalar() = default;
    Scalar(double a, double b = 0, double c = 0, double d = 0) { v[0]=a; v[1]=b; v[2]=c; v[3]=d; }
};

// Mat 的四参构造要看到 Scalar 的完整定义，所以放在这里定义
inline Mat::Mat(int rows_, int cols_, int type_, const Scalar &)
    : rows(rows_), cols(cols_), type_(type_) {}

// ObjColorUtils 用到 TermCriteria（迭代终止条件）
class TermCriteria {
public:
    enum Type { COUNT = 1, MAX_ITER = 1, EPS = 2 };
    TermCriteria() = default;
    TermCriteria(int type_, int maxCount_, double epsilon_)
        : type(type_), maxCount(maxCount_), epsilon(epsilon_) {}
    int type = 0;
    int maxCount = 0;
    double epsilon = 0.0;
};

template <typename T, int N>
struct Vec {
    T val[N] = {};
    Vec() = default;
    // 允许 Vec3b -> Vec3f 这类跨类型赋值（真 OpenCV 也有）
    template <typename U>
    Vec(const Vec<U, N> &o) {
        for (int i = 0; i < N; ++i) val[i] = static_cast<T>(o.val[i]);
    }
    // 真 OpenCV 的 Vec 支持 Vec(a,b,c) 这类变参构造，桩用递归实现
    template <typename A, typename B, typename C, typename D>
    Vec(A a, B b, C c, D d) {
        val[0] = static_cast<T>(a); val[1] = static_cast<T>(b);
        val[2] = static_cast<T>(c); val[3] = static_cast<T>(d);
    }
    template <typename A, typename B, typename C>
    Vec(A a, B b, C c) {
        val[0] = static_cast<T>(a); val[1] = static_cast<T>(b); val[2] = static_cast<T>(c);
    }
    T &operator[](int i) { return val[i]; }
    const T &operator[](int i) const { return val[i]; }
};

using Vec3b = Vec<unsigned char, 3>;
using Vec4b = Vec<unsigned char, 4>;
using Vec3f = Vec<float, 3>;

// 多色涂色用的随机数发生器与 kmeans。桩实现，不做真实运算。
struct RNG {
    unsigned long long state = 123456789;
    unsigned operator()(unsigned) { return 0; }
    int    uniform(int a, int) { return a; }
    double uniform(double a, double) { return a; }
};
static inline RNG &theRNG() { static RNG rng; return rng; }

static inline double kmeans(const Mat &, int, Mat &, TermCriteria, int, int, Mat &) { return 0.0; }
static inline double kmeans(const Mat &, int, Mat &, TermCriteria, int, int, Mat &, int) { return 0.0; }

static inline Mat imread(const std::string &, int = IMREAD_COLOR) { return Mat(); }
static inline bool imwrite(const std::string &, const Mat &, const std::vector<int> & = {}) { return false; }
static inline Mat cvtColor(const Mat &, Mat &dst, int) { dst = Mat(); return dst; }
static inline void resize(const Mat &, Mat &dst, Size) { dst = Mat(); }

} // namespace cv

#endif // BBS_OPENCV_SHIM_HPP
