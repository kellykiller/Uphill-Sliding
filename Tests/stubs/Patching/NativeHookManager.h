#pragma once
#include "CoreMinimal.h"
template<class R,class Self,class...Args> struct Scope {
    std::function<R(Self,Args...)> original;
    R result{};
    bool called=false;
    R operator()(Self self,Args...args){called=true;result=original(self,args...);return result;}
    void Override(R v){called=true;result=v;}
};
template<class Self,class...Args> struct Scope<void,Self,Args...> {
    std::function<void(Self,Args...)> original;bool called=false;
    void operator()(Self self,Args...args){called=true;original(self,args...);}
};
template<class T> struct Traits;
template<class R,class C,class...A> struct Traits<R(C::*)(A...)> {using ScopeType=Scope<R,C*,A...>;using Handler=std::function<void(ScopeType&,C*,A...)>;};
template<class R,class C,class...A> struct Traits<R(C::*)(A...)const> {using ScopeType=Scope<R,const C*,A...>;using Handler=std::function<void(ScopeType&,const C*,A...)>;};
template<auto M> struct Slot {inline static typename Traits<decltype(M)>::Handler handler;};
template<auto M,class H> FDelegateHandle Register(H handler){Slot<M>::handler=handler;return {true};}
template<auto M> void Remove(){Slot<M>::handler={};}
#define SUBSCRIBE_METHOD(M,H) Register<&M>(H)
#define SUBSCRIBE_UOBJECT_METHOD(C,M,H) Register<&C::M>(H)
#define UNSUBSCRIBE_METHOD(M,H) Remove<&M>()
#define UNSUBSCRIBE_UOBJECT_METHOD(C,M,H) Remove<&C::M>()
