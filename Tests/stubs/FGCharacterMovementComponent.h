#pragma once
#include "CoreMinimal.h"
#include "Engine/World.h"
#include "GameFramework/Character.h"
class UFGCharacterMovementComponent final {
    friend class FUphillSlidingModule;
    friend struct UphillSlidingTestHarness;
    float mMaxSlideAngle=1.65f;
    bool CanSlide() const {return eligible && std::acos(FVector::DotProduct(FVector(Velocity.X,Velocity.Y,0).GetSafeNormal(),CurrentFloor.HitResult.ImpactNormal))<=mMaxSlideAngle;}
    bool CanStartSlide()const{return eligible && CanSlide();}
public:
    bool eligible=true, bWantsToCrouch=true, grounded=true, sliding=true, interrupt=false, reverse=false, noWorld=false, noOwner=false;
    int originalCalls=0;
    mutable int accelerationReads=0;
    double speedFactor=0.4, turnRadians=0;
    UWorld world; ACharacter owner;
    FVector Velocity{1000,0,70}, acceleration{0,0,0};
    struct Floor {bool walkable=true; struct Hit {FVector ImpactNormal{-0.2,0,std::sqrt(0.96)};} HitResult; bool IsWalkableFloor()const{return walkable;}} CurrentFloor;
    UWorld* GetWorld()const{return noWorld ? nullptr : const_cast<UWorld*>(&world);} ACharacter* GetCharacterOwner()const{return noOwner ? nullptr : const_cast<ACharacter*>(&owner);}
    bool IsMovingOnGround()const{return grounded;} bool IsSliding()const{return sliding;} FVector GetCurrentAcceleration()const{++accelerationReads;return acceleration;}
    virtual float GetMaxSpeed()const{return 100;}
    virtual void CalcVelocity(float,float,bool,float){
        ++originalCalls;
        const double x=Velocity.X, y=Velocity.Y;
        const double f=reverse ? -speedFactor : speedFactor;
        Velocity.X=f*(x*std::cos(turnRadians)-y*std::sin(turnRadians));
        Velocity.Y=f*(x*std::sin(turnRadians)+y*std::cos(turnRadians));
        if(interrupt)sliding=false;
    }
    float OriginalAngle()const{return mMaxSlideAngle;}
};
