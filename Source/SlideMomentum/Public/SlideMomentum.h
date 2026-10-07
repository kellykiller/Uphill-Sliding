#pragma once

#include "CoreMinimal.h"
#include "Modules/ModuleManager.h"

class FSlideMomentumModule : public IModuleInterface
{
public:
    virtual void StartupModule() override;
    virtual void ShutdownModule() override;

private:
    FDelegateHandle CanSlideHook;
    FDelegateHandle CanStartSlideHook;
    FDelegateHandle GetMaxSpeedHook;
    FDelegateHandle CalcVelocityHook;
};
