// Compile the actual implementation. These mocks do not simulate UE collision physics.
#include "../Source/UphillSliding/Private/UphillSliding.cpp"
#include <iostream>

using Movement=UFGCharacterMovementComponent;
using CalcScope=Scope<void,Movement*,float,float,bool,float>;
using BoolScope=Scope<bool,const Movement*>;
using SpeedScope=Scope<float,const Movement*>;

struct UphillSlidingTestHarness
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
    FUphillSlidingModule mod;
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
    CheckGate("simulated remote player",[](auto& m){m.world.mode=NM_Client;m.owner.local=false;m.owner.role=ROLE_SimulatedProxy;});
    CheckGate("non-owning autonomous proxy",[](auto& m){m.world.mode=NM_Client;m.owner.local=false;m.owner.role=ROLE_AutonomousProxy;});
    CheckGate("role none",[](auto& m){m.owner.role=ROLE_None;});
    CheckGate("AI",[](auto& m){m.owner.player=false;});
    CheckGate("no slide",[](auto& m){m.sliding=false;});
    CheckGate("unwalkable",[](auto& m){m.CurrentFloor.walkable=false;});
    CheckGate("no world",[](auto& m){m.noWorld=true;});
    CheckGate("no owner",[](auto& m){m.noOwner=true;});
    CheckGate("invalid normal",[](auto& m){m.CurrentFloor.HitResult.ImpactNormal={-.2,0,0};});
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
    { Movement m;const float angle=m.OriginalAngle();assert(UphillSlidingTestHarness::Slide(m,false));assert(m.OriginalAngle()==angle);assert(UphillSlidingTestHarness::Slide(m,true));assert(m.OriginalAngle()==angle);++scenarios; }
    { Movement m;m.eligible=false;const float angle=m.OriginalAngle();assert(!UphillSlidingTestHarness::Slide(m,false));assert(m.OriginalAngle()==angle);assert(!UphillSlidingTestHarness::Slide(m,true));assert(m.OriginalAngle()==angle);++scenarios; }
    { Movement m;const float angle=m.OriginalAngle();assert(UphillSlidingTestHarness::Slide(m,false,[&](const Movement*){assert(m.OriginalAngle()==PI);const bool result=UphillSlidingTestHarness::Slide(m,true);assert(m.OriginalAngle()==PI);return result;}));assert(m.OriginalAngle()==angle);++scenarios; }
    { Movement m;m.bWantsToCrouch=false;assert(!UphillSlidingTestHarness::Slide(m,false));assert(!UphillSlidingTestHarness::Slide(m,true));++scenarios; }
    auto CheckNetworkRole = [&](const char* name, NetMode mode, ENetRole role, bool local)
    {
        Movement m;
        m.world.mode = mode;
        m.owner.role = role;
        m.owner.local = local;
        assert(IsUphillCrouch(&m));
        const float angle = m.OriginalAngle();
        assert(UphillSlidingTestHarness::Slide(m, true));
        assert(UphillSlidingTestHarness::Slide(m, false));
        assert(m.OriginalAngle() == angle);
        assert(MaxSpeed(m) == 1000);
        Calc(m);
        assert(Near(m.Velocity.X, 1000) && m.Velocity.Z == 70);
        std::cout << "PASS " << name << '\n';
        ++scenarios;
    };
    CheckNetworkRole("standalone authority", NM_Standalone, ROLE_Authority, true);
    CheckNetworkRole("owning client prediction", NM_Client, ROLE_AutonomousProxy, true);
    CheckNetworkRole("listen host", NM_ListenServer, ROLE_Authority, true);
    CheckNetworkRole("listen server remote player", NM_ListenServer, ROLE_Authority, false);
    CheckNetworkRole("dedicated server remote player", NM_DedicatedServer, ROLE_Authority, false);

    // Identical supplied inputs/state must yield identical hook decisions on both sides.
    // This does not simulate packets, engine saved moves or UE collision physics.
    for (int scenario = 0; scenario < 7; ++scenario)
    {
        Movement client, server;
        client.world.mode = NM_Client;
        client.owner.role = ROLE_AutonomousProxy;
        server.world.mode = NM_DedicatedServer;
        server.owner.local = false;
        if (scenario == 1) { client.acceleration = server.acceleration = {-1, 0, 0}; }
        if (scenario == 2) { client.CurrentFloor.HitResult.ImpactNormal = server.CurrentFloor.HitResult.ImpactNormal = {0, 0, 1}; }
        if (scenario == 3) { client.CurrentFloor.HitResult.ImpactNormal = server.CurrentFloor.HitResult.ImpactNormal = {.2, 0, std::sqrt(.96)}; }
        if (scenario == 4) { client.bWantsToCrouch = server.bWantsToCrouch = false; }
        if (scenario == 5) { client.turnRadians = server.turnRadians = PI / 6; }
        if (scenario == 6) { client.interrupt = server.interrupt = true; }
        for (int step = 0; step < 8; ++step)
        {
            assert(UphillSlidingTestHarness::Slide(client, true) == UphillSlidingTestHarness::Slide(server, true));
            assert(UphillSlidingTestHarness::Slide(client, false) == UphillSlidingTestHarness::Slide(server, false));
            assert(Near(MaxSpeed(client), MaxSpeed(server)));
            const Movement before = client;
            Calc(client);
            Calc(server);
            assert(Near(client.Velocity.X, server.Velocity.X));
            assert(Near(client.Velocity.Y, server.Velocity.Y));
            assert(Near(client.Velocity.Z, server.Velocity.Z));
            Movement replay = before;
            Calc(replay);
            assert(Near(client.Velocity.X, replay.Velocity.X));
            assert(Near(client.Velocity.Y, replay.Velocity.Y));
            assert(Near(client.Velocity.Z, replay.Velocity.Z));
        }
        ++scenarios;
    }
    assert(!IsUphillCrouch(nullptr));
    assert(!IsUphillSlide(nullptr));
    ++scenarios;
    mod.ShutdownModule();
    UphillSlidingTestHarness::AssertRemoved();
    mod.ShutdownModule();
    UphillSlidingTestHarness::AssertRemoved();
    ++scenarios;
    mod.StartupModule();
    { Movement m;Calc(m);assert(Near(m.Velocity.X,1000));++scenarios; }
    mod.ShutdownModule();
    UphillSlidingTestHarness::AssertRemoved();
    std::cout << scenarios << " regression scenarios passed (mock engine/SML).\n";
}
