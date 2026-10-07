#pragma once
class IModuleInterface {public: virtual ~IModuleInterface()=default; virtual void StartupModule(){} virtual void ShutdownModule(){} };