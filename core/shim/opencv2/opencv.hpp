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

namespace cv {

enum ImreadModes {
    IMREAD_UNCHANGED = -1,
    IMREAD_GRAYSCALE = 0,
    IMREAD_COLOR     = 1,
    IMREAD_ANYCOLOR  = 4
};

enum ImwriteFlags {
    IMWRITE_PNG_COMPRESSION = 16
};

// 常见像素格式常量（OpenCV 的编码规则：深度 | 通道数<<3）
enum MatTypes {
    CV_8UC1  = 0,
    CV_8UC3  = 16,
    CV_8UC4  = 24,
    CV_32FC1 = 5,
    CV_32FC3 = 21,
    CV_32FC4 = 29
};

class Mat {
public:
    Mat() = default;
    Mat(int rows_, int cols_, int type_) : rows(rows_), cols(cols_), type_(type_) {}

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
    T &operator[](int i) { return val[i]; }
    const T &operator[](int i) const { return val[i]; }
};

using Vec3b = Vec<unsigned char, 3>;
using Vec4b = Vec<unsigned char, 4>;
using Vec3f = Vec<float, 3>;

static inline Mat imread(const std::string &, int = IMREAD_COLOR) { return Mat(); }
static inline bool imwrite(const std::string &, const Mat &, const std::vector<int> & = {}) { return false; }
static inline Mat cvtColor(const Mat &, Mat &dst, int) { dst = Mat(); return dst; }
static inline void resize(const Mat &, Mat &dst, Size) { dst = Mat(); }

enum ColorConversionCodes {
    COLOR_BGR2RGB = 4,
    COLOR_RGB2BGR = 4,
    COLOR_BGR2GRAY = 6,
    COLOR_RGBA2RGB = 1
};

} // namespace cv

#endif // BBS_OPENCV_SHIM_HPP
