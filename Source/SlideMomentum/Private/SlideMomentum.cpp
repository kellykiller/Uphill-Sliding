#include "SlideMomentum.h"

#if !WITH_EDITOR && !UE_SERVER

#include "Engine/World.h"
#include "FGCharacterMovementComponent.h"
#include "GameFramework/Character.h"
#include "HAL/IConsoleManager.h"
#include "Templates/UnrealTemplate.h"
#include "Patching/NativeHookManager.h"

DEFINE_LOG_CATEGORY_STATIC(LogSlideMomentum, Log, All);

namespace
{
    TAutoConsoleVariable<int32> CVarSlideMomentumEnabled(
        TEXT("SlideMomentum.Enabled"),
        1,
        TEXT("Enable uphill slide momentum in standalone singleplayer: 0=off, 1=on."),
        ECVF_Default);

    TAutoConsoleVariable<int32> CVarSlideMomentumDebug(
        TEXT("SlideMomentum.Debug"),
        0,
        TEXT("Log uphill slide checks and velocity corrections: 0=off, 1=on."),
        ECVF_Default);

    bool IsUphillCrouch(const UFGCharacterMovementComponent* Movement)
    {
        if (CVarSlideMomentumEnabled.GetValueOnGameThread() == 0 ||
            Movement == nullptr || !Movement->bWantsToCrouch ||
            !Movement->IsMovingOnGround() ||
            !Movement->CurrentFloor.IsWalkableFloor())
        {
            return false;
        }

        const UWorld* World = Movement->GetWorld();
        const ACharacter* Character = Movement->GetCharacterOwner();
        if (World == nullptr || World->GetNetMode() != NM_Standalone ||
            Character == nullptr || !Character->IsLocallyControlled() ||
            !Character->IsPlayerControlled())
        {
            return false;
        }

        const FVector Normal = Movement->CurrentFloor.HitResult.ImpactNormal;
        const FVector HorizontalVelocity(Movement->Velocity.X, Movement->Velocity.Y, 0.0);
        const FVector Direction = HorizontalVelocity.GetSafeNormal();

        // A walkable floor tilts its normal against the direction of uphill travel.
        // This also rejects flat ground, downhill travel and traversal modes such as tubes.
        return Normal.Z > KINDA_SMALL_NUMBER &&
            !Direction.IsNearlyZero() &&
            FVector::DotProduct(Direction, Normal) < -0.0001;
    }

    bool IsUphillSlide(const UFGCharacterMovementComponent* Movement)
    {
        return IsUphillCrouch(Movement) && Movement->IsSliding();
    }
}

template <typename TScope>
void FSlideMomentumModule::CallWithWideSlideAngle(
    TScope& Scope, const UFGCharacterMovementComponent* Movement, const TCHAR* Name)
{
    if (!IsUphillCrouch(Movement))
    {
        return; // SML forwards the call automatically.
    }

    // FactoryGame declares mMaxSlideAngle in radians. PI allows any uphill angle;
    // the original method still checks speed, floor eligibility and other conditions.
    // This helper is a module member because the field is private and the module
    // is its AccessTransformers friend. Restore the field after this invocation.
    auto* MutableMovement = const_cast<UFGCharacterMovementComponent*>(Movement);
    TGuardValue<float> AngleGuard(MutableMovement->mMaxSlideAngle, PI);
    const bool Result = Scope(Movement);
    if (CVarSlideMomentumDebug.GetValueOnGameThread() != 0)
    {
        UE_LOG(LogSlideMomentum, Display,
            TEXT("%s uphill: allowed=%d speed=%.1f cm/s"),
            Name, Result ? 1 : 0, Movement->Velocity.Size2D());
    }
}

#endif // !WITH_EDITOR && !UE_SERVER

void FSlideMomentumModule::StartupModule()
{
#if !WITH_EDITOR && !UE_SERVER
    // The editor uses FactoryGame stubs; dedicated servers do not use this mod.
    CanSlideHook = SUBSCRIBE_METHOD(
        UFGCharacterMovementComponent::CanSlide,
        [](auto& Scope, const UFGCharacterMovementComponent* Movement)
        {
            CallWithWideSlideAngle(Scope, Movement, TEXT("CanSlide"));
        });

    CanStartSlideHook = SUBSCRIBE_METHOD(
        UFGCharacterMovementComponent::CanStartSlide,
        [](auto& Scope, const UFGCharacterMovementComponent* Movement)
        {
            CallWithWideSlideAngle(Scope, Movement, TEXT("CanStartSlide"));
        });

    GetMaxSpeedHook = SUBSCRIBE_UOBJECT_METHOD(
        UFGCharacterMovementComponent,
        GetMaxSpeed,
        [](auto& Scope, const UFGCharacterMovementComponent* Movement)
        {
            const bool PreserveMomentum = IsUphillSlide(Movement);
            const float IncomingSpeed = PreserveMomentum
                ? static_cast<float>(Movement->Velocity.Size2D()) : 0.0f;
            const float OriginalMaxSpeed = Scope(Movement);

            // Scope may invoke other mods' hooks as well as the const original.
            // Recheck eligibility before applying our override.
            if (PreserveMomentum && IsUphillSlide(Movement))
            {
                Scope.Override(FMath::Max(OriginalMaxSpeed, IncomingSpeed));
            }
        });

    CalcVelocityHook = SUBSCRIBE_UOBJECT_METHOD(
        UFGCharacterMovementComponent,
        CalcVelocity,
        [](auto& Scope, UFGCharacterMovementComponent* Movement,
           float DeltaTime, float Friction, bool IsFluid, float BrakingDeceleration)
        {
            if (IsFluid || DeltaTime <= 0.0f || !IsUphillSlide(Movement))
            {
                return; // SML forwards the unmodified call automatically.
            }

            const FVector Before(Movement->Velocity.X, Movement->Velocity.Y, 0.0);
            const FVector Acceleration = Movement->GetCurrentAcceleration();

            // Reverse input is allowed to brake the slide.
            const bool IsBraking = FVector::DotProduct(
                FVector(Acceleration.X, Acceleration.Y, 0.0), Before) < -KINDA_SMALL_NUMBER;

            Scope(Movement, DeltaTime, Friction, IsFluid, BrakingDeceleration);

            if (IsBraking || !IsUphillSlide(Movement))
            {
                return;
            }

            const FVector After(Movement->Velocity.X, Movement->Velocity.Y, 0.0);
            const double BeforeSpeed = Before.Size();
            const double AfterSpeed = After.Size();
            if (BeforeSpeed <= KINDA_SMALL_NUMBER ||
                AfterSpeed + KINDA_SMALL_NUMBER >= BeforeSpeed)
            {
                return;
            }

            // Keep ordinary steering, but do not turn a reversal into a speed boost.
            FVector Direction = AfterSpeed > KINDA_SMALL_NUMBER
                ? After / AfterSpeed : Before / BeforeSpeed;
            if (FVector::DotProduct(Direction, Before / BeforeSpeed) < 0.5)
            {
                return;
            }

            Movement->Velocity.X = Direction.X * BeforeSpeed;
            Movement->Velocity.Y = Direction.Y * BeforeSpeed;
            // Keep Z unchanged. The normal movement solver handles ramps and collisions
            // after CalcVelocity. No velocity is restored after moving into a wall.

            if (CVarSlideMomentumDebug.GetValueOnGameThread() != 0)
            {
                UE_LOG(LogSlideMomentum, Display,
                    TEXT("Uphill slide: %.1f -> %.1f cm/s; retained %.1f cm/s"),
                    BeforeSpeed, AfterSpeed, Movement->Velocity.Size2D());
            }
        });

    UE_LOG(LogSlideMomentum, Display,
        TEXT("SlideMomentum loaded (standalone singleplayer)."));
#endif
}

void FSlideMomentumModule::ShutdownModule()
{
#if !WITH_EDITOR && !UE_SERVER
    // SML 3.12 removes handlers directly; its unsubscribe macros do not fetch a CDO.
    // Retain cleanup so unloading this module cannot leave callbacks into its code.
    if (CalcVelocityHook.IsValid())
    {
        UNSUBSCRIBE_UOBJECT_METHOD(UFGCharacterMovementComponent, CalcVelocity, CalcVelocityHook);
        CalcVelocityHook.Reset();
    }
    if (GetMaxSpeedHook.IsValid())
    {
        UNSUBSCRIBE_UOBJECT_METHOD(UFGCharacterMovementComponent, GetMaxSpeed, GetMaxSpeedHook);
        GetMaxSpeedHook.Reset();
    }
    if (CanStartSlideHook.IsValid())
    {
        UNSUBSCRIBE_METHOD(UFGCharacterMovementComponent::CanStartSlide, CanStartSlideHook);
        CanStartSlideHook.Reset();
    }
    if (CanSlideHook.IsValid())
    {
        UNSUBSCRIBE_METHOD(UFGCharacterMovementComponent::CanSlide, CanSlideHook);
        CanSlideHook.Reset();
    }
#endif
}

IMPLEMENT_MODULE(FSlideMomentumModule, SlideMomentum)
