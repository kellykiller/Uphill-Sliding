#pragma once
enum ENetRole { ROLE_None, ROLE_SimulatedProxy, ROLE_AutonomousProxy, ROLE_Authority };
struct ACharacter
{
    bool local = true;
    bool player = true;
    ENetRole role = ROLE_Authority;
    bool IsLocallyControlled() const { return local; }
    bool IsPlayerControlled() const { return player; }
    bool HasAuthority() const { return role == ROLE_Authority; }
    ENetRole GetLocalRole() const { return role; }
};
