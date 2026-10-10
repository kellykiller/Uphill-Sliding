#pragma once
#include <cmath>
#include <algorithm>
#include <functional>
#include <type_traits>
#include <string>
using int32=int;
#ifndef WITH_EDITOR
#define WITH_EDITOR 0
#endif
#ifndef UE_SERVER
#define UE_SERVER 0
#endif
using TCHAR=char;
#define TEXT(x) x
#define PI 3.14159265358979323846f
#define KINDA_SMALL_NUMBER 0.0001
#define ECVF_Default 0
#define DEFINE_LOG_CATEGORY_STATIC(...)
template<class... Args> void MockLog(const char*, Args...) {}
#define UE_LOG(Category, Verbosity, Format, ...) MockLog(Format __VA_OPT__(,) __VA_ARGS__)
#define IMPLEMENT_MODULE(...)
struct FDelegateHandle { bool valid=false; bool IsValid()const{return valid;} void Reset(){valid=false;} };
struct FVector {double X=0,Y=0,Z=0; FVector()=default; FVector(double x,double y,double z):X(x),Y(y),Z(z){} double Size()const{return std::sqrt(X*X+Y*Y+Z*Z);} double Size2D()const{return std::hypot(X,Y);} FVector operator/(double n)const{return {X/n,Y/n,Z/n};} FVector GetSafeNormal()const {auto n=Size(); return n>1e-8?*this/n:FVector{};} bool IsNearlyZero()const{return Size()<KINDA_SMALL_NUMBER;} static double DotProduct(FVector a,FVector b){return a.X*b.X+a.Y*b.Y+a.Z*b.Z;} };
struct FMath {template<class T> static T Max(T a,T b){return std::max(a,b);}};
template<class T,class A=T> struct TGuardValue {T& ref;T old;TGuardValue(T& r,const A& a):ref(r),old(r){r=a;}~TGuardValue(){ref=old;}};
template<class T> struct TAutoConsoleVariable {inline static std::string LastName;T value;TAutoConsoleVariable(const char* n,T v,const char*,int):value(v){LastName=n;} T GetValueOnGameThread()const{return value;}};
