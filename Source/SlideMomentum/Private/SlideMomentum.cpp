#include "SlideMomentum.h"

#if !WITH_EDITOR

#include "Engine/World.h"
#include "FGCharacterMovementComponent.h"
#include "GameFramework/Character.h"
#include "Templates/UnrealTemplate.h"
#include "Patching/NativeHookManager.h"

DEFINE_LOG_CATEGORY_STATIC(LogSlideMomentum, Log, All);

namespace
{
    bool IsUphillCrouch(const UFGCharacterMovementComponent* Movement)
    {
        if (Movement == nullptr || !Movement->bWantsToCrouch ||
            !Movement->IsMovingOnGround() ||
            !Movement->CurrentFloor.IsWalkableFloor())
        {
            return false;
        }

        const UWorld* World = Movement->GetWorld();
        const ACharacter* Character = Movement->GetCharacterOwner();
        if (World == nullptr || Character == nullptr || !Character->IsPlayerControlled())
        {
            return false;
        }

        // Apply identical rules to client prediction/replay and server authority.
        // Remote client pawns are simulated proxies: their movement is replicated
        // and must not receive a second local momentum correction.
        const bool IsOwningClient = Character->GetLocalRole() == ROLE_AutonomousProxy &&
            Character->IsLocallyControlled();
        if (!Character->HasAuthority() && !IsOwningClient)
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
    TScope& Scope, const UFGCharacterMovementComponent* Movement)
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
    Scope(Movement);
}

#endif // !WITH_EDITOR

void FSlideMomentumModule::StartupModule()
{
#if !WITH_EDITOR
    // The editor uses FactoryGame stubs. Game and dedicated-server builds install
    // the same hooks, using state already carried by normal character movement.
    CanSlideHook = SUBSCRIBE_METHOD(
        UFGCharacterMovementComponent::CanSlide,
        [](auto& Scope, const UFGCharacterMovementComponent* Movement)
        {
            CallWithWideSlideAngle(Scope, Movement);
        });

    CanStartSlideHook = SUBSCRIBE_METHOD(
        UFGCharacterMovementComponent::CanStartSlide,
        [](auto& Scope, const UFGCharacterMovementComponent* Movement)
        {
            CallWithWideSlideAngle(Scope, Movement);
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

        });

    UE_LOG(LogSlideMomentum, Display,
        TEXT("Uphill Sliding loaded (client/server movement rules)."));
#endif
}

void FSlideMomentumModule::ShutdownModule()
{
#if !WITH_EDITOR
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
