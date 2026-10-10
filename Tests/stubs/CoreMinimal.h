#pragma once
#include <algorithm>
#include <cmath>
#include <functional>
#include <string>
#include <type_traits>

using int32 = int;
using TCHAR = char;
#ifndef WITH_EDITOR
#define WITH_EDITOR 0
#endif
#ifndef UE_SERVER
#define UE_SERVER 0
#endif
#define TEXT(x) x
#define PI 3.14159265358979323846f
#define KINDA_SMALL_NUMBER 0.0001
#define ECVF_Default 0
#define DEFINE_LOG_CATEGORY_STATIC(...)
template <class... Args>
void MockLog(const char*, Args...) {}
#define UE_LOG(Category, Verbosity, Format, ...) MockLog(Format __VA_OPT__(,) __VA_ARGS__)
#define IMPLEMENT_MODULE(...)

struct FDelegateHandle
{
    bool valid = false;
    bool IsValid() const { return valid; }
    void Reset() { valid = false; }
};

struct FVector
{
    double X = 0;
    double Y = 0;
    double Z = 0;
    FVector() = default;
    FVector(double x, double y, double z) : X(x), Y(y), Z(z) {}
    double Size() const { return std::sqrt(X * X + Y * Y + Z * Z); }
    double Size2D() const { return std::hypot(X, Y); }
    FVector operator/(double divisor) const { return {X / divisor, Y / divisor, Z / divisor}; }
    FVector GetSafeNormal() const
    {
        const auto length = Size();
        return length > 1e-8 ? *this / length : FVector{};
    }
    bool IsNearlyZero() const { return Size() < KINDA_SMALL_NUMBER; }
    static double DotProduct(FVector a, FVector b)
    {
        return a.X * b.X + a.Y * b.Y + a.Z * b.Z;
    }
};

struct FMath
{
    template <class T>
    static T Max(T a, T b) { return std::max(a, b); }
};

template <class T, class A = T>
struct TGuardValue
{
    T& ref;
    T old;
    TGuardValue(T& value, const A& replacement) : ref(value), old(value)
    {
        value = replacement;
    }
    ~TGuardValue() { ref = old; }
};

template <class T>
struct TAutoConsoleVariable
{
    inline static std::string LastName;
    T value;
    TAutoConsoleVariable(const char* name, T initial, const char*, int) : value(initial)
    {
        LastName = name;
    }
    T GetValueOnGameThread() const { return value; }
};
