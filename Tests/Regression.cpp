// Compile the actual implementation. These mocks do not simulate UE collision physics.
#include "../Source/SlideMomentum/Private/SlideMomentum.cpp"
#include <iostream>

using Movement=UFGCharacterMovementComponent;
using CalcScope=Scope<void,Movement*,float,float,bool,float>;
using BoolScope=Scope<bool,const Movement*>;
using SpeedScope=Scope<float,const Movement*>;

struct SlideMomentumTestHarness
{
    static bool Slide(Movement& m, bool start, std::function<bool(const Movement*)> original={})
    {
        BoolScope scope;
        int calls=0;
        scope.original=[&](const Movement* self)
        {
            ++calls;
            return original ? original(self) : (start ? self->CanStartSlide() : self->CanSlide());
        };
        if (start) Slot<&Movement::CanStartSlide>::handler(scope,&m);
        else Slot<&Movement::CanSlide>::handler(scope,&m);
        if (!scope.called) scope(&m);
        assert(calls==1);
        return scope.result;
    }
    static void AssertRemoved()
    {
        assert(!Slot<&Movement::CanSlide>::handler);
        assert(!Slot<&Movement::CanStartSlide>::handler);
        assert(!Slot<&Movement::GetMaxSpeed>::handler);
        assert(!Slot<&Movement::CalcVelocity>::handler);
    }
};

void Calc(Movement& m, float dt=.016f, bool fluid=false)
{
    CalcScope scope;
    scope.original=[](auto* self,float a,float b,bool c,float d){self->CalcVelocity(a,b,c,d);};
    const int before=m.originalCalls;
    Slot<&Movement::CalcVelocity>::handler(scope,&m,dt,8.f,fluid,100.f);
    if (!scope.called) scope(&m,dt,8.f,fluid,100.f);
    assert(m.originalCalls==before+1);
}

float MaxSpeed(Movement& m, std::function<float(const Movement*)> original={})
{
    SpeedScope scope;
    int calls=0;
    scope.original=[&](const auto* self){++calls;return original ? original(self) : self->GetMaxSpeed();};
    Slot<&Movement::GetMaxSpeed>::handler(scope,&m);
    if (!scope.called) scope(&m);
    assert(calls==1);
    return scope.result;
}

bool Near(double a,double b){return std::abs(a-b)<0.00001;}

int main()
{
    FSlideMomentumModule mod;
    mod.StartupModule();
    int scenarios=0;
    auto CheckGate=[&](const char* name, auto change)
    {
        Movement m;
        change(m);
        Calc(m);
        assert(Near(m.Velocity.X,400));
        assert(m.accelerationReads==0);
        assert(MaxSpeed(m)==100);
        std::cout << "PASS " << name << '\n';
        ++scenarios;
    };
    CheckGate("flat",[](auto& m){m.CurrentFloor.HitResult.ImpactNormal={0,0,1};});
    CheckGate("downhill",[](auto& m){m.CurrentFloor.HitResult.ImpactNormal={.2,0,std::sqrt(.96)};});
    CheckGate("airborne",[](auto& m){m.grounded=false;});
    CheckGate("crouch released",[](auto& m){m.bWantsToCrouch=false;});
    CheckGate("client",[](auto& m){m.world.mode=NM_Client;});
    CheckGate("listen server",[](auto& m){m.world.mode=NM_ListenServer;});
    CheckGate("dedicated server",[](auto& m){m.world.mode=NM_DedicatedServer;});
    CheckGate("remote player",[](auto& m){m.owner.local=false;});
    CheckGate("AI",[](auto& m){m.owner.player=false;});
    CheckGate("no slide",[](auto& m){m.sliding=false;});
    CheckGate("unwalkable",[](auto& m){m.CurrentFloor.walkable=false;});
    CheckGate("no world",[](auto& m){m.noWorld=true;});
    CheckGate("no owner",[](auto& m){m.noOwner=true;});
    CheckGate("invalid normal",[](auto& m){m.CurrentFloor.HitResult.ImpactNormal={-.2,0,0};});
    CVarSlideMomentumEnabled.value=0;
    CheckGate("disabled",[](auto&){});
    CVarSlideMomentumEnabled.value=1;
    { Movement m;Calc(m);assert(Near(m.Velocity.X,1000)&&m.Velocity.Z==70);assert(m.accelerationReads==1);assert(MaxSpeed(m)==1000);++scenarios; }
    { Movement m;m.CurrentFloor.HitResult.ImpactNormal={-.0002,0,std::sqrt(1-.0002*.0002)};Calc(m);assert(Near(m.Velocity.X,1000));++scenarios; }
    { Movement m;m.acceleration={-1,0,0};Calc(m);assert(Near(m.Velocity.X,400));assert(m.accelerationReads==1);++scenarios; }
    { Movement m;m.acceleration={-1,1,0};Calc(m);assert(Near(m.Velocity.X,400));++scenarios; }
    { Movement m;m.reverse=true;Calc(m);assert(Near(m.Velocity.X,-400));++scenarios; }
    { Movement m;m.turnRadians=PI/3+.01;Calc(m);assert(Near(m.Velocity.Size2D(),400));++scenarios; }
    { Movement m;m.turnRadians=PI/6;Calc(m);assert(Near(m.Velocity.Size2D(),1000));assert(Near(std::atan2(m.Velocity.Y,m.Velocity.X),PI/6));++scenarios; }
    { Movement m;m.speedFactor=1.2;Calc(m);assert(Near(m.Velocity.X,1200));++scenarios; }
    { Movement m;m.interrupt=true;Calc(m);assert(Near(m.Velocity.X,400));++scenarios; }
    { Movement m;Calc(m,0);assert(Near(m.Velocity.X,400));assert(m.accelerationReads==0);++scenarios; }
    { Movement m;Calc(m,-.1f);assert(Near(m.Velocity.X,400));assert(m.accelerationReads==0);++scenarios; }
    { Movement m;Calc(m,.016f,true);assert(Near(m.Velocity.X,400));assert(m.accelerationReads==0);++scenarios; }
    { Movement m;Calc(m);m.Velocity={0,0,0};Calc(m);assert(m.Velocity.Size()==0);++scenarios; }
    { Movement m;m.Velocity={50,0,-123};Calc(m);assert(Near(m.Velocity.X,50));assert(m.Velocity.Z==-123);assert(MaxSpeed(m)==100);++scenarios; }
    { Movement m;const float speed=MaxSpeed(m,[&](const Movement*){m.bWantsToCrouch=false;return 100.f;});assert(speed==100);++scenarios; }
    { Movement m;const float angle=m.OriginalAngle();assert(SlideMomentumTestHarness::Slide(m,false));assert(m.OriginalAngle()==angle);assert(SlideMomentumTestHarness::Slide(m,true));assert(m.OriginalAngle()==angle);++scenarios; }
    { Movement m;m.eligible=false;const float angle=m.OriginalAngle();assert(!SlideMomentumTestHarness::Slide(m,false));assert(m.OriginalAngle()==angle);assert(!SlideMomentumTestHarness::Slide(m,true));assert(m.OriginalAngle()==angle);++scenarios; }
    { Movement m;const float angle=m.OriginalAngle();assert(SlideMomentumTestHarness::Slide(m,false,[&](const Movement*){assert(m.OriginalAngle()==PI);const bool result=SlideMomentumTestHarness::Slide(m,true);assert(m.OriginalAngle()==PI);return result;}));assert(m.OriginalAngle()==angle);++scenarios; }
    { Movement m;m.bWantsToCrouch=false;assert(!SlideMomentumTestHarness::Slide(m,false));assert(!SlideMomentumTestHarness::Slide(m,true));++scenarios; }
    assert(!IsUphillCrouch(nullptr));
    assert(!IsUphillSlide(nullptr));
    ++scenarios;
    mod.ShutdownModule();
    SlideMomentumTestHarness::AssertRemoved();
    mod.ShutdownModule();
    SlideMomentumTestHarness::AssertRemoved();
    ++scenarios;
    mod.StartupModule();
    { Movement m;Calc(m);assert(Near(m.Velocity.X,1000));++scenarios; }
    mod.ShutdownModule();
    SlideMomentumTestHarness::AssertRemoved();
    std::cout << scenarios << " regression scenarios passed (mock engine/SML).\n";
}
