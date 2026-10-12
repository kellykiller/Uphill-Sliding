#pragma once

#include <cstdlib>
#include <iostream>
#include <string>

inline std::string CurrentScenario = "initialization";
inline int CompletedScenarios = 0;

inline void Expect(bool condition, const char* expression, int line)
{
    if (!condition)
    {
        std::cerr << "FAIL " << CurrentScenario << " at line " << line
                  << ": " << expression << '\n';
        std::exit(EXIT_FAILURE);
    }
}

// Unlike assert(), checks and their expressions remain active under NDEBUG.
#define EXPECT(Expression) Expect(static_cast<bool>(Expression), #Expression, __LINE__)

template <typename Test>
void RunScenario(const std::string& name, Test test)
{
    CurrentScenario = name;
    test();
    ++CompletedScenarios;
    std::cout << "PASS " << name << '\n';
}
