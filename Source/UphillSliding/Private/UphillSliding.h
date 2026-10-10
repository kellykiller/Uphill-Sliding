#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"

#if !WITH_EDITOR
class UFGCharacterMovementComponent;
#endif

class FUphillSlidingModule : public IModuleInterface
{
public:
    virtual void StartupModule() override;
    virtual void ShutdownModule() override;

private:
#if !WITH_EDITOR
    template <typename TScope>
    static void CallWithWideSlideAngle(
        TScope& Scope, const UFGCharacterMovementComponent* Movement);

    FDelegateHandle CanSlideHook;
    FDelegateHandle CanStartSlideHook;
    FDelegateHandle GetMaxSpeedHook;
    FDelegateHandle CalcVelocityHook;
#endif
};
