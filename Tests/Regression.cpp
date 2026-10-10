// Compile the actual implementation. These mocks do not simulate UE collision physics.
#include "../Source/UphillSliding/Private/UphillSliding.cpp"
#include "TestSupport.h"

using Movement = UFGCharacterMovementComponent;
using CalcScope = Scope<void, Movement*, float, float, bool, float>;
using BoolScope = Scope<bool, const Movement*>;
using SpeedScope = Scope<float, const Movement*>;

struct UphillSlidingTestHarness
{
    static bool Slide(Movement& movement, bool start, std::function<bool(const Movement*)> original = {})
    {
        BoolScope scope;
        int calls = 0;
        scope.original = [&](const Movement* self)
        {
            ++calls;
            return original ? original(self) : (start ? self->CanStartSlide() : self->CanSlide());
        };
        if (start)
        {
            Slot<&Movement::CanStartSlide>::handler(scope, &movement);
        }
        else
        {
            Slot<&Movement::CanSlide>::handler(scope, &movement);
        }
        if (!scope.called)
        {
            scope(&movement);
        }
        EXPECT(calls == 1);
        return scope.result;
    }
    static void CheckRemoved()
    {
        EXPECT(!Slot<&Movement::CanSlide>::handler);
        EXPECT(!Slot<&Movement::CanStartSlide>::handler);
        EXPECT(!Slot<&Movement::GetMaxSpeed>::handler);
        EXPECT(!Slot<&Movement::CalcVelocity>::handler);
    }
};

void CalculateVelocity(Movement& movement, float dt = .016f, bool fluid = false)
{
    CalcScope scope;
    scope.original = [](auto* self, float dt, float friction, bool fluid, float braking)
    {
        self->CalcVelocity(dt, friction, fluid, braking);
    };
    const int before = movement.originalCalls;
    Slot<&Movement::CalcVelocity>::handler(scope, &movement, dt, 8.f, fluid, 100.f);
    if (!scope.called)
    {
        scope(&movement, dt, 8.f, fluid, 100.f);
    }
    EXPECT(movement.originalCalls == before+1);
}

float ReadMaxSpeed(Movement& movement, std::function<float(const Movement*)> original = {})
{
    SpeedScope scope;
    int calls = 0;
    scope.original = [&](const auto* self)
    {
        ++calls;
        return original ? original(self) : self->GetMaxSpeed();
    };
    Slot<&Movement::GetMaxSpeed>::handler(scope, &movement);
    if (!scope.called)
    {
        scope(&movement);
    }
    EXPECT(calls == 1);
    return scope.result;
}

bool NearlyEqual(double actual, double expected)
{
    return std::abs(actual - expected) < 0.00001;
}

int main(int argc, char** argv)
{
    FUphillSlidingModule module;
    module.StartupModule();
    if (argc > 1 && std::string(argv[1]) == "--verify-failure")
    {
        EXPECT(false); // The runner checks that this fails even with NDEBUG.
    }
    auto CheckGate = [&](const char* name, auto change)
    {
        RunScenario(name, [&]
        {
            Movement movement;
            change(movement);
            CalculateVelocity(movement);
            EXPECT(NearlyEqual(movement.Velocity.X, 400));
            EXPECT(movement.accelerationReads == 0);
            EXPECT(ReadMaxSpeed(movement) == 100);
        });
    };
    CheckGate("flat", [](auto& movement)
    {
        movement.CurrentFloor.HitResult.ImpactNormal = {0, 0, 1};
    });
    CheckGate("downhill", [](auto& movement)
    {
        movement.CurrentFloor.HitResult.ImpactNormal = {.2, 0, std::sqrt(.96)};
    });
    CheckGate("airborne", [](auto& movement)
    {
        movement.grounded = false;
    });
    CheckGate("crouch released", [](auto& movement)
    {
        movement.bWantsToCrouch = false;
    });
    CheckGate("simulated remote player", [](auto& movement)
    {
        movement.world.mode = NM_Client;
        movement.owner.local = false;
        movement.owner.role = ROLE_SimulatedProxy;
    });
    CheckGate("non-owning autonomous proxy", [](auto& movement)
    {
        movement.world.mode = NM_Client;
        movement.owner.local = false;
        movement.owner.role = ROLE_AutonomousProxy;
    });
    CheckGate("role none", [](auto& movement)
    {
        movement.owner.role = ROLE_None;
    });
    CheckGate("AI", [](auto& movement)
    {
        movement.owner.player = false;
    });
    CheckGate("no slide", [](auto& movement)
    {
        movement.sliding = false;
    });
    CheckGate("unwalkable", [](auto& movement)
    {
        movement.CurrentFloor.walkable = false;
    });
    CheckGate("no world", [](auto& movement)
    {
        movement.noWorld = true;
    });
    CheckGate("no owner", [](auto& movement)
    {
        movement.noOwner = true;
    });
    CheckGate("invalid normal", [](auto& movement)
    {
        movement.CurrentFloor.HitResult.ImpactNormal = {-.2, 0, 0};
    });
    RunScenario("retain speed and vertical velocity", [&]
    {
        Movement movement;
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.X, 1000) && movement.Velocity.Z == 70);
        EXPECT(movement.accelerationReads == 1);
        EXPECT(ReadMaxSpeed(movement) == 1000);
    });
    RunScenario("gentle uphill slope", [&]
    {
        Movement movement;
        movement.CurrentFloor.HitResult.ImpactNormal = {-.0002, 0, std::sqrt(1-.0002*.0002)};
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.X, 1000));
    });
    RunScenario("reverse input braking", [&]
    {
        Movement movement;
        movement.acceleration = {-1, 0, 0};
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.X, 400));
        EXPECT(movement.accelerationReads == 1);
    });
    RunScenario("diagonal reverse input braking", [&]
    {
        Movement movement;
        movement.acceleration = {-1, 1, 0};
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.X, 400));
    });
    RunScenario("velocity reversal", [&]
    {
        Movement movement;
        movement.reverse = true;
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.X, -400));
    });
    RunScenario("turn beyond 60 degrees", [&]
    {
        Movement movement;
        movement.turnRadians = PI/3+.01;
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.Size2D(), 400));
    });
    RunScenario("ordinary steering", [&]
    {
        Movement movement;
        movement.turnRadians = PI/6;
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.Size2D(), 1000));
        EXPECT(NearlyEqual(std::atan2(movement.Velocity.Y, movement.Velocity.X), PI/6));
    });
    RunScenario("original acceleration is retained", [&]
    {
        Movement movement;
        movement.speedFactor = 1.2;
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.X, 1200));
    });
    RunScenario("slide interrupted by original", [&]
    {
        Movement movement;
        movement.interrupt = true;
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.X, 400));
    });
    RunScenario("zero delta time", [&]
    {
        Movement movement;
        CalculateVelocity(movement, 0);
        EXPECT(NearlyEqual(movement.Velocity.X, 400));
        EXPECT(movement.accelerationReads == 0);
    });
    RunScenario("negative delta time", [&]
    {
        Movement movement;
        CalculateVelocity(movement, -.1f);
        EXPECT(NearlyEqual(movement.Velocity.X, 400));
        EXPECT(movement.accelerationReads == 0);
    });
    RunScenario("fluid movement", [&]
    {
        Movement movement;
        CalculateVelocity(movement, .016f, true);
        EXPECT(NearlyEqual(movement.Velocity.X, 400));
        EXPECT(movement.accelerationReads == 0);
    });
    RunScenario("stationary velocity", [&]
    {
        Movement movement;
        CalculateVelocity(movement);
        movement.Velocity = {0, 0, 0};
        CalculateVelocity(movement);
        EXPECT(movement.Velocity.Size() == 0);
    });
    RunScenario("slow slide and minimum max speed", [&]
    {
        Movement movement;
        movement.Velocity = {50, 0, -123};
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.X, 50));
        EXPECT(movement.Velocity.Z == -123);
        EXPECT(ReadMaxSpeed(movement) == 100);
    });
    RunScenario("another hook releases crouch", [&]
    {
        Movement movement;
        const float speed = ReadMaxSpeed(movement, [&](const Movement*)
        {
            movement.bWantsToCrouch = false;
            return 100.f;
        });
        EXPECT(speed == 100);
    });
    RunScenario("restore slide angle", [&]
    {
        Movement movement;
        const float angle = movement.OriginalAngle();
        EXPECT(UphillSlidingTestHarness::Slide(movement, false));
        EXPECT(movement.OriginalAngle() == angle);
        EXPECT(UphillSlidingTestHarness::Slide(movement, true));
        EXPECT(movement.OriginalAngle() == angle);
    });
    RunScenario("original slide eligibility", [&]
    {
        Movement movement;
        movement.eligible = false;
        const float angle = movement.OriginalAngle();
        EXPECT(!UphillSlidingTestHarness::Slide(movement, false));
        EXPECT(movement.OriginalAngle() == angle);
        EXPECT(!UphillSlidingTestHarness::Slide(movement, true));
        EXPECT(movement.OriginalAngle() == angle);
    });
    RunScenario("nested slide angle guard", [&]
    {
        Movement movement;
        const float angle = movement.OriginalAngle();
        EXPECT(UphillSlidingTestHarness::Slide(movement, false, [&](const Movement*)
        {
            EXPECT(movement.OriginalAngle() == PI);
            const bool result = UphillSlidingTestHarness::Slide(movement, true);
            EXPECT(movement.OriginalAngle() == PI);
            return result;
        }));
        EXPECT(movement.OriginalAngle() == angle);
    });
    RunScenario("crouch release slide eligibility", [&]
    {
        Movement movement;
        movement.bWantsToCrouch = false;
        EXPECT(!UphillSlidingTestHarness::Slide(movement, false));
        EXPECT(!UphillSlidingTestHarness::Slide(movement, true));
    });
    auto CheckNetworkRole = [&](const char* name, NetMode mode, ENetRole role, bool local)
    {
        RunScenario(name, [&]
        {
            Movement movement;
            movement.world.mode = mode;
            movement.owner.role = role;
            movement.owner.local = local;
            EXPECT(IsUphillCrouch(&movement));
            const float angle = movement.OriginalAngle();
            EXPECT(UphillSlidingTestHarness::Slide(movement, true));
            EXPECT(UphillSlidingTestHarness::Slide(movement, false));
            EXPECT(movement.OriginalAngle() == angle);
            EXPECT(ReadMaxSpeed(movement) == 1000);
            CalculateVelocity(movement);
            EXPECT(NearlyEqual(movement.Velocity.X, 1000) && movement.Velocity.Z == 70);
        });
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
        RunScenario("client/server replay sequence " + std::to_string(scenario), [&]
        {
            Movement client;
            Movement server;
            client.world.mode = NM_Client;
            client.owner.role = ROLE_AutonomousProxy;
            server.world.mode = NM_DedicatedServer;
            server.owner.local = false;
            if (scenario == 1)
            {
                client.acceleration = server.acceleration = {-1, 0, 0};
            }
            if (scenario == 2)
            {
                client.CurrentFloor.HitResult.ImpactNormal = server.CurrentFloor.HitResult.ImpactNormal = {0, 0, 1};
            }
            if (scenario == 3)
            {
                client.CurrentFloor.HitResult.ImpactNormal = server.CurrentFloor.HitResult.ImpactNormal = {.2, 0, std::sqrt(.96)};
            }
            if (scenario == 4)
            {
                client.bWantsToCrouch = server.bWantsToCrouch = false;
            }
            if (scenario == 5)
            {
                client.turnRadians = server.turnRadians = PI / 6;
            }
            if (scenario == 6)
            {
                client.interrupt = server.interrupt = true;
            }
            for (int step = 0; step < 8; ++step)
            {
                EXPECT(UphillSlidingTestHarness::Slide(client, true) == UphillSlidingTestHarness::Slide(server, true));
                EXPECT(UphillSlidingTestHarness::Slide(client, false) == UphillSlidingTestHarness::Slide(server, false));
                EXPECT(NearlyEqual(ReadMaxSpeed(client), ReadMaxSpeed(server)));
                const Movement before = client;
                CalculateVelocity(client);
                CalculateVelocity(server);
                EXPECT(NearlyEqual(client.Velocity.X, server.Velocity.X));
                EXPECT(NearlyEqual(client.Velocity.Y, server.Velocity.Y));
                EXPECT(NearlyEqual(client.Velocity.Z, server.Velocity.Z));
                Movement replay = before;
                CalculateVelocity(replay);
                EXPECT(NearlyEqual(client.Velocity.X, replay.Velocity.X));
                EXPECT(NearlyEqual(client.Velocity.Y, replay.Velocity.Y));
                EXPECT(NearlyEqual(client.Velocity.Z, replay.Velocity.Z));
            }
        });
    }
    RunScenario("null movement guards", []
    {
        EXPECT(!IsUphillCrouch(nullptr));
        EXPECT(!IsUphillSlide(nullptr));
    });
    RunScenario("idempotent hook cleanup", [&]
    {
        module.ShutdownModule();
        UphillSlidingTestHarness::CheckRemoved();
        module.ShutdownModule();
        UphillSlidingTestHarness::CheckRemoved();
    });
    module.StartupModule();
    RunScenario("module restart", [&]
    {
        Movement movement;
        CalculateVelocity(movement);
        EXPECT(NearlyEqual(movement.Velocity.X, 1000));
    });
    module.ShutdownModule();
    UphillSlidingTestHarness::CheckRemoved();
    std::cout << CompletedScenarios << " regression scenarios passed (mock engine/SML).\n";
}
