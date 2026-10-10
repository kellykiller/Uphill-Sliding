#pragma once
enum NetMode { NM_Standalone, NM_Client, NM_ListenServer, NM_DedicatedServer };
struct UWorld
{
    NetMode mode = NM_Standalone;
    NetMode GetNetMode() const { return mode; }
};
